# Profile-1 50% neural-strength probe

**Purpose:** check whether reducing the current neural enhancer's strength can mitigate its aided HASPI regression for profile 1. This is a validation-only control probe, not a new trained model.

**Method:** for profile-1 cases only, replace the neural pre-CVBW signal by `noisy + 0.5 * (neural - noisy)`. Apply the unchanged default peak-normalized MATLAB CVBW function. The same eight fixed 3-second validation cases were used as the unmodified model. No held-out test cases were used.

## Results on the eight profile-1 cases

| Metric | Original neural | 50% blend | Classical reference |
|---|---:|---:|---:|
| Mean HASPI v2 | 0.284 (approx.) | 0.3239 | 0.3349 |
| Mean HASQI v2, NAL-R reference | 0.0347 (approx.) | 0.0467 | 0.0413 |
| Mean aided SI-SDR change vs noisy | +7.547 dB | +3.225 dB | +3.536 dB |
| Mean aided STOI change vs noisy | +0.03498 | +0.01075 | -0.00508 |

Against the original neural output, the blend increased HASPI by about 0.040 and HASQI by 0.012. It remained 0.011 below classical HASPI, while exceeding classical HASQI by 0.0054. Neural-minus-classical SI-SDR was -0.311 dB; STOI was +0.0158. The profile-1 subset has only eight cases, and HASQI uses Clarity `equalisation=1` (NAL-R reference), not a CVBW-matched reference. SPL mapping is the shared RMS-1-to-65-dB-SPL assumption described in `DeepLearning/CLARITY_METRICS_SETUP.md`.

**Conclusion:** mixed trade-off, not a demonstrated overall win. It shows that the pre-CVBW operating point affects post-CVBW metric rankings, motivating objective-aware model selection. Do not deploy this strength setting or transfer the validation gain to a held-out population without testing.
