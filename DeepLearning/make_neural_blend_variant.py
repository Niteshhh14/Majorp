"""Create a validation-only neural/noisy blend variant without changing the model."""
from __future__ import annotations

import argparse
import csv
from pathlib import Path
import shutil

import numpy as np
import soundfile as sf


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--strength", type=float, required=True)
    parser.add_argument("--profiles", type=int, nargs="+", required=True)
    args = parser.parse_args()
    if not 0.0 <= args.strength <= 1.0:
        raise ValueError("strength must lie in [0, 1]")
    if args.output_dir.exists():
        raise FileExistsError(f"Output directory already exists: {args.output_dir}")

    shutil.copytree(args.source_dir / "audio", args.output_dir / "audio")
    shutil.copy2(args.source_dir / "validation_metrics.csv", args.output_dir)
    (args.output_dir / "prepared").mkdir(parents=True)
    shutil.copy2(
        args.source_dir / "prepared" / "validation_pairs.csv",
        args.output_dir / "prepared" / "validation_pairs.csv",
    )
    with (args.source_dir / "prepared" / "validation_pairs.csv").open(
        newline="", encoding="utf-8-sig"
    ) as stream:
        manifest = list(csv.DictReader(stream))

    changed = []
    for row in manifest:
        if int(row["profile_id"]) not in args.profiles:
            continue
        case_id = int(row["case_id"])
        prefix = f"case_{case_id:03d}_"
        noisy_path = args.output_dir / "audio" / f"{prefix}noisy.wav"
        neural_path = args.output_dir / "audio" / f"{prefix}neural.wav"
        noisy, fs_noisy = sf.read(noisy_path, dtype="float32")
        neural, fs_neural = sf.read(neural_path, dtype="float32")
        if fs_noisy != fs_neural or noisy.shape != neural.shape or noisy.ndim != 1:
            raise ValueError(f"Input shapes/rates disagree for case {case_id}")
        blended = noisy + args.strength * (neural - noisy)
        sf.write(neural_path, blended.astype(np.float32), fs_neural, subtype="FLOAT")
        changed.append(case_id)

    if not changed:
        raise ValueError("No cases matched the requested profile IDs")
    report = args.output_dir / "blend_variant.txt"
    report.write_text(
        f"Validation-only blend variant\nstrength={args.strength}\n"
        f"profiles={args.profiles}\ncase_ids={changed}\n"
        "formula=noisy + strength * (neural - noisy)\n"
        "CVBW is still applied by MATLAB after blending.\n",
        encoding="utf-8",
    )
    print(f"Created variant for {len(changed)} cases in {args.output_dir}")


if __name__ == "__main__":
    main()
