# Audiogram-frequency loss interpolation correction

Date: 2026-11-08
Status: completed validation-only experiment; neutral performance outcome.

## Question

Did the audiogram-frequency weighting bug explain the poor profile-4 aided result?

## Change

The prior `audiogram_frequency_weights` mapped six thresholds at 250, 500, 1000, 2000, 4000, and 6000 Hz uniformly across 257 STFT bins. The corrected function maps the actual 16 kHz, 512-point STFT bin frequencies to the six anchors by log-frequency interpolation, holding endpoint thresholds outside the measured range. A tensor-level check confirmed a 4-by-257 weight matrix and distinct curves for all four profiles.

## Controlled protocol

- Same 128 unique VCTK training utterances and same 32 fixed validation mixtures as the earlier conditioned cascade.
- Each training utterance repeated for audiogram profiles 1, 4, 35, and 36.
- Seed 271828, five epochs, batch size 8; best checkpoint selected by pre-CVBW validation loss.
- MATLAB CVBW applied consistently to clean, noisy, spectral-subtraction, and neural signals for all 32 validation cases.
- No held-out test speakers used.

## Results

- Pre-CVBW mean SI-SDR: 11.246 dB; mean STOI: 0.7957.
- Paired aided neural-minus-classical SI-SDR: +2.8426 dB overall, neural higher in 20/32 cases.
- Paired aided neural-minus-classical STOI: +0.0573, neural higher in 28/30 valid paired cases.
- Profile 4 aided SI-SDR difference: -1.3136 dB, neural higher in 1/8 cases.

The previous run gave +2.8439 dB overall, +0.0574 STOI, and -1.3047 dB for profile 4. These results are essentially unchanged. Across matched CSV rows, case IDs, profile IDs, and SNR metadata agree; no join mismatches were found. Cases 2 and 16 have invalid/missing paired STOI. Maximum absolute difference across finite old/new per-case metrics is 0.1611, while the profile win counts are unchanged (1: 7/8, 4: 1/8, 35: 7/8, 36: 5/8).

## Interpretation

The old frequency mapping was incorrect and is fixed for methodological correctness. This experiment rejects the hypothesis that it caused the profile-4 regression. Do not report it as a performance improvement. The current six-profile-threshold loss weights remain heuristic; they are not a validated perceptual loss. A primary joint NR/HLC study also describes threshold interpolation on a logarithmic frequency axis ([arXiv:2603.20387](https://arxiv.org/abs/2603.20387)), but its auditory-model architecture and evaluation are not directly comparable to this pipeline.

## Next

Inspect the paired metric path and post-CVBW signal levels, then compare validation-only aided-metric checkpoint selection or a profile-4 targeted objective. Do not use held-out test speakers for this tuning. Preserve all outcomes and report missing metric counts.
