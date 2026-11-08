# Official Clarity metric summary

Cases: 32. Higher scores indicate better predicted performance.
The HASQI column uses Clarity's equalisation=1 (NAL-R applied to reference); this is not a CVBW-matched reference.
The common digital-to-SPL mapping assumes clean-reference RMS 1 corresponds to 65 dB SPL; no physical calibration was measured.

## Overall means

| Metric | Noisy + CVBW | Spectral subtraction + CVBW | Neural + CVBW | Neural − classical | Neural wins |
|---|---:|---:|---:|---:|---:|
| HASPI | 0.1179 | 0.1285 | 0.1172 | -0.0114 | 18/32 |
| HASQI (NAL-R reference) | 0.0165 | 0.0145 | 0.0131 | -0.0014 | 15/32 |

## Neural minus classical by audiogram profile

| Profile | n | Mean HASPI delta | HASPI wins | Mean HASQI delta | HASQI wins |
|---:|---:|---:|---:|---:|---:|
| 1 | 8 | -0.0506 | 5/8 | -0.0066 | 4/8 |
| 4 | 8 | +0.0042 | 6/8 | +0.0009 | 6/8 |
| 35 | 8 | +0.0010 | 1/8 | +0.0000 | 0/8 |
| 36 | 8 | -0.0002 | 6/8 | +0.0001 | 5/8 |

## Interpretation limits

These are exploratory validation estimates, not test or clinical results. The model was trained/selected using pre-CVBW losses; this is an aided-metric audit. Profile IDs are preset audiograms, not listener-linked measurements. HASQI compares against NAL-R reference even though the output uses project CVBW. The standardized level mapping is an assumption, and the current validation set reuses DEMAND environments across splits. Preserve the held-out test set until method selection is frozen.
