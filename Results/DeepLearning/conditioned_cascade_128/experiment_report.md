# Audiogram-conditioned CVBW cascade pilot

Date: 2026-11-08
Status: validation pilot; held-out test speakers were not accessed.

## What was compared

The new model receives a noisy 16 kHz speech clip and a six-frequency audiogram vector. Its compact neural mask denoiser is followed by the unchanged MATLAB CVBW stage. The training loss weights spectral errors using the profile thresholds. Baselines are the frozen spectral-subtraction-plus-CVBW system and the existing profile-independent neural-denoiser-plus-CVBW system.

Training used 128 distinct VCTK training utterances, each paired with four project profiles (1, 4, 35, 36), for 512 profile-conditioned rows, five epochs, seed 271828. Checkpoints were selected by validation loss (best epoch 4). Validation used the same deterministic 32 one-second mixtures as the earlier aided audit, from seven validation speakers, eight cases per profile. Hash comparison confirmed the regenerated clean/noisy validation WAVs exactly match the prior audit's files. No test speaker was used.

The six threshold inputs are sampled at 250, 500, 1000, 2000, 4000, and 6000 Hz from the project audiogram definitions. They are example profiles, not measured audiograms belonging to VCTK speakers. The training loss's frequency weighting is a provisional heuristic; it is not a calibrated auditory/perceptual model.

## Aided validation results

All audio was passed through the same MATLAB CVBW code where applicable. SI-SDR and STOI compare each aided output to the correspondingly aided clean reference; the changes below are relative to the aided noisy mixture.

| System | Mean paired aided SI-SDR change vs noisy | Mean paired aided STOI change vs noisy |
|---|---:|---:|
| Spectral subtraction + CVBW | +1.566 dB (21/32 positive) | -0.0344 (13/30 positive) |
| Existing profile-independent neural + CVBW | +4.887 dB | +0.0212 (30 valid cases) |
| Audiogram-conditioned neural + CVBW | +4.410 dB (29/32 positive) | +0.0230 (27/30 positive) |

For the direct conditioned-versus-classical paired differences, aided SI-SDR averages +2.844 dB and is higher in 20/32 cases. Aided STOI averages +0.0574 and is higher in 28/30 valid paired cases. The conditioned model versus the existing neural baseline changes mean aided SI-SDR by -0.477 dB (higher in 12/32 cases) and mean aided STOI by +0.00183 (higher in 16/30 cases). This is effectively similar STOI with a small average SI-SDR loss, not a clear quality improvement over the existing neural system.

Profile dependence remains important. Versus classical:

| Profile | Aided SI-SDR difference, wins | Aided STOI difference, valid cases |
|---:|---:|---:|
| 1 | +6.443 dB, 7/8 | +0.0723, 8 |
| 4 | -1.305 dB, 1/8 | +0.0375, 7 |
| 35 | +5.397 dB, 7/8 | +0.0569, 8 |
| 36 | +0.840 dB, 5/8 | +0.0609, 7 |

Profile 4 remains a failure area for SI-SDR and must not be hidden by the overall mean.

## Computation comparison

Measured on the same CPU/Python process with four PyTorch threads, batch size 1, one-second inputs, warm-up, and audio I/O excluded:

| Denoiser | Parameters | Estimated convolution MACs per one-second clip | Median model latency | p95 latency |
|---|---:|---:|---:|---:|
| Existing profile-independent mask CNN | 10,681 | 343.5 million | 21.44 ms | 25.74 ms |
| Audiogram-conditioned mask CNN | 3,741 | 115.8 million | 18.63 ms | 21.74 ms |

The conditioned neural stage uses about 65% fewer parameters, 66% fewer convolution MACs, and 13% less measured neural-stage latency. This supports a component-level computation/size improvement while aided STOI is nearly unchanged relative to the earlier neural baseline. The CVBW stage is shared and dominates complete MATLAB pipeline runtime: its mean was 3.768 seconds per one-second clip across the same eight benchmark cases. Replacing the baseline neural network saves about 2.9 ms while leaving CVBW in place, roughly 0.08% of estimated full pipeline time. Therefore this is a neural-stage computation reduction, not a meaningful end-to-end speedup. Do not claim a real-time or total-system speed improvement from this result.

## Failed direct-to-CVBW model probe

A separate model trained to predict CVBW-processed clean magnitude directly was much faster than the MATLAB classical pipeline but unusable in this pilot: mean aided-reference SI-SDR was about -46.16 dB and mean STOI about 0.538. It retained noisy phase and did not learn the CVBW phase behavior from the small training sample. Its speed is not a valid system improvement because output quality collapses. Details are in `audiogram_conditioned_pilot/validation_summary.json` and `validation_comparison.csv`.

## Conclusion and next work

The current validation pilot shows a promising computation/size trade-off inside the neural stage: substantially fewer learned operations with near-equal aided STOI versus the profile-independent neural baseline. The conditioned cascade also exceeds classical CVBW on the current aided STOI aggregate. Evidence is limited to 32 short validation mixtures and seven speakers; two STOI cases are missing, DEMAND noise scenes overlap across splits, the profile-4 SI-SDR result is weak, and no confidence interval or independent test result exists. This is not yet a paper-ready superiority claim.

Next: check profile-4 failures and STOI validity, increase validation coverage across longer utterances/noises/SNRs, measure complete-pipeline runtime consistently, and only then freeze the model and evaluate the untouched test speakers once. Keep CVBW parameters and classical baseline frozen during tuning.
