# Validation-only matched aided comparison

Source: `Results/DeepLearning/conditioned_cascade_128/aided_reference_metrics.csv`
Cases: 32. MATLAB CVBW was applied consistently to clean, noisy, classical, and neural audio.
The reported deltas compare each enhanced aided output against its noisy aided input, using the same aided-clean reference.

## Aggregate changes

- Classical paired aided SI-SDR change: n=32, mean=+1.5663, median=+2.7416 dB; positive in 21/32 cases.
- Neural paired aided SI-SDR change: n=32, mean=+4.4102, median=+2.6290 dB; positive in 29/32 cases.
- Neural minus classical SI-SDR change: n=32, mean=+2.8439, median=+1.4473 dB; neural higher in 20/32 cases.
- Classical paired aided STOI change: n=30, mean=-0.0344, median=-0.0082; positive in 13/30 valid cases.
- Neural paired aided STOI change: n=30, mean=+0.0230, median=+0.0160; positive in 27/30 valid cases.
- Neural minus classical STOI change: n=30, mean=+0.0574, median=+0.0537; neural higher in 28/30 valid paired cases.

## SI-SDR difference by audiogram profile

| Profile | Cases | Mean neural-minus-classical aided SI-SDR change (dB) | Neural wins |
|---:|---:|---:|---:|
| 1 | 8 | +6.4433 | 7/8 |
| 4 | 8 | -1.3047 | 1/8 |
| 35 | 8 | +5.3970 | 7/8 |
| 36 | 8 | +0.8399 | 5/8 |

## Interpretation limits

This is a model-tuning result on 32 selected validation mixtures from seven validation speakers, not a held-out test result. Profile IDs are experimental presets and are not linked to the speakers' clinical audiograms. The neural checkpoint was selected using pre-CVBW metrics, so this comparison is an audit of its aided behavior, not evidence that it was trained for aided performance. STOI is missing for some cases and is not imputed. Do not claim clinical benefit or generalization to unseen noise scenes; DEMAND scenes are shared across the current speaker splits.
