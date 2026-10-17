# Hybrid Hearing Aid Framework

MATLAB project for a speech enhancement and hearing-aid processing pipeline. It prepares 16 kHz clean/noisy speech, applies spectral-subtraction denoising, then applies a variable-bandwidth (CVBW) audiogram fitting stage and reports objective metrics and plots.

## Start here

1. Open MATLAB and set the current folder to this repository root (the folder containing `main.m`).
2. Ensure the source audio described in `Data/` is available locally. Large corpus/audio files are intentionally excluded from Git; see `DATA_AND_RESULTS.md` for details.
3. Run `main` to prepare audio and run the default full pipeline (audiogram preset 4).
4. Run `run_evaluation_grid` for the current 12-case evaluation or `run_batch_samples` for the sample batch. These can take time and write under `Results/`.

MATLAB with Signal Processing Toolbox is expected for audio resampling/filtering and plots. STOI, PESQ, and HASPI are optional and reported only when compatible functions are installed. No MATLAB/Octave runtime was available in the authoring environment, so these entry points have not been rerun there.

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

The checked-in result reports show spectral subtraction helps the tested sample, but the CVBW output is severely degraded by current objective metrics. Audiogram matching error is low, which does not establish that time-domain processing is correct. Resolve this before treating the pipeline as successful. See `WALKTHROUGH.md` for evidence, failure history, and next steps, and `TEAMMATE_PROMPT.txt` for a ready-to-use continuation prompt.
