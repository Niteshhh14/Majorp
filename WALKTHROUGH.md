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

Interpretation: denoising has positive results for the reported sample, while the subsequent hearing-aid stage is a blocker. Good frequency-response matching does not explain the extreme SI-SDR drop; investigate delay, phase, band alignment, gain calibration, clipping/normalization, and the metric/reference alignment. Do not claim successful hearing-aid enhancement until this is resolved and checked across multiple signals/presets. These are existing artifacts; they were not regenerated in this handoff session.

## Work performed in this handoff

- Inspected project entry points, DSP functions, evaluation functions, and saved reports.
- Confirmed the workspace originally had no Git metadata or top-level project documentation; initialized Git in the project root and configured `origin` to the owner-supplied URL.
- Added this walkthrough, `README.md`, and `.gitignore`; added a teammate continuation prompt in `TEAMMATE_PROMPT.txt`.
- No MATLAB/Octave runtime was available in the environment, so no new DSP execution or verification is claimed.
- `git ls-remote origin HEAD` first failed in the restricted shell with `getaddrinfo() thread failed to start`; with network access enabled, the remote was reachable and had no existing `HEAD`. Initial `main` branch was pushed successfully to `https://github.com/Niteshhh14/Majorp.git`.
- Initial commit: `ab47e6a` (`Document project status and teammate handoff`), containing 103 files. Git excludes the 20+ GB `Data/` tree, generated results binaries, and archived sample output.

## Failures and constraints log

| Date | Attempt / observation | Result | Why it matters / follow-up |
|---|---|---|---|
| 2026-10-17 | Inspected default preset-4 saved report | CVBW stage: -5.70 dB processed SNR, -50.52 dB processed SI-SDR, STOI falls 0.9113 to 0.5650 after denoising | Highest-priority functional issue; trace sample alignment and signal scaling through the DSP path before tuning gains. |
| 2026-10-17 | Inspected existing 12-case grid report | Average processed SNR delta -8.97 dB, despite +6.10 dB average denoised SNR gain | Indicates likely systematic integration issue. The run is only 12 of 480 possible cases. |
| 2026-10-17 | Initialized Git, inspected remote, and pushed initial `main` | Remote had no `HEAD`; commit `ab47e6a` pushed and upstream tracking configured | Teammates can clone the code/docs/reports. They must acquire the excluded dataset separately and read the data/licensing notes. |
| 2026-10-17 | Checked for MATLAB/Octave runtime | No executable found on PATH | Reproduce results in MATLAB/Octave before accepting DSP changes. |

## Next work, in order

1. Reproduce preset-4 pipeline and save baseline output/metrics with a MATLAB version/toolbox inventory.
2. Localize severe SI-SDR collapse by inspecting waveform correlation, lag, RMS/peak, clipping, and individual band outputs before and after summation. Align signals when calculating metrics, but preserve an unaligned diagnostic so a delay bug is not hidden.
3. Compare Farrow/filter-bank outputs against the supplied reference MATLAB scripts and verify each band's frequency response and time alignment.
4. Fix only the demonstrated cause; add a small deterministic regression case that verifies signal length, bounded peak, finite samples, expected gain/matching error, and no large unintended SI-SDR regression.
5. Re-run the 12-case subset, then expand coverage deliberately. Summarize per-profile/per-SNR results and optional-metric availability.
6. Document data acquisition/licensing and MATLAB/toolbox setup. Keep large datasets and generated outputs outside Git; provide reproducible download/setup instructions or Git LFS only if the team explicitly chooses it.
7. Use the published `main` branch as the shared baseline; work in feature branches and push without force. Review remote history before integrating any later work.

## Data and result handling

The supplied VCTK corpus makes the data tree about 20.9 GB and there are existing generated results. Raw speech/noise/audio and generated WAV/MAT/figures are not suitable for a normal Git push. `.gitignore` excludes them while retaining text summaries/reports as evidence. Confirm dataset redistribution terms before publishing any data. If a run is essential, archive its compact report and configuration, not its entire output directory.
