# Project Walkthrough and Engineering Log

This document records the repository state observed on 2026-10-17, why the pipeline exists, what the existing run artifacts establish, and what remains. Append dated entries as new work is attempted; record failures as well as successes so teammates can distinguish evidence from assumptions.

## Goal and rationale

The project explores a hybrid MATLAB hearing-aid pipeline: suppress background noise, then apply frequency-dependent amplification configured by an audiogram. We need both perceptual/clinical motivation (make speech more accessible to a listener with hearing loss) and signal-quality checks; a plausible audiogram response alone does not prove that the output speech is usable.

## Processing walkthrough

1. `main.m` selects a speech recording and DEMAND noise, converts both to mono/16 kHz, normalizes speech, repeats/crops noise, and mixes at the requested SNR. It saves clean/noise/noisy WAV files and a preparation summary.
2. `run_full_pipeline.m` checks the prepared audio/sample rate and aligns the clean/noisy lengths.
3. `spectral_subtraction_enhance.m` estimates noise spectrum from the initial 0.35 seconds and performs overlap-add spectral subtraction.
4. `apply_cvbw_hearing_aid.m` selects a preset, constructs bands using the prototype filter and Farrow-based variable sample-rate conversion, applies per-band gains, sums the bands, removes the mean, and peak-normalizes.
5. `evaluate_basic_metrics.m` computes SNR and SI-SDR; STOI/PESQ/HASPI are optional. Pipeline scripts save reports, figures, WAVs, MAT files, and logs under `Results/`.
6. `run_evaluation_grid.m` currently evaluates a 12-case subset of a possible 480 combinations (four SNR values times four audiogram profiles times a larger sample set). Consult its settings before interpreting the subset as representative.

## Existing evidence

From `Results/Logs/main_full_run_summary.txt` and `Results/Metrics/full_pipeline_audiogram_04_report.txt`:

- Preset 4, 16 kHz, nominal 0 dB input SNR.
- Input SNR 0.00 dB; denoised SNR 5.39 dB (gain +5.39 dB).
- Processed SNR -5.70 dB (delta -5.70 dB relative to input).
- Input SI-SDR 0.03 dB; denoised SI-SDR 5.04 dB; processed SI-SDR -50.52 dB.
- STOI: input 0.9031, denoised 0.9113, processed 0.5650.
- Audiogram matching errors: max 0.83 dB, min -0.51 dB, mean absolute 0.29 dB.
- The grid report says 12 cases ran; mean denoised SNR gain +6.10 dB and mean processed SNR delta -8.97 dB.

Interpretation: denoising has positive results for the reported sample, while the subsequent hearing-aid stage is a blocker. Good frequency-response matching does not explain the extreme SI-SDR drop. Ten samples and an alignment diagnostic were run later; see below. Do not claim successful hearing-aid enhancement until the CVBW issue is resolved and checked across multiple signals/presets.

## Work performed in this handoff

- Inspected project entry points, DSP functions, evaluation functions, and saved reports. Added `README.md`, this walkthrough, `.gitignore`, and `TEAMMATE_PROMPT.txt`.
- Initialized Git in the project root. The remote was empty; published `main` without overwriting existing work (`ab47e6a`, then walkthrough update `6ee4c20`).
- Added a `startSample` argument to `run_batch_samples`; ran samples 06–10 in their own folders while preserving samples 01–05.
- Updated IEEE-oriented figure styling: white paper background, black labels, darker colorblind-friendlier band colors and line styles, compact 7.16-inch layout, Times New Roman 8 pt axes, and 320 dpi PNGs. Rebuilt all seven figures in each of samples 01–10 from saved audio/MAT files.
- Added and ran `diagnose_processed_alignment.m` across the ten cases. Results are in `Results/Diagnostics/processed_alignment_diagnostic.csv`.
- MATLAB initially failed because its default preferences folder was unwritable. Setting `MATLAB_PREFDIR` to a workspace-local directory and running the process with the authorized elevated runner allowed the sample batch and diagnostics to complete.
- Runtime used: MATLAB R2026a Update 4; Signal Processing Toolbox and Deep Learning Toolbox licenses are available. The supplied `cvbw_deepfit` Python directory is a research reference only; its training loader uses synthetic tones/noise and its perceptual loss estimators are stand-ins, so it is not validated against this project's real corpus.
- Raw data, generated audio, MATLAB MAT files, and PNG figures remain excluded from Git. Text summaries/reports are tracked.

## Failures and constraints log

| Date | Attempt / observation | Result | Why it matters / follow-up |
|---|---|---|---|
| 2026-10-17 | Inspected default preset-4 saved report | CVBW stage: -5.70 dB processed SNR, -50.52 dB processed SI-SDR, STOI falls 0.9113 to 0.5650 after denoising | Highest-priority functional issue; trace sample alignment and signal scaling through the DSP path before tuning gains. |
| 2026-10-17 | Inspected existing 12-case grid report | Average processed SNR delta -8.97 dB, despite +6.10 dB average denoised SNR gain | Indicates likely systematic integration issue. The run is only 12 of 480 possible cases. |
| 2026-10-17 | Initialized Git, inspected remote, and pushed initial `main` | Remote had no `HEAD`; commit `ab47e6a` pushed and upstream tracking configured | Teammates can clone the code/docs/reports. They must acquire the excluded dataset separately and read the data/licensing notes. |
| 2026-10-17 | Processed samples 06–10 at 0 dB with preset 4 | Denoised SNR gains: +7.34, +5.44, +5.68, +7.22, +4.45 dB. Processed SNR deltas: -1.66, -7.64, -4.37, -4.42, -5.85 dB. | The denoising gain does not carry through the current CVBW stage. Each case has a separate folder. |
| 2026-10-17 | Regenerated figures for samples 01–10 | Every folder has seven nonempty figures in the updated paper-oriented style. | Visual readability is improved; this does not alter or validate audio quality. |
| 2026-10-17 | Diagnosed lag alignment for samples 01–10 | Max absolute clean/processed correlation within +/-0.5 s is 0.0104; mean SI-SDR is -56.54 dB raw and -46.19 dB after best-lag alignment. | A fixed global time delay does not explain the failure. Investigate frequency/phase/band synthesis and gain calibration; this is evidence, not a proven root cause. |
| 2026-10-17 | MATLAB batch startup | Initial restricted startup failed on preferences access; workspace `MATLAB_PREFDIR` plus elevated execution completed successfully. | Reuse a writable MATLAB preferences directory in similarly restricted environments. |
| 2026-10-17 | Deep-learning readiness review | MATLAB Deep Learning Toolbox is licensed; the included Python DeepFit code is a prototype with synthetic-only training data and stand-in losses. | Tool availability does not mean the model/data pipeline is ready. Replace the toy dataset and stabilize the CVBW signal path before reporting model results. |

## Workflow and next phase

The current baseline flow is: VCTK clean speech plus DEMAND noise → resample and mix at a target SNR → spectral-subtraction denoising → CVBW/Farrow audiogram fitting → SNR/SI-SDR and optional STOI/PESQ/HASPI → audio, plots, metrics, and reports saved by sample. `main.m` runs one default example. `run_batch_samples(5,6)` processes the next five and creates `sample_06`–`sample_10`. `run_evaluation_grid` runs the broader balanced multi-combination snapshot.

Historical baseline before the profile fix: ten 2.5-second cases at 0 dB all used preset 4. Mean denoised SNR gain was +5.79 dB, mean processed SNR delta -4.69 dB, and mean processed SI-SDR -56.54 dB. Best-lag alignment over +/-0.5 s left mean SI-SDR at -46.19 dB; max absolute correlation was 0.0104. This suggested a deeper CVBW signal-generation/synthesis issue than a simple delay, but did not prove its exact cause. The current mixed-profile results and refreshed alignment diagnostic are recorded in “Audiogram source review and profile variation” below.

Deep learning is planned for the next phase, after the classical CVBW path and metric protocol are stable. The sequence is: (1) localize and fix the CVBW issue, (2) validate the fixed baseline over speech/noise/SNR/audiogram combinations, (3) freeze the baseline and evaluation split/metrics, and (4) train a speech-enhancement model and compare it against spectral subtraction before and after audiogram fitting. There is no calendar date yet; this readiness gate prevents training results from being confused with a broken downstream DSP stage.

## Next work, in order

1. Inspect the complex modulation and resampling stages in `VariableSRC_Farrow_8_sub.m`; compare their signs, phase, and frequency response with the supplied reference code.
2. Check per-band RMS/phase and combined signal, clipping/gain behavior, and the SI-SDR implementation. Preserve both aligned and unaligned diagnostics.
3. Make an evidence-backed CVBW correction and validate it across all ten samples and the 12-case evaluation snapshot.
4. Expand the current grid across more speech/noise pairs, -5/0/5/10 dB SNRs, and profiles 1/4/35/36. The planned full design is 480 cases; the existing 12 are a snapshot.
5. Begin deep-learning speech enhancement after the classical baseline is stable; compare models to spectral subtraction with a frozen data split and metrics.
6. Document VCTK/DEMAND acquisition/licensing and MATLAB/toolbox versions for team reproduction.
7. Use the published `main` branch as shared baseline; work in feature branches and push without force.

## Data and result handling

The supplied VCTK corpus makes the data tree about 20.9 GB and there are existing generated results. Raw speech/noise/audio and generated WAV/MAT/figures are not suitable for a normal Git push. `.gitignore` excludes them while retaining text summaries/reports as evidence. Confirm dataset redistribution terms before publishing any data. If a run is essential, archive its compact report and configuration, not its entire output directory.

## Audiogram source review and profile variation (2026-10-17)

Reviewed the supplied reference files `Available_source_code/get_audiogram.m.txt`, `Available_source_code/Standard_Set_Fig.m.txt`, and `Available_source_code/audiogram_matching.m.txt`. The source separates the target audiogram curve returned by `get_audiogram(profileNumber)` from manually tuned CVBW bandwidth, shift, and gain vectors in the standard driver. The project's `DSP/get_audiogram.m` and `DSP/get_cvbw_preset.m` agree with those entries for profiles 1, 2, 3, 4, 35, and 36. Profile 35 is profound loss; profile 36 is severe mid/high-frequency loss. The source does not map a VCTK speaker to an audiogram; profile selection is an experimental input.

Root cause of repeated batch fitting plots: `run_batch_samples.m` previously set `audiogramNumber = 4` once before its loop and passed it to every sample. The prototype FIR response is intentionally shared: `fixedBW` is 200 Hz for all presets and its design depends on sample rate/fixed bandwidth only. Thus, prototype plots should be the same, while audiogram target/CVBW band curves should change with preset; signal-dependent sub-band RMS should also respond to each recording.

Corrective change: `run_batch_samples` now defaults to a deterministic cycle `[1 4 35 36]` indexed by global sample ID, accepts an explicit profile list or scalar override, validates supported profile IDs, and records the profile number in sample reports and batch CSV. CVBW fit titles identify the profile; the prototype title says it is shared. MATLAB `checkcode` completed without blocking diagnostics. `run_batch_samples(1,1,1)` verified sample 01, then `run_batch_samples(9,2)` completed samples 02–10. The ten sample reports and CSV show profile IDs `[1,4,35,36,1,4,35,36,1,4]`. Across this mixed-profile snapshot, mean denoising SNR gain is +5.79 dB and mean processed SNR delta is -5.68 dB; processed deltas remain negative. The first profile-35 plot exposed a fixed 75 dB y-axis clipping high-gain profiles; fit plots now calculate y-axis limits from the active profile's target and band curves. `regenerate_sample_figures(1:10)` used each folder's newest audiogram MAT file, regenerated all ten CVBW figure sets, and removed obsolete profile-specific MAT/report/processed-WAV outputs. All ten sample folders have seven nonempty PNG figures. The displayed profile-35 plot now shows the full range. `diagnose_processed_alignment(1:10)` was rerun on the changed audio: mean processed SI-SDR -47.40 dB; mean best-lag-aligned SI-SDR -34.16 dB; maximum absolute correlation 0.0989. Alignment does not remove the severe degradation. The prototype FIR stays common by design because fixedBW is 200 Hz across profiles.

| Date | Attempt / finding | Result and follow-up |
|---|---|---|
| 2026-10-17 | Compared supplied audiogram/CVBW reference files with project functions | Curves and six-band BW/shift/gain vectors match for 1, 2, 3, 4, 35, 36. Selection is explicit; no speaker-to-audiogram mapping exists. |
| 2026-10-17 | Removed fixed preset 4 from batch loop; added cyclic profile selection/reporting | MATLAB `checkcode` completed without blocking diagnostics; runtime verification followed below. |
| 2026-10-17 | First `run_batch_samples(10,1)` progress check | No completed report was visible while MATLAB spent time in CVBW; initially mistaken for an early exit. |
| 2026-10-17 | Focused `run_batch_samples(1,1,1)` | Completed with profile 1 in report/MAT/CSV and profile-labeled, distinct fit figure. Confirms code fix reaches saved artifacts. |
| 2026-10-17 | Ran `run_batch_samples(9,2)` | Completed samples 02–10. Profile sequence across samples 01–10 is 1,4,35,36,1,4,35,36,1,4. Mean denoising SNR gain +5.79 dB; mean processed SNR delta -5.68 dB. |
| 2026-10-17 | Regenerated ten CVBW figure sets and alignment diagnostic | All sample folders have seven nonempty PNGs; profile-35 y-axis now shows its full response. New mixed-profile alignment means: raw processed SI-SDR -47.40 dB, best-lag aligned -34.16 dB, max absolute correlation 0.0989. DSP quality issue persists. |
