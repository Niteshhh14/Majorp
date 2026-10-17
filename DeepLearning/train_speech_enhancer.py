"""Train/evaluate a small STFT-mask speech denoiser on paired VCTK/DEMAND audio.

This is an initial noise-suppression experiment. It does not implement the
profile-dependent CVBW stage; use the same CVBW transform on all systems for
the final matched aided-reference comparison.
"""
from __future__ import annotations

import argparse
import csv
import functools
import importlib.metadata
import json
import math
import random
from pathlib import Path

import numpy as np
import soundfile as sf
import torch
from scipy.signal import resample_poly
from torch import nn
from torch.utils.data import DataLoader, Dataset
from pystoi import stoi


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = Path(__file__).resolve().parent / "splits" / "vctk_speaker_split.csv"
DEFAULT_NOISE = ROOT / "Data" / "Noise" / "DEMAND"
SR = 16000
N_FFT = 512
HOP = 128


@functools.lru_cache(maxsize=8)
def read_mono(path_string: str) -> tuple[np.ndarray, int]:
    audio, sr = sf.read(path_string, dtype="float32", always_2d=True)
    audio = audio.mean(axis=1)
    if sr != SR:
        divisor = math.gcd(int(sr), SR)
        audio = resample_poly(audio, SR // divisor, int(sr) // divisor).astype(np.float32)
        sr = SR
    return np.asarray(audio, dtype=np.float32), int(sr)


def rms(audio: np.ndarray) -> float:
    return float(np.sqrt(np.mean(np.square(audio, dtype=np.float64)) + 1e-12))


class PairedVctkDemand(Dataset):
    def __init__(self, manifest: Path, noise_root: Path, split: str,
                 segment_samples: int, seed: int, limit: int | None = None):
        with manifest.open("r", newline="", encoding="utf-8-sig") as f:
            rows = [r for r in csv.DictReader(f) if r["split"] == split]
        self.rows = random.Random(seed).sample(rows, limit) if limit and limit < len(rows) else rows
        self.noises = sorted(noise_root.rglob("*.wav"))
        if not self.rows:
            raise ValueError(f"No VCTK utterances for split={split} in {manifest}")
        if not self.noises:
            raise FileNotFoundError(f"No DEMAND WAV files found under {noise_root}")
        self.segment_samples = segment_samples
        self.seed = seed
        self.epoch = 0
        self.split = split

    def __len__(self):
        return len(self.rows)

    def set_epoch(self, epoch: int):
        self.epoch = epoch

    def __getitem__(self, index: int):
        rng = random.Random(self.seed + self.epoch * 1_000_003 + index * 7919)
        row = self.rows[index]
        clean, _ = read_mono(str(ROOT / row["relative_path"]))
        n = self.segment_samples
        clean_start = rng.randrange(max(1, len(clean) - n + 1))
        clean = clean[clean_start:clean_start + n].copy()
        if len(clean) < n:
            clean = np.pad(clean, (0, n - len(clean)))

        noise_path = self.noises[rng.randrange(len(self.noises))]
        noise, _ = read_mono(str(noise_path))
        noise_start = rng.randrange(max(1, len(noise) - n + 1))
        noise = noise[noise_start:noise_start + n].copy()
        if len(noise) < n:
            noise = np.pad(noise, (0, n - len(noise)))

        snr_db = rng.choice((-5, 0, 5, 10))
        noise *= rms(clean) / (rms(noise) * (10.0 ** (snr_db / 20.0)))
        noisy = clean + noise
        peak = max(float(np.max(np.abs(noisy))), 1e-6)
        if peak > 0.98:
            scale = 0.98 / peak
            clean *= scale
            noisy *= scale

        return (torch.from_numpy(noisy.copy()), torch.from_numpy(clean.copy()),
                str(row["speaker"]), row["relative_path"],
                str(noise_path.relative_to(noise_path.parents[1])),
                int(clean_start), int(noise_start), int(snr_db))


class SpectralMaskNet(nn.Module):
    """Compact 2-D CNN that predicts a bounded magnitude mask from log magnitude."""
    def __init__(self, width: int = 24):
        super().__init__()
        self.net = nn.Sequential(
            nn.Conv2d(1, width, 3, padding=1), nn.ReLU(),
            nn.Conv2d(width, width, 3, padding=1), nn.ReLU(),
            nn.Conv2d(width, width, 3, padding=1), nn.ReLU(),
            nn.Conv2d(width, 1, 1), nn.Sigmoid(),
        )
        self.register_buffer("window", torch.hann_window(N_FFT))

    def forward(self, noisy: torch.Tensor):
        spec = torch.stft(noisy, N_FFT, HOP, window=self.window,
                          return_complex=True, center=True)
        mag = spec.abs()
        mask = self.net(torch.log1p(mag).unsqueeze(1)).squeeze(1)
        enhanced_spec = spec * mask
        enhanced = torch.istft(enhanced_spec, N_FFT, HOP, window=self.window,
                               length=noisy.shape[-1], center=True)
        return enhanced, mag * mask, mag


def spectral_subtraction(noisy: np.ndarray, alpha: float = 1.15,
                         floor: float = 0.04, fs: int = SR) -> np.ndarray:
    """Mirror DSP/spectral_subtraction_enhance.m for a pre-CVBW comparator."""
    frame_len, hop, nfft = 256, 128, 512
    window = np.hamming(frame_len + 1)[:-1].astype(np.float64)
    frames = max(1, 1 + math.ceil((len(noisy) - frame_len) / hop))
    padded_len = (frames - 1) * hop + frame_len
    x = np.pad(noisy.astype(np.float64), (0, padded_len - len(noisy)))
    noise_frames = max(1, int(math.floor((0.35 * fs - frame_len) / hop)) + 1)
    noise_frames = min(noise_frames, frames)
    noise_mag = np.zeros(nfft)
    for k in range(noise_frames):
        idx = k * hop + np.arange(frame_len)
        noise_mag += np.abs(np.fft.fft(x[idx] * window, nfft))
    noise_mag /= noise_frames
    y = np.zeros(padded_len)
    win_sum = np.zeros(padded_len)
    for k in range(frames):
        idx = k * hop + np.arange(frame_len)
        spectrum = np.fft.fft(x[idx] * window, nfft)
        mag = np.abs(spectrum)
        enhanced_mag = np.maximum(mag - alpha * noise_mag, floor * mag)
        frame = np.fft.ifft(enhanced_mag * np.exp(1j * np.angle(spectrum))).real[:frame_len]
        y[idx] += frame * window
        win_sum[idx] += window ** 2
    enhanced = (y / (win_sum + np.finfo(float).eps))[:len(noisy)]
    peak = np.max(np.abs(enhanced))
    if peak > 0.95:
        enhanced *= 0.95 / peak
    return enhanced.astype(np.float32)


def sisdr_db(reference: np.ndarray, estimate: np.ndarray) -> float:
    reference = reference.astype(np.float64) - np.mean(reference)
    estimate = estimate.astype(np.float64) - np.mean(estimate)
    scale = np.dot(estimate, reference) / (np.dot(reference, reference) + 1e-12)
    target = scale * reference
    error = estimate - target
    return float(10 * np.log10((np.dot(target, target) + 1e-12) /
                               (np.dot(error, error) + 1e-12)))


def batch_loss(model, noisy, clean, sisdr_weight: float):
    enhanced, enhanced_mag, clean_mag = model(noisy)
    spectral = torch.mean(torch.abs(torch.log1p(enhanced_mag) - torch.log1p(
        torch.stft(clean, N_FFT, HOP, window=model.window,
                   return_complex=True, center=True).abs())))
    waveform = torch.mean(torch.abs(enhanced - clean))
    ref = clean - clean.mean(dim=-1, keepdim=True)
    est = enhanced - enhanced.mean(dim=-1, keepdim=True)
    scale = (est * ref).sum(dim=-1, keepdim=True) / (ref.square().sum(dim=-1, keepdim=True) + 1e-8)
    projected = scale * ref
    error = est - projected
    si_sdr = 10 * torch.log10((projected.square().sum(dim=-1) + 1e-8) /
                              (error.square().sum(dim=-1) + 1e-8))
    return spectral + 0.05 * waveform - sisdr_weight * si_sdr.mean(), enhanced


@torch.no_grad()
def evaluate(model, loader, device, output_csv: Path, audio_dir: Path | None = None):
    model.eval()
    rows = []
    if audio_dir:
        audio_dir.mkdir(parents=True, exist_ok=True)
    for noisy, clean, speakers, speech_paths, noise_paths, clean_starts, noise_starts, snrs in loader:
        noisy = noisy.to(device)
        estimates = model(noisy)[0].cpu().numpy()
        noisy_np, clean_np = noisy.cpu().numpy(), clean.numpy()
        for i in range(len(speakers)):
            classical = spectral_subtraction(noisy_np[i])
            row_index = len(rows) + 1
            profile_id = (1, 4, 35, 36)[(row_index - 1) % 4]
            rows.append({
                "case_id": row_index, "audiogram_profile": profile_id,
                "speaker": speakers[i], "speech_path": speech_paths[i],
                "clean_crop_start_16k": int(clean_starts[i]),
                "noise": noise_paths[i], "noise_crop_start_16k": int(noise_starts[i]),
                "input_snr_db": int(snrs[i]),
                "noisy_sisdr_db": sisdr_db(clean_np[i], noisy_np[i]),
                "spectral_subtraction_sisdr_db": sisdr_db(clean_np[i], classical),
                "neural_sisdr_db": sisdr_db(clean_np[i], estimates[i]),
                "noisy_stoi": stoi(clean_np[i], noisy_np[i], SR),
                "spectral_subtraction_stoi": stoi(clean_np[i], classical, SR),
                "neural_stoi": stoi(clean_np[i], estimates[i], SR),
            })
            if audio_dir:
                for kind, audio in (("clean", clean_np[i]), ("noisy", noisy_np[i]),
                                    ("spectral_subtraction", classical), ("neural", estimates[i])):
                    sf.write(audio_dir / f"case_{row_index:03d}_{kind}.wav", audio, SR,
                             subtype="PCM_16")
    output_csv.parent.mkdir(parents=True, exist_ok=True)
    with output_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    metrics = {}
    for name in ("noisy", "spectral_subtraction", "neural"):
        for metric in ("sisdr_db", "stoi"):
            key = f"{name}_{metric}"
            metrics[key] = float(np.mean([r[key] for r in rows]))
    return rows, metrics


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--noise-root", type=Path, default=DEFAULT_NOISE)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "Results" / "DeepLearning")
    parser.add_argument("--epochs", type=int, default=1)
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--segment-seconds", type=float, default=1.0)
    parser.add_argument("--limit-train", type=int)
    parser.add_argument("--limit-val", type=int)
    parser.add_argument("--seed", type=int, default=271828)
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--sisdr-weight", type=float, default=0.01)
    parser.add_argument("--log-steps", type=int, default=16)
    parser.add_argument("--device", default="cuda" if torch.cuda.is_available() else "cpu")
    args = parser.parse_args()

    torch.set_num_threads(args.threads)
    torch.set_num_interop_threads(1)
    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    device = torch.device(args.device)
    n = int(args.segment_seconds * SR)
    train_ds = PairedVctkDemand(args.manifest, args.noise_root, "train", n,
                               args.seed, args.limit_train)
    val_ds = PairedVctkDemand(args.manifest, args.noise_root, "validation", n,
                             args.seed + 1, args.limit_val)
    generator = torch.Generator().manual_seed(args.seed)
    train_dl = DataLoader(train_ds, batch_size=args.batch_size, shuffle=True,
                          num_workers=0, generator=generator)
    val_dl = DataLoader(val_ds, batch_size=args.batch_size, shuffle=False, num_workers=0)

    model = SpectralMaskNet().to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=1e-3)
    out_dir = args.output_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    checkpoint = out_dir / "spectral_mask_net.pt"
    for epoch in range(args.epochs):
        model.train()
        train_ds.set_epoch(epoch)
        losses = []
        for step, (noisy, clean, *_) in enumerate(train_dl):
            noisy, clean = noisy.to(device), clean.to(device)
            loss, _ = batch_loss(model, noisy, clean, args.sisdr_weight)
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            optimizer.step()
            losses.append(float(loss.detach()))
            if (step + 1) % args.log_steps == 0 or step + 1 == len(train_dl):
                print(f"epoch {epoch + 1}/{args.epochs} batch {step + 1}/{len(train_dl)} "
                      f"loss={losses[-1]:.5f}", flush=True)
        print(f"epoch {epoch + 1}/{args.epochs}: train_loss={np.mean(losses):.5f}", flush=True)
        torch.save({"state_dict": {k: v.detach().cpu() for k, v in model.state_dict().items()},
                    "sample_rate": SR, "n_fft": N_FFT, "hop": HOP,
                    "seed": args.seed, "epoch": epoch + 1}, checkpoint)

    model.to(device)
    rows, metrics = evaluate(model, val_dl, device, out_dir / "validation_metrics.csv")
    config = vars(args).copy()
    for key, value in config.items():
        if isinstance(value, Path):
            resolved = value.resolve()
            try:
                config[key] = resolved.relative_to(ROOT).as_posix()
            except ValueError:
                config[key] = str(resolved)
    config["torch_version"] = torch.__version__
    config["package_versions"] = {
        name: importlib.metadata.version(name)
        for name in ("torch", "numpy", "scipy", "soundfile", "pystoi")
    }
    config["validation_count"] = len(rows)
    config["validation_means_pre_cvbw"] = metrics
    (out_dir / "run_config.json").write_text(json.dumps(config, indent=2), encoding="utf-8")
    print(json.dumps(metrics, indent=2))
    print(f"Validation rows: {len(rows)}; checkpoint: {checkpoint}")


if __name__ == "__main__":
    main()
