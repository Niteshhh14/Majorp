# Project Context and Claude Code Handoff

Updated 2026-11-14. This is the consolidated project brief for a new collaborator/model. Read `CLAUDE.md` first for operating constraints. This document summarizes the conversation and current evidence; detailed experiment reports and the chronological log remain in the linked files.

## In one paragraph

We are developing one hearing-aid-specific speech enhancement system intended to improve aided speech intelligibility for listeners with hearing loss. The working chain is speech enhancement followed by our existing MATLAB CVBW audiogram fitting. The research focus is to improve the compact audiogram-conditioned neural enhancer so that, after the same CVBW stage, it has a defensible advantage in aided intelligibility/quality at comparable computation, comparable aided outcomes at lower computation/latency, or a better balance. Classical spectral subtraction, unprocessed speech, and existing neural checkpoints are baselines. The project has not yet demonstrated an overall neural advantage; current official aided metrics are mixed and slightly favor classical processing. Research is paused pending user direction.

## What problem and why

People with hearing loss may miss speech cues even when ordinary noise-reduction or speech-reconstruction scores look good. A hearing aid also changes the signal according to a listener's audiogram. Therefore the relevant question is not simply whether an enhancer reconstructs clean speech, but whether the output remains intelligible and acceptable after the hearing-aid fitting stage. We want to preserve useful speech information for different hearing-loss profiles while keeping the system computationally practical.

“Better than existing work” must be demonstrated against appropriate baselines and literature, on held-out data, with controlled conditions and metrics that reflect aided performance. The project has no human-listener study, no measured SPL calibration, and no validated patient cohort, so it cannot currently claim clinical benefit.

## Intended processing chain

```text
VCTK clean speech + DEMAND noise
              ↓ mix at declared SNR, 16 kHz
       Noisy speech mixture
              ↓ neural enhancer (research stage)
       Enhanced speech estimate
              ↓ existing MATLAB CVBW audiogram fitting
       Aided output
              ↓ matched baselines, aided metrics, compute/latency
```

The classical reference chain is noisy speech → spectral subtraction → the same profile-specific CVBW. The aided reference for project SI-SDR/STOI is clean speech transformed by the same CVBW. Official Clarity HASPI instead takes the original clean reference and simulates hearing loss internally; do not pass it the CVBW-clean signal as its reference.

## What has been built

- MATLAB pipeline rooted at `main.m` / `run_full_pipeline.m`: VCTK and DEMAND preparation, mixture generation, spectral subtraction, audiogram-aware CVBW/Farrow processing, figures, audio, metrics, reports.
- CVBW profile-dependent fitting code under `DSP/`, including audiogram presets and variable sample-rate conversion. Audiogram and prototype/CVBW plots were added to results. A prior hardcoded profile issue was found and fixed so sample selection carries explicit profiles; inspect source before any future changes.
- Batch and grid runners (`run_batch_samples.m`, `run_evaluation_grid.m`) keep cases in distinct result folders.
- A deterministic VCTK speaker split with seed 271828: 56 train, 7 validation, and 8 test speakers (28,529 indexed utterances). The split is speaker-disjoint; current DEMAND noise sampling is not noise-scene-disjoint.
- Compact audiogram-conditioned STFT magnitude-mask CNN with 3,741 parameters. It conditions on six threshold values for example profiles 1/4/35/36 and then passes its enhanced signal through the existing MATLAB CVBW stage. It is not an AECRN reproduction.
- Official pyClarity 0.9.0 HASPI v2 and HASQI v2 evaluation on saved MATLAB CVBW outputs, with per-case/profile summaries. Environment/setup notes: `DeepLearning/CLARITY_METRICS_SETUP.md`.
- Strength-control probes (`noisy + s*(neural-noisy)`) at s=.50 and .25 on eight profile-1 validation cases.

Useful implementation map:

- `main.m`, `run_full_pipeline.m`: MATLAB entry points.
- `DSP/`: CVBW, audiogram presets, Farrow resampling, spectral subtraction.
- `DeepLearning/train_audiogram_conditioned.py`, `train_conditioned_cascade.py`: profile-conditioned model/training.
- `DeepLearning/prepare_audiogram_conditioned_data.py`: deterministic paired mixtures.
- `DeepLearning/evaluate_neural_cvbw_pilot.m`: neural/classical/CVBW paired evaluation and saved MAT inputs.
- `DeepLearning/evaluate_clarity_metrics.py`, `summarize_clarity_metrics.py`: official aided metric path.
- `Base_papers/RELATED_WORK_AND_GAP.md`, `Base_papers/RESEARCH_DIRECTION_AND_BENCHMARK_PLAN.md`: literature and comparison boundary.
- `WALKTHROUGH.md`: chronology, decisions, prior failures, and historical results.

## What we learned in the conversation

1. The initial classical MATLAB baseline and sample/evaluation-grid machinery work, but early SNR/SI-SDR gains alone do not establish aided intelligibility or a research contribution.
2. Audiogram fitting must vary with the selected profile. A plotting bug once broadcast a row against a column and emitted a vector of matching errors; it was fixed. Profile-specific figures and matching errors should be verified from their source MAT/config, not assumed from filenames.
3. The project's fixed example audiogram presets allow controlled engineering tests. They are not real measurements, are not linked to VCTK speakers, and do not establish generalization to patients. Real audiogram data is needed for patient-personalization claims, with suitable licensing/consent and subject-disjoint evaluation.
4. The supplied AECRN paper is a genuine direct overlap: it conditions neural enhancement on audiograms and targets hearing-compensated speech. Thus “combine deep learning and audiogram fitting” is not enough novelty. Its reported protocol and scores use different data/rate/prescription and are not directly comparable to our VCTK 16 kHz + CVBW numbers.
5. Related work also includes a 2018 DDAE study evaluated with hearing-loss metrics, a multi-audiogram 2025 evaluation, dCoNNear human-listener work, and AFN-HearNet (Information Fusion 2026), which further weakens generic audiogram-conditioning or HASQI-surrogate novelty claims. Literature details and references are in `Base_papers/RELATED_WORK_AND_GAP.md`.
6. The model's log-frequency audiogram interpolation had a correctness bug; it was fixed and retrained. Metrics barely changed, so this is a correctness repair, not a performance gain.
7. One-second STOI can return NaN/near-zero sentinel because too few frames remain. The sentinel is invalid, not a true very poor score. Use the stable three-second set and report valid counts.
8. Early paired SI-SDR/STOI validation looked positive, but the later official aided HASPI/HASQI results did not confirm an overall win. This is central evidence and must not be obscured by older optimistic pilot summaries.
9. A 50% blend raised profile-1 HASPI/HASQI relative to the original neural output, but it remained below classical HASPI and hurt SI-SDR/STOI. A 25% blend has only SI-SDR/STOI so far; its Clarity check is pending.
10. A level-preserving CVBW diagnostic produces extremely high inferred levels under the project's assumed SPL mapping for severe profiles. The production path remains peak-normalized. Neither path is physically calibrated to an actual device.

## Current measurements: most relevant evidence

### Official Clarity on the 32-case stable-scene validation set

Three-second crops, 32 cases, seven validation speakers, eight cases per example profile (1/4/35/36), actual peak-normalized MATLAB CVBW applied consistently. Overall means for noisy/classical/neural:

| Metric | Noisy | Classical | Neural | Neural − classical |
|---|---:|---:|---:|---:|
| HASPI v2 | 0.1179 | 0.1285 | 0.1172 | -0.0114 |
| HASQI v2 (NAL-R reference) | 0.0165 | 0.0145 | 0.0131 | -0.0014 |

Neural wins were 18/32 HASPI and 15/32 HASQI. The model is **not better on the overall official aided metric means**. By profile, HASPI neural-minus-classical: profile 1 -0.0506, profile 4 +0.0042, profile 35 +0.0010 (near metric floor), profile 36 -0.0002. Profile 1 is the clearest regression. Detailed files: `Results/DeepLearning/conditioned_cascade_freqcorrect_validation3s_stable/`.

### Paired project-specific aided SI-SDR/STOI on the same stable validation set

Neural-minus-classical aided SI-SDR +0.9234 dB mean (17/32 wins); aided STOI +0.0173 mean (22/32 wins). Per-profile SI-SDR differences: profile 1 +4.0108 dB, profile 4 -1.8510 dB, profile 35 +2.6050 dB, profile 36 -1.0713 dB. Positive averages in these diagnostics do not override the Clarity result; metrics measure different properties.

### Complexity

The model has 3,741 parameters. One measured CPU run took 40.40 ms for a three-second clip (13.47 ms per audio second), model only. MATLAB CVBW is excluded and is much slower in a historical benchmark; do not call this end-to-end latency or compare device timings across unlike setups.

### Strength probes, profile 1 only, same eight validation cases

- 50% blend: HASPI mean .3239 vs original neural about .2841 and classical .3349; HASQI .0467 vs original .0347 and classical .0413. It improved over the full-strength neural output, but did not surpass classical HASPI, and reduced SI-SDR/STOI materially. Mixed trade-off, not a win.
- 25% blend: MATLAB CVBW and paired SI-SDR/STOI exist; neural delta vs noisy was +1.407 dB / +.00458, versus original neural +7.547 dB / +.03498 and classical +3.536 dB / -.00508. Official Clarity metrics have **not** been run. Files: `Results/DeepLearning/neural_blend_025_profile1_validation3s/experiment_report.md`.

### Metric calibration limitations

For Clarity comparisons, each original clean reference is scaled to RMS 1 and assumed to represent 65 dB SPL; exactly the same scalar is applied to noisy/classical/neural CVBW outputs. This is a declared simulation convention, not measurement-based SPL calibration. HASQI `equalisation=1` internally adds NAL-R to its reference, whereas the project output uses CVBW; label it secondary and disclose the prescription mismatch. Scores are not clinical outcomes.

## Literature and comparison boundary

- **AECRN**, Cao et al., IEEE SiPS 2025, DOI 10.1109/SiPS66314.2025.11261312: direct audiogram-conditioned network mapping noisy speech toward NAL-NL2-WDRC-compensated clean speech. The reviewed paper describes 32 kHz VoiceBank+DEMAND, 11,572 train pairs / 28 speakers, 824 test pairs / two speakers, 500 synthetic train audiograms, 50 evaluation audiograms, and HASPI/HASQI/PESQ/STOI. Its table reports AECRN .53/.37/1.69/.82 for those four metrics. These are the paper's reported numbers, not directly comparable targets for this project's different dataset, sample rate, prescription, calibration, and protocol. Exact architecture reproduction is not established from the paper details available.
- **AFN-HearNet**, peer-reviewed Information Fusion 127A (2026): audiogram-conditioned joint enhancement/compensation and HASQI surrogate; novelty claims around those generic ingredients are untenable.
- **2018 DDAE**, 2025 five-audiogram evaluation, and 2025 dCoNNear human-listener study also matter. Full references and the careful gap statement are in `Base_papers/RELATED_WORK_AND_GAP.md` and `Base_papers/RESEARCH_DIRECTION_AND_BENCHMARK_PLAN.md`.
- Potential public alternatives surfaced in model/dataset searches but have not been adopted: generic DNS SepFormer (higher compute and not audiogram-aware), Arm ULUNAS (vendor latency claim is hardware-specific), and HEAR-DS-16k (environmental audio rather than audiogram-linked clean speech; upstream license restrictions require checking). Do not assume they solve this task or import their data/code without reviewing license and fit.

## Exact next step on resumption

This is a bounded validation-only continuation, not permission to launch a new training run. The local 25% blend outputs and per-case MATLAB CVBW MATs already exist. First check their presence, then run official Clarity only for profile-1 cases 1,5,9,13,17,21,25,29 and compare against the same eight cases in the original model, 50% blend, and classical results.

```powershell
DeepLearning/.venv/Scripts/python.exe DeepLearning/evaluate_clarity_metrics.py `
  --artifact-dir Results/DeepLearning/neural_blend_025_profile1_validation3s `
  --cvbw-mode peak_normalized --level1-db-spl 65 `
  --case-ids 1,5,9,13,17,21,25,29
DeepLearning/.venv/Scripts/python.exe DeepLearning/summarize_clarity_metrics.py `
  Results/DeepLearning/neural_blend_025_profile1_validation3s/clarity_aided_metrics.csv
```

Before execution, inspect `evaluate_clarity_metrics.py --help` because CLI details may have changed. Verify saved MAT files match the intended eight scenes and profile 1. This command only scores existing validation outputs; do not regenerate data or retrain. Then write a concise comparison with valid n and all metric trade-offs. Do not promote a setting just because one metric improves.

After this probe, a research resumption should define one controlled validation-only change (e.g. checkpoint selection or a carefully justified aided-objective component), freeze the model, and only then evaluate the untouched speaker test set. First resolve noise-scene split policy, uncertainty reporting, runtime measurement convention, and a defensible comparison protocol to AECRN. Do not reproduce AECRN scores on incompatible conditions and call them a direct win/loss.

## Git and local-only state

Remote is `https://github.com/Niteshhh14/Majorp.git`, branch `main`. At handoff preparation, user-local items were present: edited `PROJECT_FAMILIARIZATION_GUIDE.docx`, its Office lock file, supplied AECRN PDF, and generated 25%/50% blend prepared inputs and metrics. They should remain untouched and unstaged. Model/data/runtime artifacts and MATLAB preference state are local and should not be committed. This handoff is documentation of project knowledge, not a claim that new experiments or Git publication were performed.
