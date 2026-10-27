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
| 2026-10-17 | Published audiogram profile fix to `origin/main` | Commit `501b95b` includes code, text reports, diagnostic CSV, walkthrough, and teammate prompt. Generated audio/MAT/PNG files remain ignored/local. |

## Baseline stabilization and matched-reference evaluation (2026-10-17)

The next diagnosis separated a CVBW signal-path defect from an evaluation-definition problem. A clean sinusoid test across the existing Farrow path preserved its center frequency and phase for the tested ratio, so this alone did not demonstrate a Farrow bug. A unity sum of the six bands had low SI-SDR/correlation against the original waveform, but that is not a valid identity test for this audiogram-shaped bank. The source's gain tables are intentionally spectral shaping, and the prototype filter remains shared by design. No CVBW preset or reference implementation was retuned without a reproduced implementation defect.

The main reported end-to-end SNR/SI-SDR/STOI compared audiogram-shaped output against unprocessed clean speech. That reference has a different spectrum by construction, so these scores can look severely negative even when the denoiser helps. Added `Evaluation/evaluate_aided_reference.m`: it applies the same profile to clean and noisy references, then compares the noisy aided and processed aided signals with the aided clean reference. Reports retain the original raw scores as diagnostics and now label them non-comparable, while showing matched aided SI-SDR/STOI and their denoising deltas. `run_batch_samples` adds these fields to each sample report and the batch CSV. Existing rows without the new metrics are labeled NaN rather than guessed.

The full ten-sample mixed-profile rerun completed. Matched aided-reference changes (noisy-to-denoised after applying the same profile to clean/noisy references) were:

| Sample | Profile | SI-SDR change (dB) | STOI change |
|---|---:|---:|---:|
| 01 | 1 | +4.91 | +0.0146 |
| 02 | 4 | +4.33 | +0.0287 |
| 03 | 35 | +7.09 | +0.0408 |
| 04 | 36 | +0.78 | +0.0285 |
| 05 | 1 | +4.59 | +0.0252 |
| 06 | 4 | +0.33 | +0.0357 |
| 07 | 35 | +5.76 | +0.0606 |
| 08 | 36 | +3.57 | +0.0161 |
| 09 | 1 | +6.91 | +0.0153 |
| 10 | 4 | +2.17 | +0.0028 |

Mean changes are +4.04 dB SI-SDR and +0.0268 STOI; all ten deltas are positive. The smallest SI-SDR change is sample 06/profile 4 (+0.33 dB); the smallest STOI change is sample 10/profile 4 (+0.0028). This supports that the denoiser helps in this ten-case snapshot but does not establish performance across the full noise/SNR/profile grid or clinical benefit. Sample 01/profile 1 specifically had noisy/processed aided SI-SDR -0.20/+4.71 dB and STOI 0.8081/0.8227. Its raw processed SI-SDR -46.37 dB and raw STOI 0.6660 remain diagnostics against a different-reference spectrum. Mean denoising SNR gain before audiogram processing across the ten cases remains +5.79 dB.

Failures during this session: an early MATLAB diagnostic used `corr`, unavailable in the current installation; normalized correlation was then calculated directly. A one-line `-batch` command rejected a local helper function definition; the diagnostic was rewritten using inline operations. The first PowerShell aggregation command had a `$label:` interpolation parse error; its retry parsed the audiogram profile label as a floating-point metric; a numeric-regex extraction then generated the ten-case table correctly. MATLAB `checkcode` on the changed MATLAB files completed with no warnings. The paired-reference helper and batch/evaluation-grid summary wiring were checked, and `run_batch_samples(1,1,1)`, `run_batch_samples(3,2)`, and `run_batch_samples(6,5)` completed. Reports and batch CSV contain matched aided SI-SDR/STOI fields; prior uncomputed values are represented as NaN during migration.

| Date | Attempt / finding | Result and follow-up |
|---|---|---|
| 2026-10-17 | Tested a clean tone through one Farrow resampling ratio | Frequency and phase were preserved for the tested tone. This does not establish full speech-bank reconstruction, but did not support changing Farrow signs. |
| 2026-10-17 | Compared unity-summed sub-bands against clean speech | Poor raw SI-SDR/correlation; not a valid pass-through criterion for a tuned audiogram bank, so no change was made on this evidence alone. |
| 2026-10-17 | Tried `corr` in a MATLAB diagnostic | Unavailable function/toolbox error; replaced with normalized dot-product correlation. |
| 2026-10-17 | Tried a local helper definition in inline `matlab -batch` code | MATLAB rejected inline local function definitions; reran the diagnostic without the helper. |
| 2026-10-17 | Added paired aided-reference metrics and reran all ten cases | MATLAB checkcode clean. Mean paired improvement +4.04 dB SI-SDR / +0.0268 STOI; all ten deltas positive. Samples 06 and 10 show smaller improvements; next run the updated 12-case grid before freezing the baseline. |

### 12-case grid and spectral-subtraction tuning check

Ran `run_evaluation_grid(12)` at the existing spectral-subtraction setting (`alpha=1.15`, `floorFactor=0.04`). The corrected CSV has 12 data rows and 28 columns. Matched aided-reference SI-SDR improved in all 12 cases (mean +4.25 dB, range +1.29 to +7.33 dB). Matched STOI improved in 11/12 (mean +0.0183, range -0.0326 to +0.0526). The exception is case 10, VCTK sample 5/DEMAND noise 1, profile 1, +5 dB input: paired SI-SDR +5.10 dB but paired STOI -0.0326. The report and CSV preserve this regression. Across the grid the pre-audiogram denoising SNR gain mean is +6.10 dB. Raw processed-vs-clean SNR delta still averages -8.97 dB and is explicitly marked diagnostic because of audiogram spectral shaping.

Investigated that STOI regression with alpha sweep on case 10. At alpha 1.15, paired STOI delta was -0.0326 and paired SI-SDR change +5.10 dB. Alpha 0.60 gave STOI -0.0104, SI-SDR change +2.72 dB. Alpha 0.20 gave STOI -0.0008, SI-SDR change +0.88 dB. Thus lower alpha trades away useful suppression/SI-SDR for a small intelligibility improvement in this case; it was not adopted. A full alpha-0.20 grid trial was stopped after its first three cases showed only +0.98, +1.21, +1.13 dB SNR gain and lower matched scores than alpha 1.15. The full alpha-1.15 12-case grid was rerun afterward so the committed reports and summaries are consistent. The function accepts optional alpha/floor parameters for controlled future experiments; defaults remain 1.15/0.04. Reports record both values.

More failures/repair notes: the first candidate-grid MATLAB loop used invalid `for [a,f]=...` syntax; corrected to index matrix rows. When regenerating the CSV from the completed MAT after discovering an exporter format mismatch, MATLAB printed the literal `\n` sequence; the file was repaired to real line breaks and re-imported as 12 rows/28 columns. The exporter format string was fixed, and the complete grid rerun verified the CSV without manual patching. One PowerShell check treated duplicate `NaN` values as column names while the CSV was malformed; that was resolved by fixing CSV row formatting first. A later PowerShell text insertion used the wrong `Regex.Replace` overload and duplicated alpha/floor annotations; all ten text reports were cleaned and the values inserted once at the correct location. `git diff --check` passes (only standard LF-to-CRLF notices on Windows).

**Baseline decision:** retain alpha 1.15 as the classical comparator. The matched-reference protocol is now wired into batch and grid output, and the 12-case run has positive SI-SDR changes in every case and STOI changes in 11/12. The baseline is usable for the deep-learning comparison, with case 10 and small-gain profile-4 samples explicitly retained as regression targets. Next freeze the data split, use identical noisy references and audiogram profiles, and compare deep-learning output against spectral subtraction plus CVBW; do not omit the STOI regression.

## Deep-learning comparison preparation (2026-10-17)

Started the next phase: prepare a leakage-resistant data split before model development. Inspected `Available_source_code/_CVBW_code_unpacked/cvbw_deepfit/`. Its `train.py` uses synthetic sine tones, random noise, and toy audiograms; the accompanying implementation guide says the real speech/noise loader is still to be implemented. The reference package is useful for architecture ideas but its smoke test is not evidence of speech-enhancement performance. Training it as supplied would not answer whether a learned speech enhancer beats the project's MATLAB baseline.

Added `DeepLearning/prepare_vctk_split.ps1` and generated `DeepLearning/splits/vctk_speaker_split.csv`. The script uses VCTK mic1 recordings, deterministic seed 271828, and speaker-level splitting. In the locally extracted corpus it found 71 speakers and 28,529 utterances: train 56 speakers/22,919 utterances, validation 7/2,568, test 8/3,042. A manifest inspection found zero speakers assigned to multiple splits, and sample relative paths resolve to the expected local VCTK audio. The split is now a controlled artifact; regenerate with `./DeepLearning/prepare_vctk_split.ps1` from the repository root. The CSV contains relative paths only; the large dataset stays local.

Added `DeepLearning/README.md` with the paired-crop/model/evaluation protocol. Planned experiment: create deterministic VCTK+DEMAND mixtures at 16 kHz; train an STFT mask model only on train speakers; choose settings on validation speakers; preserve test speakers; then compare on the same baseline cases and matched aided references, reporting SI-SDR and STOI. Retain the case-10 STOI regression and the weaker profile-4 samples 06/10. Apply identical CVBW processing to each system and persist settings, per-case metrics, and runtime. No model was trained and no DL scores exist yet.

Execution attempts and failures: the visible Python 3.13.2 command fails before startup with `Failed to find real location of ... Python313/python.exe`; the runtime has no PyTorch, SciPy, SoundFile, librosa, or pystoi. MATLAB batch was attempted with a writable project-local `.matlabprefs`; startup progressed past the earlier preferences-folder complaint but then failed with MathWorks service error 5201. Consequently the data split and experiment scaffold are complete, but actual training/evaluation must wait for a working Python or MATLAB runtime. The exact blocker and prerequisite packages are also recorded in `DeepLearning/README.md`, and the teammate handoff prompt has been updated.

Follow-up runtime/network check: checked the Codex bundled Python 3.12.14, which has NumPy but none of PyTorch, SciPy, SoundFile, librosa, or pystoi; pip cache is empty. `pip index versions torch` exhausted its retries because DNS could not resolve pypi.org. Git fetch/ls-remote also could not resolve github.com (`getaddrinfo() thread failed to start` / DNS resolution failure). No local MATLAB/Python processes were left running. This confirms the current limitation is network/runtime availability, not a lingering process. No training code was run and no model scores are available. Retrying push through the approved elevated network path is the immediate next publication action; training still requires a usable installed stack.

## First speech-enhancement pilot and matched CVBW comparison (2026-10-17)

Environment recovery: the normal Windows Python 3.13 executable still fails to locate its real executable. An ignored project-local `DeepLearning/.venv` was created from the Codex bundled Python 3.12.14. Initial `venv` setup with ensurepip failed; recreating with `--without-pip` and installing via the bundled pip `--python` mode succeeded. The first requirements installation took too long during package extraction and was interrupted; PyTorch/NumPy/SciPy had installed, and SoundFile/pystoi were then installed separately. Final versions: CPU torch 2.14.1, NumPy 2.5.4, SciPy 1.18.1, SoundFile 0.14.0, pystoi 0.4.1. The reference CVBW-DeepFit forward/backward self-test passed: 130.4k parameters and nonzero Farrow `rf` gradient. The supplied trainer was not used for speech claims because it trains on synthetic tones.

Added `DeepLearning/train_speech_enhancer.py` for an independent, compact STFT-mask denoiser. Its dataset reads VCTK mic1 FLAC and DEMAND WAV, resamples to 16 kHz, and deterministically pairs one-second crops over SNR values −5/0/5/10 dB. It reports file paths, speaker, speech/noise crop offsets, SNR, and experimental profile IDs; four profile IDs cycle 1/4/35/36, with no assertion that speakers map to clinical audiograms. The objective combines log-magnitude loss, waveform loss, and an optional weighted SI-SDR term. Its Python spectral-subtraction function mirrors the MATLAB alpha=1.15/floor=0.04 settings. Added an evaluation-only checkpoint command and optional WAV export for the MATLAB CVBW stage. Checkpoints are now saved after each epoch and the evaluator has a pilot `--limit` to prevent accidentally scanning the full 2,568-file validation split. A live VCTK/DEMAND load, model forward pass, spectral subtraction, Python syntax check, and CVBW MATLAB Code Analyzer check succeeded.

Three validation-only pilots (no test split accessed):

| Training subset | Val subset | Neural pre-CVBW SI-SDR / STOI | SS pre-CVBW SI-SDR / STOI |
|---|---:|---|---|
| 16 examples, 1 epoch, no SI-SDR term | 8 | 3.29 dB / 0.558 | 6.94 dB / 0.533 |
| 128, 2 epochs, no SI-SDR term | 32 | 4.60 dB / 0.797 | 5.38 dB / 0.760 |
| 128, 3 epochs, SI-SDR loss weight 0.01 | 32 | 11.10 dB / 0.797 | 5.38 dB / 0.760 |

The selected 32 validation crops were re-evaluated from the saved complete checkpoint and reproduced the metrics exactly. Aided evaluation used the same profile transform on clean, noisy, classical, and neural waveforms. Four cases (profiles 1/4/35/36) gave classical paired aided SI-SDR changes [4.694, 7.301, 5.338, 7.255] dB and neural [3.806, 3.333, 3.928, 3.585] dB; means +6.147 vs +3.663 dB. Without SI-SDR loss neural mean aided SI-SDR change was +2.282 dB, so the SI-SDR loss improved the neural model but it remained below classical in every case. Mean aided STOI deltas were +0.0157 classical and +0.0164 neural over the three valid cases; profile-4 case at +10 dB returned NaN for all MATLAB STOI variants. Do not impute it. This is a four-case validation pilot, not a final test result.

A 512-example/128-validation, 5-epoch CPU run was cancelled after several minutes without completing its first epoch. A repeat to regenerate crop metadata was cancelled after its first epoch; a previous complete checkpoint was preserved and exactly re-evaluated with the updated metadata evaluator. One accidental all-validation evaluation (2,568 utterances) was interrupted; added `--limit` and reran only 32 samples. MATLAB normal sandbox launch failed with error 5201, but the elevated network/service path launched MATLAB R2026a and ran the 4-case CVBW comparison. One STOI computation failed and remains NaN.

Decision: keep the classical alpha=1.15 + CVBW path as baseline. Current model selection by pre-CVBW SI-SDR does not optimize aided performance; the model is not ready to replace the baseline. Next tune a validated end-to-end aided objective or differentiable CVBW surrogate; define the noise scene policy; expand validation (including case 10 and profile-4 samples 06/10); only evaluate held-out test speakers after the model is frozen. CPU throughput is too low for full corpus training without an accelerator or a carefully declared development subset.

Comparison audit addendum: MATLAB R2026a batch started successfully through elevated network/service access; `checkcode` on the new CVBW pilot evaluator emitted no blocking findings. Matched CVBW comparison for cases 1–4 applied each case profile consistently to clean, noisy, classical, neural signals. Mean paired aided SI-SDR deltas: classical +6.147 dB; neural +3.663 dB with SI-SDR loss, +2.282 dB without. Neural is lower in all four aided SI-SDR rows. Mean aided STOI across the three valid cases: classical +0.0157, neural +0.0164 with SI-SDR loss and +0.0040 without. One profile-4/+10 dB case returns NaN for all three STOI paths; its cause is not yet known and no value was imputed. This overrides any interpretation of the pre-CVBW pilot as end-to-end performance.

Checked that the Python alpha=1.15/floor=0.04 spectral-subtraction port matches MATLAB on the same 1-second noisy clip: maximum absolute output difference 6.08e-5, relative RMS 4.96e-4, SI-SDR 69.14 dB. The first check failed only because the MATLAB Evaluation folder was absent from the path; added it and reran successfully. The evaluator currently cycles validation profile IDs [1,4,35,36] for research comparison; not a clinical mapping. Compact pilot CSV and portable configuration JSONs are tracked; WAVs/checkpoints/venv remain ignored.

PUBLICATION UPDATE: the initial neural pilot implementation, four-profile matched CVBW comparison, portable metric/config files, README, WALKTHROUGH, and teammate prompt are committed and pushed to origin/main as `748383f` (`Train and evaluate initial speech enhancement pilot`). The worktree was clean after that push. The model checkpoint, validation WAVs, virtual environment, and raw datasets remain local/ignored.

## Project familiarization and literature review (2026-10-27)

Created `PROJECT_FAMILIARIZATION_GUIDE.docx` to help the project owner and teammates restart from the project goal, the conventional hearing-aid/noise-reduction context, the papers in `Base_papers`, current MATLAB and Python workflows, evidence and metric caveats, current neural pilot status, repository navigation, and sequenced next steps. The guide distinguishes papers' published results from results measured in this repository, and distinguishes the supplied CVBW-DeepFit proposal/reference code from the project's real-audio STFT-mask pilot.

Reviewed all four PDFs in `Base_papers` and the supplied CVBW-DeepFit implementation guide/manuscript. The three speech-enhancement papers provide motivation for neural intelligibility optimization, mobile denoising, and low-latency filtering. `Implementation_Hearing Aid.pdf` has no extractable page text in the available environment and PDF metadata identifies the CVBW-DeepFit Markdown guide; treat it as a supplied design/implementation export, not as verified peer-reviewed work. The readable guide itself says the supplied Python trainer uses synthetic tones/noise and calls out unfinished real-data/perceptual/hardware stages.

The guide records the central project decision: keep spectral subtraction alpha 1.15 + CVBW as the classical reference; tune the neural model against final matched aided-reference performance because its pre-CVBW pilot scores do not translate into higher aided SI-SDR. The four-case aided pilot favored classical SI-SDR (+6.15 dB mean paired change versus neural +3.66 dB); the validation-only result has not used held-out speakers. Current speaker splits are speaker-disjoint but reuse DEMAND scenes across splits.

Document QA: `render_docx.py` could not render because LibreOffice (`soffice.exe`) is unavailable. Opened the DOCX in Microsoft Word through the desktop UI instead and reviewed the five pages. Removed the default blue title rule, placed the literature and roadmap sections at clean page starts, and confirmed that headings, text, tables, repeated table headers, and footers display without clipping.

| Date | Attempt / observation | Result and follow-up |
|---|---|---|
| 2026-10-27 | Read README, current handoff, DeepLearning notes, Base_papers PDFs, and CVBW-DeepFit design guide | Onboarding guide separates project implementation/evidence from prior-paper claims and proposed design work. |
| 2026-10-27 | Created `PROJECT_FAMILIARIZATION_GUIDE.docx` | Covers problem rationale, baseline flow, literature, metrics, measured results and limits, next steps, and repo map. |
| 2026-10-27 | Rendered DOCX with bundled renderer, then opened in Word for visual QA | LibreOffice is unavailable, but Word opened the document. Reviewed all five pages, removed inherited title border, and adjusted section starts; no clipping was visible. |

## 32-case aided neural audit and reference scope (2026-10-27)

To address the mismatch between the neural pilot's pre-CVBW training/selection metrics and the project's hearing-aid objective, reran the saved validation pilot through the actual MATLAB `apply_cvbw_hearing_aid` evaluator for all 32 deterministic validation mixtures (`evaluate_neural_cvbw_pilot(1:32)`). These are seven validation speakers, eight examples/profile, and no held-out test speakers. The earlier 4-row aided metrics CSV was replaced by the complete 32-row table at `Results/DeepLearning/pilot_sisdr_crops/aided_reference_metrics.csv`.

Paired aided SI-SDR changes (processed aided output minus noisy aided output, both against the identically aided clean reference) average +1.566 dB for spectral subtraction and +4.887 dB for the neural pilot. Neural minus classical change averages +3.320 dB; neural is higher in 19/32 cases. Profile averages/wins: profile 1 +6.928 dB (7/8), profile 4 −1.454 dB (1/8), profile 35 +6.607 dB (6/8), profile 36 +1.201 dB (5/8). Across 30 cases with finite STOI for both systems, neural-minus-classical paired aided STOI change averages +0.0556 and neural is higher in 27/30; two cases are NaN. The neural pilot was selected using pre-CVBW metrics, making this an audit rather than a result of aided-objective training. Profile 4 is a clear regression area. The negative average classical STOI delta and large profile variance need a focused validity check before interpreting as intelligibility evidence. No clinical-benefit or generalization claim follows from this small validation-only sample.

Added `DeepLearning/summarize_aided_comparison.py` to regenerate the compact Markdown summary from the CSV. Normal MATLAB startup again failed before project code with MathWorks service error 5201; the same command completed via the authorized execution path. No test speakers were read. The full per-case table and derived summary are persisted for review.

### Reference and project-scope clarification

The folder includes the peer-reviewed 2023 Scientific Reports paper *Restoring speech intelligibility for hearing aid users with deep learning*, plus two arXiv preprints. The 2025-revised arXiv paper *Towards Sub-millisecond Latency Real-Time Speech Enhancement Models on Hearables* studies LSTM-generated minimum-phase FIR filters and low-latency hardware; it is not a direct test of our audiogram/CVBW method. The supplied CVBW-DeepFit package describes audiogram conditioning, differentiable CVBW, and hardware/perceptual extensions, but its own implementation guide identifies synthetic-only training, a placeholder prototype filter, and stand-in perceptual estimators. It is a design reference, not verified experimental evidence. We can implement more components, but that alone does not establish novelty or a fair comparison: validate the actual method on real paired speech/noise, compare under identical data/metrics, and isolate one specific improvement. A suitable project extension is controlled aided-objective model selection/training focused on profile 4, with compute/runtime reported, then one final untouched speaker-disjoint test after the validation choice is frozen.

| Date | Attempt / observation | Result and follow-up |
|---|---|---|
| 2026-10-27 | Ran the saved 32-example validation pilot through MATLAB CVBW | 32/32 cases completed; profile-specific paired SI-SDR and STOI were written to the current aided comparison CSV. The first normal MATLAB launch failed with service error 5201; authorized execution completed. |
| 2026-10-27 | Aggregated by model and profile | Neural-minus-classical aided SI-SDR change +3.320 dB overall (19/32 wins); profile 4 is −1.454 dB (1/8 wins). Finite paired STOI difference +0.0556 (27/30 wins), but 2 NaNs and unexpectedly poor classical STOI mean require checking. |
| 2026-10-27 | Added reproducible CSV summarizer and refreshed handoff notes | `DeepLearning/summarize_aided_comparison.py` regenerates the summary; `DeepLearning/README.md`, this log, and `TEAMMATE_PROMPT.txt` capture result limits and the next validation-only objective. |
