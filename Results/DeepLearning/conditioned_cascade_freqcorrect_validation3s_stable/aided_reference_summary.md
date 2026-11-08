# Validation-only matched aided comparison

Source: `Results/DeepLearning/conditioned_cascade_freqcorrect_validation3s_stable/aided_reference_metrics.csv`
Cases: 32. MATLAB CVBW was applied consistently to clean, noisy, classical, and neural audio.
The reported deltas compare each enhanced aided output against its noisy aided input, using the same aided-clean reference.

## Aggregate changes

- Classical paired aided SI-SDR change: n=32, mean=+3.1642, median=+3.8533 dB; positive in 29/32 cases.
- Neural paired aided SI-SDR change: n=32, mean=+4.0876, median=+2.7559 dB; positive in 29/32 cases.
- Neural minus classical SI-SDR change: n=32, mean=+0.9234, median=+0.2192 dB; neural higher in 17/32 cases.
- Classical paired aided STOI change: n=32, mean=+0.0080, median=+0.0115; positive in 26/32 valid cases.
- Neural paired aided STOI change: n=32, mean=+0.0253, median=+0.0199; positive in 28/32 valid cases.
- Neural minus classical STOI change: n=32, mean=+0.0173, median=+0.0050; neural higher in 22/32 valid paired cases.

## SI-SDR difference by audiogram profile

| Profile | Cases | Mean neural-minus-classical aided SI-SDR change (dB) | Neural wins |
|---:|---:|---:|---:|
| 1 | 8 | +4.0108 | 7/8 |
| 4 | 8 | -1.8510 | 1/8 |
| 35 | 8 | +2.6050 | 6/8 |
| 36 | 8 | -1.0713 | 3/8 |

## Interpretation limits

This is a model-tuning result on 32 selected validation mixtures from seven validation speakers, not a held-out test result. Profile IDs are experimental presets and are not linked to the speakers' clinical audiograms. The neural checkpoint was selected using pre-CVBW metrics, so this comparison is an audit of its aided behavior, not evidence that it was trained for aided performance. All paired STOI values are finite for this set. Do not claim clinical benefit or generalization to unseen noise scenes; DEMAND scenes are shared across the current speaker splits.
