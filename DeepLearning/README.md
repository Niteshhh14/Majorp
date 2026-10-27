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

## Training environment and command

Create a project-local environment on a Python 3.12 machine:

```powershell
py -3.12 -m venv DeepLearning/.venv
DeepLearning/.venv/Scripts/python.exe -m pip install -r DeepLearning/requirements.txt
DeepLearning/.venv/Scripts/python.exe DeepLearning/train_speech_enhancer.py --help
```

The local training entry point builds deterministic VCTK/DEMAND mixtures and evaluates the learned mask against both unprocessed mixtures and a Python port of `DSP/spectral_subtraction_enhance.m`. This first mask model is profile-independent; it learns noise suppression only, then profile-specific CVBW is applied afterward. `--limit-train` and `--limit-val` provide reproducible pilots. A full split is CPU-expensive; measure throughput before scheduling it, preferably use an available accelerator, and never select a model using test speakers. Metrics produced by this script are **pre-CVBW**. Final hearing-aid comparison must pass clean, noisy, classical, and neural outputs through the same profile-specific CVBW transform and use matched aided references. Noise files are sampled from all DEMAND environments in every split, so the current split is speaker-disjoint but not noise-scene-disjoint.

The checked pilot was trained with 128 train utterances, 3 epochs, one-second crops, batch size 8, seed 271828, and SI-SDR loss weight 0.01. To reproduce its validation crops and audio, run `evaluate_speech_enhancer.py` with `--split validation --limit 32 --seed 271829 --output Results/DeepLearning/pilot_sisdr_crops/validation_metrics.csv --audio-dir Results/DeepLearning/pilot_sisdr_crops/audio`; then from MATLAB run `addpath('DeepLearning'); evaluate_neural_cvbw_pilot(1:4)` to apply CVBW to one case per profile. Change the output folder when evaluating another checkpoint so results do not overwrite one another.

## Expanded matched-aided audit (2026-10-27)

The saved validation pilot was evaluated through the actual MATLAB CVBW stage on all 32 selected mixtures (`evaluate_neural_cvbw_pilot(1:32)`). This replaces the earlier four-example aided CSV in that artifact folder. The deterministic validation subset has seven speakers and eight examples per experimental profile; it is not the held-out test set. Aggregate paired aided SI-SDR deltas (enhanced aided output minus noisy aided input, against the same aided-clean reference) are +1.566 dB for classical spectral subtraction and +4.887 dB for neural enhancement. The neural-minus-classical difference averages +3.320 dB, with neural higher in 19/32 cases. By profile, that difference averages +6.928 dB (profile 1, 7/8 wins), −1.454 dB (profile 4, 1/8 wins), +6.607 dB (profile 35, 6/8 wins), and +1.201 dB (profile 36, 5/8 wins). Profile 4 is a targeted follow-up, not a claim of uniform improvement.

For the 30 cases where both STOI values are finite, the mean neural-minus-classical paired aided STOI change is +0.0556 and neural is higher in 27/30. Two cases return NaN and remain missing. The unusually negative mean classical STOI change and strong profile dependence should be independently checked before making any perceptual claim. Use `DeepLearning/summarize_aided_comparison.py` to regenerate `Results/DeepLearning/pilot_sisdr_crops/aided_reference_summary.md` from the per-case MATLAB CSV.

This checkpoint was selected using pre-CVBW validation scores, so the 32-case result is an audit of its aided behavior, not an aided-objective training result. The next experiment should use validation-only model selection against aided metrics, first addressing profile 4 and confirming the STOI pattern. Preserve the test speakers until the model/objective is frozen. Profile IDs are experimental presets, not clinical labels assigned to VCTK speakers. The split is speaker-disjoint but not DEMAND-scene-disjoint.

## Reference-paper scope decision

The supplied `cvbw_deepfit` package describes audiogram conditioning, differentiable CVBW, fused processing, perceptual-loss hooks, and hardware/latency optimization. Its own guide says its trainer uses synthetic tones/noise, its prototype filter is a placeholder, and some perceptual objectives are stand-ins. Treat it as a design/reference implementation, not a verified performance benchmark unless publication status and the full method are independently established. The 2025-revised arXiv paper `Towards Sub-millisecond Latency Real-Time Speech Enhancement Models on Hearables` instead focuses on LSTM-generated minimum-phase FIR filtering and low-latency hardware; adding audiogram fitting would not make its task directly comparable. Diehl et al., *Restoring speech intelligibility for hearing aid users with deep learning* (Scientific Reports, 2023), remains the closest peer-reviewed application motivation, but its human listening results cannot be reproduced by our current objective-only VCTK/DEMAND experiment. A defensible extension can reproduce a manageable subset of comparable enhancement baselines, then test one explicit added claim—improved aided quality for weak profiles or better quality/runtime trade-off—on the same held-out mixtures.

## Initial training pilot (2026-10-17)

The machine's normal Python 3.13 launcher is broken. The Codex-bundled Python 3.12.14 was usable, so an ignored project-local `.venv` was created and populated with CPU PyTorch 2.14.1, NumPy 2.5.4, SciPy 1.18.1, SoundFile 0.14.0, and pystoi 0.4.1. The supplied reference model forward/backward self-test passed (130.4k parameters; nonzero Farrow `rf` gradient). MATLAB R2026a batch initially failed in the restricted execution context with MathWorks service error 5201; it ran successfully through the elevated network path for this pilot.

Added `train_speech_enhancer.py`, a compact STFT magnitude-mask CNN trained with log-magnitude, waveform, and SI-SDR losses. It loads mic1 VCTK FLAC, resamples to 16 kHz, samples DEMAND noise, generates seeded mixtures at −5/0/5/10 dB, and saves per-utterance SI-SDR/STOI, configuration, and a model checkpoint. A real VCTK/DEMAND sample read, model forward pass, and spectral-subtraction call completed.

Verified the Python spectral-subtraction port against `DSP/spectral_subtraction_enhance.m` on an identical noisy clip: maximum absolute difference 6.08e-5, relative RMS error 4.96e-4, and port-vs-MATLAB SI-SDR 69.14 dB. The remaining difference is consistent with floating-point/window implementation details; the comparison uses effectively the same output.

Three small validation-only runs completed (1-second crops; no held-out test data accessed):

| Training sample | Validation n | Neural SI-SDR / STOI | Spectral subtraction SI-SDR / STOI |
|---|---:|---|---|
| 16 utterances, 1 epoch; no SI-SDR loss | 8 | 3.29 dB / 0.558 | 6.94 dB / 0.533 |
| 128 utterances, 2 epochs; no SI-SDR loss | 32 | 4.60 dB / 0.797 | 5.38 dB / 0.760 |
| 128 utterances, 3 epochs; SI-SDR weight 0.01 | 32 | 11.10 dB / 0.797 | 5.38 dB / 0.760 |

For the 32-case last pilot, neural output exceeded spectral subtraction on 25/32 SI-SDR rows and 26/32 STOI rows; mean STOI was only +0.0012 over the noisy mixture. These are tuning results on 7 validation speakers, before CVBW. The same four validation mixtures (one each for profiles 1/4/35/36) were also passed through MATLAB CVBW. With SI-SDR loss, mean paired aided SI-SDR change was +3.663 dB for neural vs +6.147 dB for spectral subtraction. Mean aided STOI changes were +0.0164 neural vs +0.0157 classical, averaged over the 3 cases with valid MATLAB STOI; one STOI case returned NaN. Without SI-SDR loss, neural mean aided changes were +2.282 dB / +0.0040 STOI, while classical stayed +6.147 dB / +0.0157. Thus the SI-SDR loss improved neural results, but spectral subtraction still had higher aided SI-SDR on all four profiles. These are tuning results, not final performance claims. Per-case metrics are in `Results/DeepLearning/pilot_sisdr_crops` and `pilot_128_crops`; model checkpoints and WAVs are local ignored artifacts.

A larger 512-train/128-validation, 5-epoch CPU run was stopped after several minutes because the workload was too slow for the available CPU and had not reached an epoch boundary. It produced no metrics/checkpoint. A repeat to add crop offsets was stopped after its first epoch; the original complete checkpoint was retained and re-evaluated with the exact same deterministic validation crops, reproducing its metric summary. Checkpoints are now saved after every epoch and the evaluator supports a quick `--limit` to prevent accidentally processing all 2,568 validation utterances. The data split reuses DEMAND environments across splits, so the next experiment should define noise-scene-disjoint splits before making any noise-generalization claim. Do not use the pre-CVBW pilot table as a final hearing-aid result.
