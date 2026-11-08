"""Compare profile-independent and conditioned denoiser size, MACs, and latency."""
from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import numpy as np
import torch

from train_speech_enhancer import N_FFT, HOP, ROOT, SpectralMaskNet, SR
from train_conditioned_cascade import AudiogramMaskNet
from train_audiogram_conditioned import PROFILE_THRESHOLDS


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, default=ROOT / "Results" / "DeepLearning" /
                        "pilot_sisdr" / "spectral_mask_net.pt")
    parser.add_argument("--conditioned", type=Path, default=ROOT / "Results" / "DeepLearning" /
                        "conditioned_cascade_128" / "best_model.pt")
    parser.add_argument("--output", type=Path, default=ROOT / "Results" / "DeepLearning" /
                        "conditioned_cascade_128" / "compute_comparison.json")
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--repeats", type=int, default=100)
    args = parser.parse_args()

    torch.set_num_threads(args.threads)
    baseline = SpectralMaskNet().eval()
    baseline.load_state_dict(torch.load(args.baseline, map_location="cpu", weights_only=True)["state_dict"])
    conditioned = AudiogramMaskNet().eval()
    conditioned.load_state_dict(torch.load(args.conditioned, map_location="cpu", weights_only=True)["state_dict"])
    audio = torch.randn(1, SR)
    profile = torch.tensor([PROFILE_THRESHOLDS[4]], dtype=torch.float32) / 100.0
    with torch.inference_mode():
        for _ in range(10):
            baseline(audio)
            conditioned(audio, profile)
        baseline_ms = []
        conditioned_ms = []
        for _ in range(args.repeats):
            start = time.perf_counter()
            baseline(audio)
            baseline_ms.append((time.perf_counter() - start) * 1000)
            start = time.perf_counter()
            conditioned(audio, profile)
            conditioned_ms.append((time.perf_counter() - start) * 1000)

    bins = N_FFT // 2 + 1
    frames = 1 + SR // HOP
    points = bins * frames
    baseline_conv_macs_per_point = 1 * 24 * 9 + 24 * 24 * 9 * 2 + 24
    conditioned_conv_macs_per_point = 9 * 12 * 9 + 12 * 12 * 9 * 2 + 12
    baseline_params = sum(p.numel() for p in baseline.parameters())
    conditioned_params = sum(p.numel() for p in conditioned.parameters())

    def stats(values):
        return {"mean_ms": float(np.mean(values)), "median_ms": float(np.median(values)),
                "p95_ms": float(np.percentile(values, 95)),
                "rtf_from_median": float(np.median(values) / 1000.0)}

    report = {
        "hardware_execution": "CPU; same Python process; audio I/O excluded; 1 s input; batch 1",
        "torch_threads": args.threads,
        "baseline_profile_independent": {
            "parameters": baseline_params,
            "estimated_conv_macs_per_1s_clip": int(baseline_conv_macs_per_point * points),
            "latency": stats(baseline_ms),
        },
        "conditioned_cascade_denoiser": {
            "parameters": conditioned_params,
            "estimated_conv_macs_per_1s_clip": int(conditioned_conv_macs_per_point * points),
            "latency": stats(conditioned_ms),
        },
        "parameter_reduction_fraction": float(1 - conditioned_params / baseline_params),
        "estimated_conv_mac_reduction_fraction": float(
            1 - conditioned_conv_macs_per_point / baseline_conv_macs_per_point),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
