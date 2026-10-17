# Deep-learning speech enhancement experiment

## Purpose and status

This folder starts the neural speech-enhancement comparison against the frozen classical baseline (spectral subtraction `alpha=1.15`, `floorFactor=0.04`, followed by the same profile-specific CVBW stage). The goal is a controlled enhancement comparison, not a clinical-benefit claim.

The first concrete experiment artifact is `splits/vctk_speaker_split.csv`. It indexes VCTK mic1 utterances by relative path and assigns whole speakers to a split, so a speaker cannot occur in both training and evaluation. The current manifest uses seed `271828` and contains 28,529 utterances across 56 train, 7 validation, and 8 test speakers. It can be regenerated from the repository root with:

```powershell
./DeepLearning/prepare_vctk_split.ps1
```

The manifest contains paths and split labels only; the speech corpus remains local and excluded from Git. DEMAND recordings are available locally as well.

## Supplied code review

`Available_source_code/_CVBW_code_unpacked/cvbw_deepfit/` is a research reference implementation for audiogram-conditioned denoising and CVBW fusion. Its `train.py` currently trains on generated tones and random noise, not VCTK/DEMAND. The implementation guide explicitly leaves the real corpus loader and several perceptual objectives as future work. Its smoke test therefore cannot be reported as project speech-enhancement performance.

## Experimental protocol to implement

1. Freeze this speaker split and publish its seed/hash with every model artifact.
2. Build deterministic 16 kHz paired crops from VCTK clean speech and DEMAND noise. Sample and record noise file, crop offset, channel, and SNR. Avoid sharing source utterances across splits; report the precise noise split policy.
3. Train a modest STFT mask model on train speakers, select settings only on validation speakers, and keep the test speakers untouched until evaluation.
4. Use exactly the existing evaluation cases and clean/noisy references for both systems. Apply the same CVBW profile after enhancement and use the matched aided-reference protocol for STOI and SI-SDR. Include case 10 and profile-4 samples 06/10 as named regression checks.
5. Save configuration, software versions, checkpoint, per-case metrics, aggregate metrics, and failure notes. Compare quality and runtime; do not claim all cases improve if a metric regresses.

## Current execution blocker (2026-10-17)

Training has not started. `python --version` reports Python 3.13.2, but invoking Python fails with “Failed to find real location” for its executable; PyTorch, SciPy, SoundFile, librosa, and pystoi are not installed in the visible Python runtime. MATLAB R2026a batch startup was retried with the project-local writable `.matlabprefs` directory but stopped with MathWorks service error 5201. No model training/evaluation output exists.

Before training, restore a working MATLAB session or install a supported Python environment with PyTorch, NumPy, SciPy, SoundFile, and STOI support. Then implement and smoke-test the real paired-audio loader and model; the synthetic-tone smoke test is not sufficient. Keep the baseline and split fixed while doing this.
