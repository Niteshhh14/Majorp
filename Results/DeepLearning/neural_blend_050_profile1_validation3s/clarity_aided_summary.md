# Official Clarity metric summary

Cases: 8. Higher scores indicate better predicted performance.
The HASQI column uses Clarity's equalisation=1 (NAL-R applied to reference); this is not a CVBW-matched reference.
The common digital-to-SPL mapping assumes clean-reference RMS 1 corresponds to 65 dB SPL; no physical calibration was measured.

## Overall means

| Metric | Noisy + CVBW | Spectral subtraction + CVBW | Neural + CVBW | Neural − classical | Neural wins |
|---|---:|---:|---:|---:|---:|
| HASPI | 0.3067 | 0.3349 | 0.3239 | -0.0110 | 4/8 |
| HASQI (NAL-R reference) | 0.0472 | 0.0413 | 0.0467 | +0.0054 | 7/8 |

## Neural minus classical by audiogram profile

| Profile | n | Mean HASPI delta | HASPI wins | Mean HASQI delta | HASQI wins |
|---:|---:|---:|---:|---:|---:|
| 1 | 8 | -0.0110 | 4/8 | +0.0054 | 7/8 |

## Interpretation limits

These are exploratory validation estimates, not test or clinical results. The model was trained/selected using pre-CVBW losses; this is an aided-metric audit. Profile IDs are preset audiograms, not listener-linked measurements. HASQI compares against NAL-R reference even though the output uses project CVBW. The standardized level mapping is an assumption, and the current validation set reuses DEMAND environments across splits. Preserve the held-out test set until method selection is frozen.
