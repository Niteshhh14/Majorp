# Stable-scene three-second aided validation

**Status:** validation-only exploratory result; not held-out test evidence.

The frequency-corrected audiogram-conditioned neural denoiser was run on a 32-case, three-second validation snapshot, then passed through the existing MATLAB CVBW stage. The same saved mixtures and audiogram profiles were used for noisy, classical spectral-subtraction, and neural processing. Duration-invariant scene selection kept case identity, speaker, utterance, DEMAND noise file, and SNR stable across crop durations. There are seven validation speakers and eight cases per each of profiles 1, 4, 35, and 36.

## Aided results

| Measure | Classical spectral subtraction | Neural model |
|---|---:|---:|
| Aided SI-SDR change vs noisy (mean) | +3.1642 dB | +4.0876 dB |
| Aided SI-SDR positive cases | 29/32 | 29/32 |
| Aided STOI change vs noisy (mean) | +0.0080 | +0.0253 |
| Aided STOI positive cases | 26/32 | 28/32 |

Neural-minus-classical paired differences are +0.9234 dB mean SI-SDR (median +0.2192; neural higher in 17/32) and +0.0173 mean STOI (median +0.0050; neural higher in 22/32).

| Profile | n | Neural-minus-classical aided SI-SDR | Neural wins |
|---:|---:|---:|---:|
| 1 | 8 | +4.0108 dB | 7/8 |
| 4 | 8 | -1.8510 dB | 1/8 |
| 35 | 8 | +2.6050 dB | 6/8 |
| 36 | 8 | -1.0713 dB | 3/8 |

## Compute and limits

The neural stage used 3,741 parameters and averaged 40.40 ms per 3-second clip (13.47 ms per second of audio) in the recorded CPU run. This omits MATLAB CVBW; it is not end-to-end latency. CVBW currently dominates measured pipeline time.

This is 32 selected validation cases, not a frozen held-out test. The neural model was trained/selected with pre-CVBW objectives, not an aided-intelligibility loss. Profiles are experimental presets, not listener-matched audiograms. The validation speakers are few and DEMAND noise environments overlap data splits. HASPI/HASQI and calibrated sound-level conventions have not been validated here. The aggregate favors neural processing on this sample, but per-profile regressions for profiles 4 and 36 rule out a claim of uniform improvement. Use this report to motivate metric calibration and profile-focused validation, not as proof of superiority or clinical benefit.

Inputs and per-case outputs are recorded in `aided_reference_metrics.csv`, `prepared/validation_pairs.csv`, and `audio/`. The checkpoint used is `Results/DeepLearning/conditioned_cascade_freqcorrect_128/best_model.pt` (local generated model artifact; not committed).

## Official Clarity aided metric audit (2026-11-09)

pyClarity 0.9.0 HASPI v2 and HASQI v2 were run on all 32 cases through the actual default (peak-normalized) MATLAB CVBW behavior. For each case, the unamplified clean reference was scaled to RMS 1 (assumed 65 dB SPL) and the same scalar was applied to noisy, classical, and neural CVBW outputs. This standard mapping is not a measured physical calibration. HASQI used `equalisation=1`, which adds NAL-R to the reference; that prescription differs from the project's CVBW and is an explicitly secondary quality comparison.

| Metric | Noisy + CVBW | Spectral subtraction + CVBW | Neural + CVBW | Neural − classical | Neural wins |
|---|---:|---:|---:|---:|---:|
| HASPI v2 | 0.1179 | 0.1285 | 0.1172 | -0.0114 | 18/32 |
| HASQI v2 (NAL-R reference) | 0.0165 | 0.0145 | 0.0131 | -0.0014 | 15/32 |

Profile-wise neural-minus-classical differences:

| Profile | n | HASPI delta / wins | HASQI delta / wins |
|---:|---:|---:|---:|
| 1 | 8 | -0.0506 / 5 | -0.0066 / 4 |
| 4 | 8 | +0.0042 / 6 | +0.0009 / 6 |
| 35 | 8 | +0.0010 / 1 | +0.0000 / 0 |
| 36 | 8 | -0.0002 / 6 | +0.0001 / 5 |

This contradicts a claim that the current neural checkpoint improves aided performance overall: it has better paired SI-SDR/STOI averages but lower Clarity aided intelligibility/quality means than spectral subtraction. The score distribution is highly scene-dependent and some profound-profile scores approach the metric floor. The current neural checkpoint was selected using pre-CVBW losses. This metric audit motivates aided-objective model selection/training; it is not test evidence and does not validate clinical benefit. Full per-case scores and interpretation are in `clarity_aided_metrics.csv` and `clarity_aided_summary.md`.
