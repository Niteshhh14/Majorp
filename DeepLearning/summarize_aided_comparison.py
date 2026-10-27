"""Summarize MATLAB matched-aided metrics for a saved validation comparison."""
from __future__ import annotations

import argparse
import csv
import math
from collections import defaultdict
from pathlib import Path
from statistics import mean, median


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = ROOT / "Results" / "DeepLearning" / "pilot_sisdr_crops" / "aided_reference_metrics.csv"
DEFAULT_OUTPUT = ROOT / "Results" / "DeepLearning" / "pilot_sisdr_crops" / "aided_reference_summary.md"


def number(value: str) -> float | None:
    try:
        result = float(value)
    except (TypeError, ValueError):
        return None
    return result if math.isfinite(result) else None


def stats(values: list[float]) -> str:
    if not values:
        return "n/a"
    return f"n={len(values)}, mean={mean(values):+.4f}, median={median(values):+.4f}"


def build_report(input_path: Path) -> str:
    with input_path.open("r", newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ValueError(f"No comparison rows found in {input_path}")

    neural_sisdr = [number(row["neural_delta_sisdr_db"]) for row in rows]
    classical_sisdr = [number(row["classical_delta_sisdr_db"]) for row in rows]
    neural_stoi = [number(row["neural_delta_stoi"]) for row in rows]
    classical_stoi = [number(row["classical_delta_stoi"]) for row in rows]
    paired_sisdr = [n - c for n, c in zip(neural_sisdr, classical_sisdr)
                    if n is not None and c is not None]
    paired_stoi = [n - c for n, c in zip(neural_stoi, classical_stoi)
                   if n is not None and c is not None]
    valid_neural_stoi = [v for v in neural_stoi if v is not None]
    valid_classical_stoi = [v for v in classical_stoi if v is not None]

    lines = [
        "# Validation-only matched aided comparison",
        "",
        f"Source: `{input_path.relative_to(ROOT).as_posix()}`",
        f"Cases: {len(rows)}. MATLAB CVBW was applied consistently to clean, noisy, classical, and neural audio.",
        "The reported deltas compare each enhanced aided output against its noisy aided input, using the same aided-clean reference.",
        "",
        "## Aggregate changes",
        "",
        f"- Classical paired aided SI-SDR change: {stats([v for v in classical_sisdr if v is not None])} dB; positive in {sum(v is not None and v > 0 for v in classical_sisdr)}/{len(rows)} cases.",
        f"- Neural paired aided SI-SDR change: {stats([v for v in neural_sisdr if v is not None])} dB; positive in {sum(v is not None and v > 0 for v in neural_sisdr)}/{len(rows)} cases.",
        f"- Neural minus classical SI-SDR change: {stats(paired_sisdr)} dB; neural higher in {sum(v > 0 for v in paired_sisdr)}/{len(paired_sisdr)} cases.",
        f"- Classical paired aided STOI change: {stats(valid_classical_stoi)}; positive in {sum(v > 0 for v in valid_classical_stoi)}/{len(valid_classical_stoi)} valid cases.",
        f"- Neural paired aided STOI change: {stats(valid_neural_stoi)}; positive in {sum(v > 0 for v in valid_neural_stoi)}/{len(valid_neural_stoi)} valid cases.",
        f"- Neural minus classical STOI change: {stats(paired_stoi)}; neural higher in {sum(v > 0 for v in paired_stoi)}/{len(paired_stoi)} valid paired cases.",
        "",
        "## SI-SDR difference by audiogram profile",
        "",
        "| Profile | Cases | Mean neural-minus-classical aided SI-SDR change (dB) | Neural wins |",
        "|---:|---:|---:|---:|",
    ]
    profiles: dict[str, list[float]] = defaultdict(list)
    for row, n, c in zip(rows, neural_sisdr, classical_sisdr):
        if n is not None and c is not None:
            profiles[row["profile_id"]].append(n - c)
    for profile in sorted(profiles, key=int):
        values = profiles[profile]
        lines.append(f"| {profile} | {len(values)} | {mean(values):+.4f} | {sum(v > 0 for v in values)}/{len(values)} |")

    lines.extend([
        "",
        "## Interpretation limits",
        "",
        "This is a model-tuning result on 32 selected validation mixtures from seven validation speakers, not a held-out test result. Profile IDs are experimental presets and are not linked to the speakers' clinical audiograms. The neural checkpoint was selected using pre-CVBW metrics, so this comparison is an audit of its aided behavior, not evidence that it was trained for aided performance. STOI is missing for some cases and is not imputed. Do not claim clinical benefit or generalization to unseen noise scenes; DEMAND scenes are shared across the current speaker splits.",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    report = build_report(args.input.resolve())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(report, encoding="utf-8")
    print(report)
    print(f"\nSaved: {args.output}")


if __name__ == "__main__":
    main()
