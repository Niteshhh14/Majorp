"""Compute official Clarity HASPI/HASQI on level-preserved MATLAB CVBW outputs.

The clean reference is unamplified. A single per-case scalar maps its RMS to 1,
which Clarity maps to `level1` dB SPL. That same scalar is applied to every
compared output; output-specific normalization is deliberately prohibited.
HASQI v2's equalisation=1 applies NAL-R to its reference internally, so its
score is reported with that prescription mismatch disclosed (our HA output uses
the project's CVBW fitting). SI-SDR/STOI against the CVBW-clean target remain
separate project-specific diagnostics.
"""
from __future__ import annotations

import argparse
import csv
from pathlib import Path

import numpy as np
from scipy.io import loadmat

from clarity.evaluator.haspi import haspi_v2
from clarity.evaluator.hasqi import hasqi_v2
from clarity.utils.audiogram import Audiogram
from train_audiogram_conditioned import PROFILE_THRESHOLDS


FS = 16_000
AUDIOGRAM_FREQUENCIES = np.array([250, 500, 1000, 2000, 4000, 6000])
SIGNALS = ("noisyAided", "classicalAided", "neuralAided")


def _vector(mat: dict, name: str) -> np.ndarray:
    signal = np.asarray(mat[name], dtype=np.float64).squeeze()
    if signal.ndim != 1 or signal.size < FS:
        raise ValueError(f"{name} must be a 1-D signal of at least 1s")
    if not np.isfinite(signal).all():
        raise ValueError(f"{name} contains NaN or Inf")
    return signal


def score_case(path: Path, case_id: int, profile_id: int, level1: float) -> dict:
    mat = loadmat(path)
    reference = _vector(mat, "cleanReference")
    rms = float(np.sqrt(np.mean(reference**2)))
    if not np.isfinite(rms) or rms <= 1e-12:
        raise ValueError(f"Invalid clean-reference RMS in {path}")
    gain = 1.0 / rms
    ref_calibrated = reference * gain
    audiogram = Audiogram(
        levels=np.asarray(PROFILE_THRESHOLDS[profile_id], dtype=float),
        frequencies=AUDIOGRAM_FREQUENCIES,
    )

    row: dict[str, float | int] = {
        "case_id": case_id,
        "profile_id": profile_id,
        "reference_rms_before_calibration": rms,
        "common_calibration_gain": gain,
        "level1_db_spl_at_rms_1": level1,
        "reference_calibrated_rms": float(np.sqrt(np.mean(ref_calibrated**2))),
    }
    for signal_name in SIGNALS:
        processed = _vector(mat, signal_name)
        length = min(reference.size, processed.size)
        processed_calibrated = processed[:length] * gain
        ref = ref_calibrated[:length]
        row[f"{signal_name}_rms_db_spl"] = float(
            level1 + 20 * np.log10(max(np.sqrt(np.mean(processed_calibrated**2)), 1e-15))
        )
        row[f"haspi_{signal_name}"] = float(
            haspi_v2(ref, FS, processed_calibrated, FS, audiogram, level1=level1)[0]
        )
        # Clarity HASQI v2 equalisation=1 applies NAL-R to the reference.
        # This is not the project's CVBW prescription; retain it as a clearly
        # labeled secondary standard score, not an exact CVBW-target metric.
        row[f"hasqi_nalr_reference_{signal_name}"] = float(
            hasqi_v2(
                ref,
                FS,
                processed_calibrated,
                FS,
                audiogram,
                equalisation=1,
                level1=level1,
            )[0]
        )
    return row


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifact-dir", type=Path, required=True)
    parser.add_argument(
        "--cvbw-mode",
        choices=("level_preserved", "peak_normalized"),
        default="peak_normalized",
        help="Select the exact saved MATLAB CVBW behavior being evaluated.",
    )
    parser.add_argument("--case-limit", type=int, default=0)
    parser.add_argument(
        "--case-ids",
        type=str,
        default="",
        help="Optional comma-separated case IDs to score from a subset run.",
    )
    parser.add_argument("--level1-db-spl", type=float, default=65.0)
    args = parser.parse_args()
    manifest_path = args.artifact_dir / "prepared" / "validation_pairs.csv"
    raw_dir = args.artifact_dir / f"cvbw_{args.cvbw_mode}_mat"
    with manifest_path.open(newline="", encoding="utf-8-sig") as stream:
        manifest = list(csv.DictReader(stream))
    if args.case_ids:
        selected_ids = {int(value.strip()) for value in args.case_ids.split(",") if value.strip()}
        manifest = [row for row in manifest if int(row["case_id"]) in selected_ids]
        missing_ids = selected_ids - {int(row["case_id"]) for row in manifest}
        if missing_ids:
            raise ValueError(f"Requested case IDs are absent from manifest: {sorted(missing_ids)}")
    if args.case_limit:
        manifest = manifest[: args.case_limit]
    rows = []
    for index, case in enumerate(manifest, 1):
        case_id = int(case["case_id"])
        profile_id = int(case["profile_id"])
        row = score_case(
            raw_dir / f"case_{case_id:03d}.mat",
            case_id,
            profile_id,
            args.level1_db_spl,
        )
        row["speaker"] = case["speaker"]
        row["input_snr_db"] = float(case["input_snr_db"])
        rows.append(row)
        print(
            f"{index}/{len(manifest)} case {case_id:03d} profile {profile_id}: "
            f"HASPI neural={row['haspi_neuralAided']:.4f} "
            f"HASQI(NAL-R ref) neural={row['hasqi_nalr_reference_neuralAided']:.4f}",
            flush=True,
        )

    output = args.artifact_dir / "clarity_aided_metrics.csv"
    with output.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {len(rows)} scored cases to {output}")


if __name__ == "__main__":
    main()
