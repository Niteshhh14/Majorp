# Validation-only matched aided comparison

Source: `Results/DeepLearning/conditioned_cascade_freqcorrect_validation3s/aided_reference_metrics.csv`
Cases: 32. MATLAB CVBW was applied consistently to clean, noisy, classical, and neural audio.
The reported deltas compare each enhanced aided output against its noisy aided input, using the same aided-clean reference.

## Aggregate changes

- Classical paired aided SI-SDR change: n=32, mean=+3.7218, median=+4.0687 dB; positive in 30/32 cases.
- Neural paired aided SI-SDR change: n=32, mean=+4.0304, median=+3.2381 dB; positive in 30/32 cases.
- Neural minus classical SI-SDR change: n=32, mean=+0.3087, median=-0.5834 dB; neural higher in 14/32 cases.
- Classical paired aided STOI change: n=32, mean=+0.0048, median=+0.0131; positive in 23/32 valid cases.
- Neural paired aided STOI change: n=32, mean=+0.0214, median=+0.0210; positive in 26/32 valid cases.
- Neural minus classical STOI change: n=32, mean=+0.0166, median=+0.0060; neural higher in 19/32 valid paired cases.

## SI-SDR difference by audiogram profile

| Profile | Cases | Mean neural-minus-classical aided SI-SDR change (dB) | Neural wins |
|---:|---:|---:|---:|
| 1 | 8 | +4.0379 | 6/8 |
| 4 | 8 | -2.6284 | 0/8 |
| 35 | 8 | +2.5503 | 7/8 |
| 36 | 8 | -2.7251 | 1/8 |

## Interpretation limits

This is a model-tuning result on 32 selected validation mixtures from seven validation speakers, not a held-out test result. Profile IDs are experimental presets and are not linked to the speakers' clinical audiograms. The neural checkpoint was selected using pre-CVBW metrics, so this comparison is an audit of its aided behavior, not evidence that it was trained for aided performance. All paired STOI values are finite for this set. Do not claim clinical benefit or generalization to unseen noise scenes; DEMAND scenes are shared across the current speaker splits.
