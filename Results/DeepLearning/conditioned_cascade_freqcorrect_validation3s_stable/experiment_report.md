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
