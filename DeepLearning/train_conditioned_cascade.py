"""Train a profile-aware denoiser that keeps the existing CVBW stage in-pipeline."""
from __future__ import annotations

import argparse
import csv
import json
import time
from pathlib import Path

import numpy as np
import soundfile as sf
import torch
import torch.nn.functional as F
from pystoi import stoi
from torch import nn
from torch.utils.data import DataLoader, Dataset

from train_audiogram_conditioned import PROFILE_THRESHOLDS
from train_speech_enhancer import HOP, N_FFT, ROOT, SR, sisdr_db, spectral_subtraction


class DenoisingPairs(Dataset):
    def __init__(self, manifest: Path):
        self.root = manifest.parent
        with manifest.open("r", newline="", encoding="utf-8-sig") as stream:
            self.rows = list(csv.DictReader(stream))

    def __len__(self):
        return len(self.rows)

    def __getitem__(self, index):
        row = self.rows[index]
        noisy, sr = sf.read(self.root / row["noisy_file"], dtype="float32")
        clean, clean_sr = sf.read(self.root / row["clean_file"], dtype="float32")
        if sr != SR or clean_sr != SR:
            raise ValueError("Expected 16 kHz pair files")
        n = min(len(noisy), len(clean))
        profile = int(row["profile_id"])
        condition = np.asarray(PROFILE_THRESHOLDS[profile], dtype=np.float32) / 100.0
        return (torch.from_numpy(noisy[:n].copy()), torch.from_numpy(clean[:n].copy()),
                torch.from_numpy(condition), index)


class AudiogramMaskNet(nn.Module):
    def __init__(self, width: int = 12, condition_width: int = 8):
        super().__init__()
        self.condition = nn.Sequential(nn.Linear(6, condition_width), nn.ReLU(),
                                       nn.Linear(condition_width, condition_width), nn.ReLU())
        self.features = nn.Sequential(
            nn.Conv2d(1 + condition_width, width, 3, padding=1), nn.ReLU(),
            nn.Conv2d(width, width, 3, padding=1), nn.ReLU(),
            nn.Conv2d(width, width, 3, padding=1), nn.ReLU(),
            nn.Conv2d(width, 1, 1), nn.Sigmoid(),
        )
        self.register_buffer("window", torch.hann_window(N_FFT))

    def forward(self, noisy, audiogram):
        spec = torch.stft(noisy, N_FFT, HOP, window=self.window,
                          return_complex=True, center=True)
        magnitude = spec.abs()
        logmag = torch.log1p(magnitude)
        profile = self.condition(audiogram).unsqueeze(-1).unsqueeze(-1)
        profile = profile.expand(-1, -1, logmag.shape[-2], logmag.shape[-1])
        mask = self.features(torch.cat((logmag.unsqueeze(1), profile), dim=1)).squeeze(1)
        enhanced_spec = spec * mask
        enhanced = torch.istft(enhanced_spec, N_FFT, HOP, window=self.window,
                               length=noisy.shape[-1], center=True)
        return enhanced, magnitude * mask


def audiogram_frequency_weights(profile, bins, device):
    thresholds = profile.to(device).unsqueeze(1)
    curve = F.interpolate(thresholds, size=bins, mode="linear", align_corners=True).squeeze(1)
    weights = 1.0 + curve
    return weights / weights.mean(dim=1, keepdim=True).clamp_min(1e-6)


def loss_fn(model, noisy, clean, profile, sisdr_weight=0.01):
    enhanced, enhanced_mag = model(noisy, profile)
    clean_mag = torch.stft(clean, N_FFT, HOP, window=model.window,
                           return_complex=True, center=True).abs()
    weight = audiogram_frequency_weights(profile, clean_mag.shape[-2], clean.device).unsqueeze(-1)
    spectral = (weight * torch.abs(torch.log1p(enhanced_mag) - torch.log1p(clean_mag))).mean()
    waveform = torch.mean(torch.abs(enhanced - clean))
    ref = clean - clean.mean(dim=-1, keepdim=True)
    est = enhanced - enhanced.mean(dim=-1, keepdim=True)
    scale = (est * ref).sum(dim=-1, keepdim=True) / (ref.square().sum(dim=-1, keepdim=True) + 1e-8)
    projected = scale * ref
    error = est - projected
    si_sdr = 10 * torch.log10((projected.square().sum(dim=-1) + 1e-8) /
                              (error.square().sum(dim=-1) + 1e-8))
    return spectral + 0.05 * waveform - sisdr_weight * si_sdr.mean(), enhanced


def run_train(args):
    torch.set_num_threads(args.threads)
    torch.manual_seed(args.seed)
    np.random.seed(args.seed)
    train_ds = DenoisingPairs(args.train_manifest)
    val_ds = DenoisingPairs(args.validation_manifest)
    train_dl = DataLoader(train_ds, batch_size=args.batch_size, shuffle=True)
    val_dl = DataLoader(val_ds, batch_size=args.batch_size, shuffle=False)
    device = torch.device(args.device)
    model = AudiogramMaskNet().to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    best = float("inf")
    history = []
    for epoch in range(args.epochs):
        model.train()
        losses = []
        for noisy, clean, profile, _ in train_dl:
            noisy, clean, profile = noisy.to(device), clean.to(device), profile.to(device)
            loss, _ = loss_fn(model, noisy, clean, profile)
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            optimizer.step()
            losses.append(float(loss.detach()))
        val = validation_loss(model, val_dl, device)
        history.append({"epoch": epoch + 1, "train_loss": float(np.mean(losses)), "validation_loss": val})
        print(f"epoch {epoch + 1}/{args.epochs}: train={history[-1]['train_loss']:.5f} val={val:.5f}", flush=True)
        if val < best:
            best = val
            torch.save({"state_dict": {k: v.detach().cpu() for k, v in model.state_dict().items()},
                        "sample_rate": SR, "n_fft": N_FFT, "hop": HOP,
                        "epoch": epoch + 1, "profile_thresholds_db_hl": PROFILE_THRESHOLDS},
                       args.output_dir / "best_model.pt")
    (args.output_dir / "training_history.json").write_text(json.dumps(history, indent=2), encoding="utf-8")
    return history


@torch.no_grad()
def validation_loss(model, loader, device):
    model.eval()
    values = []
    for noisy, clean, profile, _ in loader:
        loss, _ = loss_fn(model, noisy.to(device), clean.to(device), profile.to(device))
        values.append(float(loss))
    return float(np.mean(values))


@torch.no_grad()
def run_evaluate(args):
    torch.set_num_threads(args.threads)
    device = torch.device(args.device)
    state = torch.load(args.checkpoint, map_location="cpu", weights_only=True)
    model = AudiogramMaskNet().to(device)
    model.load_state_dict(state["state_dict"])
    model.eval()
    dataset = DenoisingPairs(args.validation_manifest)
    audio_dir = args.output_dir / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    records = []
    times = []
    for ix in range(len(dataset)):
        noisy, clean, profile, _ = dataset[ix]
        row = dataset.rows[ix]
        profile_id = int(row["profile_id"])
        x = noisy.unsqueeze(0).to(device)
        p = profile.unsqueeze(0).to(device)
        for _ in range(3):
            model(x, p)
        start = time.perf_counter()
        with torch.inference_mode():
            enhanced = model(x, p)[0].squeeze(0).cpu().numpy()
        times.append((time.perf_counter() - start) * 1000)
        classical = spectral_subtraction(noisy.numpy())
        case = int(row["case_id"])
        records.append({"case_id": case, "audiogram_profile": profile_id,
                        "speaker": row["speaker"], "input_snr_db": int(row["input_snr_db"]),
                        "noisy_sisdr": sisdr_db(clean.numpy(), noisy.numpy()),
                        "classical_sisdr": sisdr_db(clean.numpy(), classical),
                        "conditioned_sisdr": sisdr_db(clean.numpy(), enhanced),
                        "noisy_stoi": safe_stoi(clean.numpy(), noisy.numpy()),
                        "classical_stoi": safe_stoi(clean.numpy(), classical),
                        "conditioned_stoi": safe_stoi(clean.numpy(), enhanced),
                        "conditioned_model_ms": times[-1]})
        for kind, audio in (("clean", clean.numpy()), ("noisy", noisy.numpy()),
                            ("spectral_subtraction", classical), ("neural", enhanced)):
            sf.write(audio_dir / f"case_{case:03d}_{kind}.wav", audio, SR, subtype="PCM_16")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    with (args.output_dir / "validation_metrics.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=["case_id", "audiogram_profile", "speaker", "input_snr_db"])
        writer.writeheader()
        writer.writerows({k: r[k] for k in writer.fieldnames} for r in records)
    with (args.output_dir / "pre_cvbw_metrics.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(records[0]))
        writer.writeheader()
        writer.writerows(records)
    summary = {"rows": len(records), "profiles": sorted({r["audiogram_profile"] for r in records}),
               "mean_conditioned_sisdr_db": float(np.mean([r["conditioned_sisdr"] for r in records])),
               "mean_conditioned_stoi": float(np.nanmean([r["conditioned_stoi"] for r in records])),
               "mean_inference_ms_per_1s": float(np.mean(times)),
               "parameters": sum(p.numel() for p in model.parameters())}
    (args.output_dir / "pre_cvbw_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))


def safe_stoi(clean, estimate):
    try:
        return float(stoi(clean, estimate, SR))
    except Exception:
        return float("nan")


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="action", required=True)
    fit = sub.add_parser("train")
    fit.add_argument("--train-manifest", type=Path, required=True)
    fit.add_argument("--validation-manifest", type=Path, required=True)
    fit.add_argument("--output-dir", type=Path, required=True)
    fit.add_argument("--epochs", type=int, default=3)
    fit.add_argument("--batch-size", type=int, default=8)
    fit.add_argument("--lr", type=float, default=1e-3)
    fit.add_argument("--seed", type=int, default=271828)
    fit.add_argument("--threads", type=int, default=4)
    fit.add_argument("--device", default="cuda" if torch.cuda.is_available() else "cpu")
    fit.set_defaults(func=run_train)
    evaluate = sub.add_parser("evaluate")
    evaluate.add_argument("--checkpoint", type=Path, required=True)
    evaluate.add_argument("--validation-manifest", type=Path, required=True)
    evaluate.add_argument("--output-dir", type=Path, required=True)
    evaluate.add_argument("--threads", type=int, default=4)
    evaluate.add_argument("--device", default="cuda" if torch.cuda.is_available() else "cpu")
    evaluate.set_defaults(func=run_evaluate)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
