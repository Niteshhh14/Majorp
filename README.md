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
- `DeepLearning/`: speaker-disjoint VCTK manifest, real-audio Python training/evaluation, and MATLAB matched-CVBW pilot evaluator.
- `Base_papers/`: project source papers.
- `Results/`: existing run reports/outputs. Generated binary outputs are ignored by Git.

## Current status

The neural-enhancement phase has started in `DeepLearning/`. A deterministic speaker-disjoint split from VCTK mic1 audio (seed 271828) has 56 train, 7 validation, and 8 test speakers across 28,529 utterances. A small, profile-independent STFT-mask pilot was trained and evaluated on validation speakers only. Before CVBW, its 32-utterance pilot scores are SI-SDR 11.10 dB / STOI 0.797 vs spectral subtraction 5.38 dB / 0.760. The expanded matched-aided audit now covers 32 validation mixtures: neural mean paired aided SI-SDR change is +4.89 dB vs +1.57 dB classical, with neural higher in 19/32 cases. By profile, the neural-minus-classical difference is negative for profile 4 (−1.45 dB, 1/8 wins); finite paired STOI difference is +0.0556 in 27/30 cases. This remains a validation tuning audit, not an aided-objective-trained model or held-out result; two STOI rows are missing, and the unexpected classical STOI decrease needs checking. No test speakers have been used. See `DeepLearning/README.md` and `WALKTHROUGH.md` for scope, results, and next actions.

The batch hardcoding was found and corrected. Ten 2.5-second VCTK/DEMAND cases at 0 dB use profiles 1, 4, 35, and 36 in a reproducible cycle. Raw processed-versus-clean SNR/SI-SDR/STOI scores remain as diagnostics because CVBW intentionally changes the spectrum. The matched-reference evaluation applies the same audiogram transform to clean and noisy references, then measures aided outputs against aided clean speech. Across ten cases, paired SI-SDR change averages +4.04 dB (range +0.33 to +7.09 dB) and paired STOI change averages +0.0268 (range +0.0028 to +0.0606); both improved in all ten, with small gains in samples 06 and 10.

The updated 12-case grid (−5/0/5/10 dB and profiles 1/4/35/36) has mean paired SI-SDR change +4.25 dB (all 12 positive) and mean paired STOI change +0.0183 (11/12 positive). Case 10 (profile 1, +5 dB) has a paired STOI regression of −0.0326. A lower spectral-subtraction α of 0.20 nearly removed that regression in a targeted test but reduced the first three grid cases' denoising SNR gains to about +1 dB and had lower paired SI-SDR/STOI; the default α=1.15 remains. Use this stable classical baseline as the comparator for the deep-learning phase, and specifically track case 10 and the weak profile-4 samples 06/10. The reference CVBW presets were not altered. See `WALKTHROUGH.md` for the full evidence and `TEAMMATE_PROMPT.txt` for the next steps.
