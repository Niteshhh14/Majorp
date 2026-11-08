# Profile-1 25% neural-strength probe

**Purpose:** test a less aggressive enhancement setting after the 50% strength probe showed an aided HASPI/HASQI gain but a substantial SI-SDR/STOI decrease.

**Method:** on the same eight profile-1, three-second validation cases, blend the neural pre-CVBW output with noisy speech using `noisy + 0.25 * (neural - noisy)`. The unchanged default peak-normalized MATLAB CVBW stage was applied. The official Clarity HASPI/HASQI run is pending; this report must not be treated as an aided-intelligibility result.

## Available metrics

| Measure | 25% blend | Original neural | Classical reference |
|---|---:|---:|---:|
| Mean aided SI-SDR change vs noisy | +1.407 dB | +7.547 dB | +3.536 dB |
| Mean aided STOI change vs noisy | +0.00458 | +0.03498 | -0.00508 |

The 25% blend was lower than the original neural output by 6.14 dB aided SI-SDR and 0.0304 STOI on average; it was also lower than classical SI-SDR by 2.13 dB, while remaining 0.0097 higher in STOI. These are only eight validation cases. No model was retrained and no held-out test data was used.

## Pending

Run `DeepLearning/evaluate_clarity_metrics.py` with `--case-ids 1,5,9,13,17,21,25,29` using the generated `cvbw_peak_normalized_mat` files, then compare against the original and 50% blend. Do not infer HASPI/HASQI behavior from SI-SDR/STOI.
