# Hybrid Hearing Aid Framework

MATLAB project for a speech enhancement and hearing-aid processing pipeline. It prepares 16 kHz clean/noisy speech, applies spectral-subtraction denoising, then applies a variable-bandwidth (CVBW) audiogram fitting stage and reports objective metrics and plots.

## Start here

1. Open MATLAB and set the current folder to this repository root (the folder containing `main.m`).
2. Ensure the VCTK and DEMAND source audio is available locally under `Data/`. The large corpus/audio files are intentionally excluded from Git; see `WALKTHROUGH.md` for details.
3. Run `main` to prepare audio and run the default full pipeline (audiogram preset 4).
4. Run `run_batch_samples(5, 6)` to create five additional cases in `Results/Samples/sample_06` through `sample_10`; `run_batch_samples(5)` creates or refreshes samples 01–05. Profiles cycle reproducibly through 1, 4, 35, and 36 by global sample number. To choose profiles explicitly, pass a third argument, for example `run_batch_samples(4, 1, [1 2 35 36])`; a scalar repeats for all samples. Each folder keeps audio, figures, metrics, and logs separate, including the selected audiogram ID.
5. Run `regenerate_sample_figures(1:10)` to rebuild the audiogram/CVBW fitting figures from saved MAT files without repeating audio processing. It writes 320 dpi PNGs with profile-aware axes and high-contrast line styles. Run `diagnose_processed_alignment(1:10)` to compare raw and best-lag-aligned SI-SDR; it writes `Results/Diagnostics/processed_alignment_diagnostic.csv`.
6. Run `run_evaluation_grid` for the current 12-case evaluation. These commands can take time and write under `Results/`.

MATLAB with Signal Processing Toolbox is expected for audio resampling/filtering and plots. STOI, PESQ, and HASPI are optional and reported only when compatible functions are installed. In restricted environments MATLAB may need a writable preferences directory set with `MATLAB_PREFDIR`.

## Project map

- `main.m`: prepares clean speech and DEMAND noise at 16 kHz, mixes at the selected SNR, and runs the default pipeline.
- `run_full_pipeline.m`: denoising, audiogram fitting, metric computation, plots, and report generation.
- `run_evaluation_grid.m`, `run_batch_samples.m`: broader evaluation runners.
- `DSP/`: CVBW filter bank, audiogram presets, Farrow variable sample-rate conversion, and spectral subtraction.
- `Evaluation/`: SNR/SI-SDR and optional intelligibility/quality metrics.
- `Visualization/`: figures for pipeline and audiogram fitting.
- `Available_source_code/`: supplied/reference implementations, including a Python DeepFit reference package.
- `Base_papers/`: project source papers.
- `Results/`: existing run reports/outputs. Generated binary outputs are ignored by Git.

## Current status

The batch hardcoding was found and corrected. The ten current 2.5-second VCTK/DEMAND cases at 0 dB use profiles 1, 4, 35, and 36 in a reproducible cycle; mean denoising SNR gain is +5.79 dB and mean processed SNR delta is -5.68 dB. A refreshed diagnostic gives mean processed SI-SDR -47.40 dB and mean best-lag aligned SI-SDR -34.16 dB, so the CVBW audio path remains a blocker despite the corrected profile-dependent plots. The shared 200 Hz prototype FIR is expected to remain the same across profiles; audiogram target and CVBW band curves vary. The former preset-4-only metrics are historical. See `WALKTHROUGH.md` for evidence/failure history and `TEAMMATE_PROMPT.txt` for the continuation handoff.
