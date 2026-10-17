"""Evaluate a saved mask model on one frozen manifest split."""
from __future__ import annotations

import argparse
import importlib.metadata
import json
from pathlib import Path

import torch

from train_speech_enhancer import (DEFAULT_MANIFEST, DEFAULT_NOISE, ROOT,
                                   PairedVctkDemand, SpectralMaskNet, evaluate)
from torch.utils.data import DataLoader


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--noise-root", type=Path, default=DEFAULT_NOISE)
    parser.add_argument("--split", choices=("validation", "test"), default="validation")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--segment-seconds", type=float, default=1.0)
    parser.add_argument("--seed", type=int, default=271829)
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--limit", type=int, help="deterministic random subset for a quick pilot")
    parser.add_argument("--audio-dir", type=Path, help="export paired WAVs for MATLAB CVBW evaluation")
    args = parser.parse_args()

    torch.set_num_threads(args.threads)
    torch.set_num_interop_threads(1)
    checkpoint = torch.load(args.checkpoint, map_location="cpu", weights_only=True)
    model = SpectralMaskNet()
    model.load_state_dict(checkpoint["state_dict"])
    dataset = PairedVctkDemand(args.manifest, args.noise_root, args.split,
                               int(args.segment_seconds * 16000), args.seed, args.limit)
    loader = DataLoader(dataset, batch_size=args.batch_size, shuffle=False, num_workers=0)
    output = args.output or (ROOT / "Results" / "DeepLearning" /
                             f"{args.split}_evaluation.csv")
    rows, metrics = evaluate(model, loader, torch.device("cpu"), output, args.audio_dir)
    try:
        checkpoint_path = args.checkpoint.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        checkpoint_path = str(args.checkpoint.resolve())
    summary = {
        "split": args.split, "rows": len(rows), "unique_speakers": len({r["speaker"] for r in rows}),
        "checkpoint": checkpoint_path, "seed": args.seed,
        "sample_rate": 16000, "segment_seconds": args.segment_seconds,
        "metrics_pre_cvbw": metrics,
        "package_versions": {name: importlib.metadata.version(name)
                             for name in ("torch", "numpy", "scipy", "soundfile", "pystoi")},
    }
    summary_path = output.with_suffix(".json")
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
