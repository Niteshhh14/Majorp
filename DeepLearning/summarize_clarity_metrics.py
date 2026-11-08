"""Create a per-method and per-audiogram summary of Clarity scores."""
from __future__ import annotations

import argparse
import csv
from pathlib import Path
import statistics


METHODS = ("noisyAided", "classicalAided", "neuralAided")
METRICS = {
    "HASPI": "haspi_{}",
    "HASQI (NAL-R reference)": "hasqi_nalr_reference_{}",
}


def mean(rows: list[dict], field: str) -> float:
    values = [float(row[field]) for row in rows]
    return statistics.mean(values)


def wins(rows: list[dict], left: str, right: str) -> int:
    return sum(float(row[left]) > float(row[right]) for row in rows)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("csv_path", type=Path)
    args = parser.parse_args()
    with args.csv_path.open(newline="", encoding="utf-8-sig") as stream:
        rows = list(csv.DictReader(stream))
    if not rows:
        raise SystemExit("No metric rows found")

    lines = [
        "# Official Clarity metric summary",
        "",
        f"Cases: {len(rows)}. Higher scores indicate better predicted performance.",
        "The HASQI column uses Clarity's equalisation=1 (NAL-R applied to reference); this is not a CVBW-matched reference.",
        "The common digital-to-SPL mapping assumes clean-reference RMS 1 corresponds to 65 dB SPL; no physical calibration was measured.",
        "",
        "## Overall means",
        "",
        "| Metric | Noisy + CVBW | Spectral subtraction + CVBW | Neural + CVBW | Neural − classical | Neural wins |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for label, pattern in METRICS.items():
        fields = {method: pattern.format(method) for method in METHODS}
        diff = [float(row[fields["neuralAided"]]) - float(row[fields["classicalAided"]]) for row in rows]
        lines.append(
            f"| {label} | {mean(rows, fields['noisyAided']):.4f} | "
            f"{mean(rows, fields['classicalAided']):.4f} | "
            f"{mean(rows, fields['neuralAided']):.4f} | "
            f"{statistics.mean(diff):+.4f} | "
            f"{sum(value > 0 for value in diff)}/{len(rows)} |"
        )

    lines.extend(["", "## Neural minus classical by audiogram profile", ""])
    lines.append("| Profile | n | Mean HASPI delta | HASPI wins | Mean HASQI delta | HASQI wins |")
    lines.append("|---:|---:|---:|---:|---:|---:|")
    for profile in sorted({int(row["profile_id"]) for row in rows}):
        group = [row for row in rows if int(row["profile_id"]) == profile]
        hdiff = [float(row["haspi_neuralAided"]) - float(row["haspi_classicalAided"]) for row in group]
        qdiff = [float(row["hasqi_nalr_reference_neuralAided"]) - float(row["hasqi_nalr_reference_classicalAided"]) for row in group]
        lines.append(
            f"| {profile} | {len(group)} | {statistics.mean(hdiff):+.4f} | "
            f"{sum(value > 0 for value in hdiff)}/{len(group)} | "
            f"{statistics.mean(qdiff):+.4f} | {sum(value > 0 for value in qdiff)}/{len(group)} |"
        )

    lines.extend(
        [
            "",
            "## Interpretation limits",
            "",
            "These are exploratory validation estimates, not test or clinical results. The model was trained/selected using pre-CVBW losses; this is an aided-metric audit. Profile IDs are preset audiograms, not listener-linked measurements. HASQI compares against NAL-R reference even though the output uses project CVBW. The standardized level mapping is an assumption, and the current validation set reuses DEMAND environments across splits. Preserve the held-out test set until method selection is frozen.",
            "",
        ]
    )
    output = args.csv_path.with_name("clarity_aided_summary.md")
    output.write_text("\n".join(lines), encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()
