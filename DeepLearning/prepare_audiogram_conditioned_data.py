"""Export deterministic train/validation speech-noise pairs for CVBW targets."""
from __future__ import annotations

import argparse
import csv
from pathlib import Path

import soundfile as sf

from train_speech_enhancer import (DEFAULT_MANIFEST, DEFAULT_NOISE, ROOT,
                                   PairedVctkDemand, SR)

PROFILES = (1, 4, 35, 36)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--split", choices=("train", "validation"), required=True)
    parser.add_argument("--limit", type=int, default=32)
    parser.add_argument("--seed", type=int)
    parser.add_argument("--duration-seconds", type=float, default=1.0,
                        help="Speech/noise crop duration; use longer validation clips for intelligibility metrics.")
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    if args.duration_seconds <= 0:
        parser.error("--duration-seconds must be positive")

    seed = args.seed if args.seed is not None else (271828 if args.split == "train" else 271829)
    dataset = PairedVctkDemand(DEFAULT_MANIFEST, DEFAULT_NOISE, args.split,
                               round(SR * args.duration_seconds), seed, args.limit)
    audio_dir = args.output_dir / args.split / "audio"
    target_dir = args.output_dir / args.split / "targets"
    audio_dir.mkdir(parents=True, exist_ok=True)
    target_dir.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, object]] = []

    for item_index in range(len(dataset)):
        noisy, clean, speaker, speech_path, noise_path, clean_start, noise_start, snr = dataset[item_index]
        case_id = item_index + 1
        clean_path = audio_dir / f"case_{case_id:04d}_clean.wav"
        noisy_path = audio_dir / f"case_{case_id:04d}_noisy.wav"
        sf.write(clean_path, clean.numpy(), SR, subtype="PCM_16")
        sf.write(noisy_path, noisy.numpy(), SR, subtype="PCM_16")
        selected_profiles = PROFILES if args.split == "train" else (PROFILES[(item_index) % len(PROFILES)],)
        for profile in selected_profiles:
            target_path = target_dir / f"case_{case_id:04d}_profile_{profile:02d}_cvbw.wav"
            rows.append({
                "split": args.split, "case_id": case_id, "profile_id": profile,
                "speaker": speaker, "speech_path": speech_path,
                "noise_path": noise_path, "clean_crop_start_16k": int(clean_start),
                "noise_crop_start_16k": int(noise_start), "input_snr_db": int(snr),
                "clean_file": clean_path.relative_to(args.output_dir).as_posix(),
                "noisy_file": noisy_path.relative_to(args.output_dir).as_posix(),
                "target_file": target_path.relative_to(args.output_dir).as_posix(),
            })

    args.output_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = args.output_dir / f"{args.split}_pairs.csv"
    with manifest_path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {len(rows)} profile-conditioned rows from {len(dataset)} clips "
          f"({args.duration_seconds:g} s requested): {manifest_path}")


if __name__ == "__main__":
    main()
