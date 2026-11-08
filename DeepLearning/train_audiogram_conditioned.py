"""Train a compact audiogram-conditioned direct-to-CVBW magnitude model."""
from __future__ import annotations

import argparse
import csv
import json
import math
import time
import warnings
from pathlib import Path

import numpy as np
import soundfile as sf
import torch
from pystoi import stoi
from torch import nn
from torch.utils.data import DataLoader, Dataset

from train_speech_enhancer import HOP, N_FFT, ROOT, SR, sisdr_db

# Thresholds in dB HL at [250, 500, 1000, 2000, 4000, 6000] Hz,
# sampled/interpolated from the project's DSP/get_audiogram.m definitions.
PROFILE_THRESHOLDS = {
    1: (25, 25, 25, 35, 25, 27.5),
    4: (10, 15, 25, 40, 50, 57.5),
    35: (90, 95, 85, 95, 90, 92.5),
    36: (15, 25, 35, 55, 95, 75),
}


class ConditionedPairs(Dataset):
    def __init__(self, manifest: Path):
        self.root = manifest.parent
        with manifest.open("r", newline="", encoding="utf-8-sig") as stream:
            self.rows = list(csv.DictReader(stream))
        if not self.rows:
            raise ValueError(f"No rows in {manifest}")

    def __len__(self):
        return len(self.rows)

    def __getitem__(self, index):
        row = self.rows[index]
        noisy, noisy_sr = sf.read(self.root / row["noisy_file"], dtype="float32")
        target, target_sr = sf.read(self.root / row["target_file"], dtype="float32")
        if noisy_sr != SR or target_sr != SR:
            raise ValueError("Prepared audio and CVBW targets must be 16 kHz")
        length = min(len(noisy), len(target))
        profile = int(row["profile_id"])
        condition = np.asarray(PROFILE_THRESHOLDS[profile], dtype=np.float32) / 100.0
        return (torch.from_numpy(noisy[:length].copy()),
                torch.from_numpy(target[:length].copy()),
                torch.from_numpy(condition), index)


class AudiogramConditionedNet(nn.Module):
    """Compact STFT magnitude regressor conditioned on six audiogram thresholds."""
    def __init__(self, width: int = 16, condition_width: int = 12):
        super().__init__()
        self.condition = nn.Sequential(nn.Linear(6, condition_width), nn.ReLU(),
                                       nn.Linear(condition_width, condition_width), nn.ReLU())
        self.features = nn.Sequential(
            nn.Conv2d(1 + condition_width, width, 3, padding=1), nn.ReLU(),
            nn.Conv2d(width, width, 3, padding=1), nn.ReLU(),
            nn.Conv2d(width, width, 3, padding=1), nn.ReLU(),
            nn.Conv2d(width, 1, 1),
        )
        self.register_buffer("window", torch.hann_window(N_FFT))

    def forward(self, noisy: torch.Tensor, audiogram: torch.Tensor):
        spectrum = torch.stft(noisy, N_FFT, HOP, window=self.window,
                              return_complex=True, center=True)
        magnitude = spectrum.abs()
        log_magnitude = torch.log1p(magnitude)
        profile = self.condition(audiogram).unsqueeze(-1).unsqueeze(-1)
        profile = profile.expand(-1, -1, log_magnitude.shape[-2], log_magnitude.shape[-1])
        predicted_logmag = self.features(torch.cat((log_magnitude.unsqueeze(1), profile), dim=1)).squeeze(1)
        predicted_mag = torch.expm1(torch.clamp(predicted_logmag, min=0.0, max=15.0))
        output_spec = predicted_mag * torch.exp(1j * torch.angle(spectrum))
        output = torch.istft(output_spec, N_FFT, HOP, window=self.window,
                             length=noisy.shape[-1], center=True)
        return output, predicted_logmag


def train(args):
    torch.set_num_threads(args.threads)
    torch.manual_seed(args.seed)
    np.random.seed(args.seed)
    device = torch.device(args.device)
    train_ds = ConditionedPairs(args.train_manifest)
    val_ds = ConditionedPairs(args.validation_manifest)
    train_dl = DataLoader(train_ds, batch_size=args.batch_size, shuffle=True)
    val_dl = DataLoader(val_ds, batch_size=args.batch_size, shuffle=False)
    model = AudiogramConditionedNet().to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
    out = args.output_dir
    out.mkdir(parents=True, exist_ok=True)
    best_val = float("inf")
    history = []
    for epoch in range(args.epochs):
        model.train()
        losses = []
        for noisy, target, profile, _ in train_dl:
            noisy, target, profile = noisy.to(device), target.to(device), profile.to(device)
            target_mag = torch.stft(target, N_FFT, HOP, window=model.window,
                                    return_complex=True, center=True).abs()
            target_logmag = torch.log1p(target_mag)
            _, pred_logmag = model(noisy, profile)
            loss = torch.nn.functional.l1_loss(pred_logmag, target_logmag)
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            optimizer.step()
            losses.append(float(loss.detach()))
        val_loss = validation_logmag_loss(model, val_dl, device)
        history.append({"epoch": epoch + 1, "train_logmag_l1": float(np.mean(losses)),
                        "validation_logmag_l1": val_loss})
        print(f"epoch {epoch + 1}/{args.epochs}: train={history[-1]['train_logmag_l1']:.5f} "
              f"validation={val_loss:.5f}", flush=True)
        if val_loss < best_val:
            best_val = val_loss
            torch.save({"state_dict": {k: v.detach().cpu() for k, v in model.state_dict().items()},
                        "epoch": epoch + 1, "sample_rate": SR, "n_fft": N_FFT, "hop": HOP,
                        "profile_thresholds_db_hl": PROFILE_THRESHOLDS}, out / "best_model.pt")
    (out / "training_history.json").write_text(json.dumps(history, indent=2), encoding="utf-8")
    return history


@torch.no_grad()
def validation_logmag_loss(model, loader, device):
    model.eval()
    losses = []
    for noisy, target, profile, _ in loader:
        noisy, target, profile = noisy.to(device), target.to(device), profile.to(device)
        target_mag = torch.stft(target, N_FFT, HOP, window=model.window,
                                return_complex=True, center=True).abs()
        _, pred = model(noisy, profile)
        losses.append(float(torch.nn.functional.l1_loss(pred, torch.log1p(target_mag))))
    return float(np.mean(losses))


@torch.no_grad()
def evaluate(args):
    torch.set_num_threads(args.threads)
    device = torch.device(args.device)
    checkpoint = torch.load(args.checkpoint, map_location="cpu", weights_only=True)
    model = AudiogramConditionedNet()
    model.load_state_dict(checkpoint["state_dict"])
    model.to(device).eval()
    dataset = ConditionedPairs(args.validation_manifest)
    rows = []
    audio_dir = args.output_dir / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    latencies_ms = []
    for index in range(len(dataset)):
        noisy, target, condition, _ = dataset[index]
        profile_id = int(dataset.rows[index]["profile_id"])
        noisy_device = noisy.unsqueeze(0).to(device)
        cond_device = condition.unsqueeze(0).to(device)
        for _ in range(3):
            model(noisy_device, cond_device)
        if device.type == "cuda":
            torch.cuda.synchronize()
        start = time.perf_counter()
        with torch.inference_mode():
            estimated = model(noisy_device, cond_device)[0].squeeze(0).cpu().numpy()
        if device.type == "cuda":
            torch.cuda.synchronize()
        latencies_ms.append((time.perf_counter() - start) * 1000)
        estimated = np.asarray(estimated, dtype=np.float32)
        target_np = target.numpy()
        reference_row = dataset.rows[index]
        try:
            with warnings.catch_warnings(record=True) as caught:
                warnings.simplefilter("always")
                stoi_value = float(stoi(target_np, estimated, SR, extended=False))
            if any("Not enough STFT frames" in str(w.message) for w in caught):
                stoi_value = float("nan")
        except Exception:
            stoi_value = float("nan")
        rows.append({
            "case_id": int(reference_row["case_id"]), "profile_id": profile_id,
            "speaker": reference_row["speaker"], "input_snr_db": int(reference_row["input_snr_db"]),
            "direct_model_sisdr_db": sisdr_db(target_np, estimated),
            "direct_model_stoi": stoi_value,
            "direct_model_inference_ms_per_1s": latencies_ms[-1],
        })
        sf.write(audio_dir / f"case_{int(reference_row['case_id']):03d}_profile_{profile_id:02d}_direct_model.wav",
                 estimated, SR, subtype="PCM_16")

    baseline_path = args.baseline_csv
    if baseline_path.exists():
        with baseline_path.open("r", newline="", encoding="utf-8-sig") as stream:
            baseline = {(int(row["case_id"]), int(row["profile_id"])): row
                        for row in csv.DictReader(stream)}
        for row in rows:
            base = baseline.get((row["case_id"], row["profile_id"]))
            if base:
                row["classical_aided_sisdr_db"] = float(base["classical_aided_sisdr_db"])
                row["neural_aided_sisdr_db"] = float(base["neural_aided_sisdr_db"])
                row["classical_aided_stoi"] = float(base["classical_aided_stoi"])
                row["neural_aided_stoi"] = float(base["neural_aided_stoi"])

    output_csv = args.output_dir / "validation_comparison.csv"
    with output_csv.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    summary = {
        "rows": len(rows), "profile_ids": sorted({r["profile_id"] for r in rows}),
        "mean_direct_model_sisdr_db": float(np.mean([r["direct_model_sisdr_db"] for r in rows])),
        "mean_direct_model_stoi_finite": float(np.nanmean([r["direct_model_stoi"] for r in rows])),
        "mean_inference_ms_per_1s": float(np.mean(latencies_ms)),
        "p95_inference_ms_per_1s": float(np.percentile(latencies_ms, 95)),
        "real_time_factor": float(np.mean(latencies_ms) / 1000.0),
        "parameter_count": sum(p.numel() for p in model.parameters()),
        "parameters_trainable": sum(p.numel() for p in model.parameters() if p.requires_grad),
    }
    (args.output_dir / "validation_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="action", required=True)
    fit = sub.add_parser("train")
    fit.add_argument("--train-manifest", type=Path, required=True)
    fit.add_argument("--validation-manifest", type=Path, required=True)
    fit.add_argument("--output-dir", type=Path, required=True)
    fit.add_argument("--epochs", type=int, default=5)
    fit.add_argument("--batch-size", type=int, default=8)
    fit.add_argument("--lr", type=float, default=1e-3)
    fit.add_argument("--seed", type=int, default=271828)
    fit.add_argument("--threads", type=int, default=4)
    fit.add_argument("--device", default="cuda" if torch.cuda.is_available() else "cpu")
    fit.set_defaults(func=train)

    infer = sub.add_parser("evaluate")
    infer.add_argument("--checkpoint", type=Path, required=True)
    infer.add_argument("--validation-manifest", type=Path, required=True)
    infer.add_argument("--baseline-csv", type=Path, default=ROOT / "Results" / "DeepLearning" /
                       "pilot_sisdr_crops" / "aided_reference_metrics.csv")
    infer.add_argument("--output-dir", type=Path, required=True)
    infer.add_argument("--threads", type=int, default=4)
    infer.add_argument("--device", default="cuda" if torch.cuda.is_available() else "cpu")
    infer.set_defaults(func=evaluate)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
