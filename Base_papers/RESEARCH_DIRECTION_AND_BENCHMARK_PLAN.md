# Research direction and benchmark plan

Updated 2026-11-09. This document sets the current research direction after a literature check and the latest controlled validation run.

## Research objective

Develop one practical hearing-aid speech enhancement system: the existing neural speech enhancer is improved to increase intelligibility and quality after the existing MATLAB CVBW hearing-aid fitting stage. CVBW and audiogram fitting remain functional parts of the final chain and every aided evaluation. The main research work is neural enhancement, its training objective, and its quality/compute trade-off.

The existing unprocessed, spectral-subtraction, and neural checkpoints are evaluation baselines. They are not competing final product directions. AECRN is the required paper reference. A defensible outcome is at least one repeatable, held-out improvement over AECRN under a matched protocol and over this repository's own baselines: (1) better aided quality/intelligibility at comparable compute, (2) similar quality/intelligibility at materially lower compute/latency, or (3) a better quality/intelligibility/compute trade-off. This is a target, not a result or a novelty claim.

## Literature audit: overlap is substantial

| Work | Established result | Consequence for this project |
|---|---|---|
| Lai et al., IEEE EMBC 2018, [DOI 10.1109/EMBC.2018.8512277](https://doi.org/10.1109/EMBC.2018.8512277) | Evaluates a deep denoising autoencoder against classical enhancement using HASPI/HASQI for hearing-loss profiles. | Generic DNN denoising plus hearing-loss metrics is established. |
| Cao et al., AECRN, IEEE SiPS 2025, [DOI 10.1109/SiPS66314.2025.11261312](https://doi.org/10.1109/SiPS66314.2025.11261312) | Conditions a neural model on audiograms and predicts hearing-compensated clean speech; trains/evaluates with hearing-related and generic metrics. It is the required direct reference. | Audiogram-conditioned enhancement and hearing-compensated targets alone are not a contribution. The supplied paper's VoiceBank+DEMAND, 32 kHz, NAL-NL2/OpenMHA target protocol differs from this 16 kHz VCTK/DEMAND/CVBW implementation. Scores cannot be compared across those protocols. See `RELATED_WORK_AND_GAP.md` for its full-text protocol and reproduction limits. |
| Ni et al., AFN-HearNet, *Information Fusion* 127A (2026), [publisher article](https://www.sciencedirect.com/science/article/abs/pii/S1566253525007882), [official repository](https://github.com/deepnetni/AFN-HearNet) | Audiogram-conditioned joint noise reduction and hearing-loss compensation; uses a HASQI metric surrogate in training with other losses and reports quality/intelligibility metrics and compute. | This is a close, peer-reviewed precedent beyond AECRN. Generic joint optimization, a HASQI proxy, and compact audiogram-conditioned processing are not safe novelty claims. The public repository's license was not verified; do not copy its code/data. |
| Ashkanichenarlogh et al., *Trends in Hearing* 2025, [DOI 10.1177/23312165251396644](https://doi.org/10.1177/23312165251396644) | Evaluates hearing-aid DNN processing across five audiograms and varied acoustic conditions. | Profile-stratified and condition-stratified evaluation is expected practice, not novelty. |
| dCoNNear, IEEE/ACM TASLP 2025, [DOI 10.1109/TASLPRO.2025.3536183](https://doi.org/10.1109/TASLPRO.2025.3536183) | Uses individualized auditory modeling and reports listening-test evaluation for hearing-loss compensation. | Objective metrics alone do not establish improved user intelligibility. |
| AV-NeuroAMP, [arXiv:2610.08579](https://arxiv.org/abs/2610.08579), 2026 preprint | Joint enhancement/amplification with audiogram conditioning, including human listening evaluation; audiovisual and noncausal assumptions differ from this project. | Another emerging overlap; treat as a preprint and do not claim that joint processing or audiogram conditioning is new. |

The central question is therefore not “does audiogram-aware enhancement exist?” It does. The question is whether a carefully controlled neural enhancement update can produce a reproducible quality/compute advantage over AECRN and local baselines when the same MATLAB CVBW fitting, audiograms, mixtures, levels, and metrics are used. A CVBW-specific evaluation/training implementation may be useful engineering, but it is not automatically novel.

## Existing system and current validation evidence

The active model is a compact audiogram-conditioned magnitude-mask CNN (3,741 parameters) followed by MATLAB CVBW. It was trained on VCTK/DEMAND mixtures; it is not an AECRN reproduction. Classical spectral subtraction plus the same CVBW, unprocessed audio, and earlier profile-independent neural processing remain controls. Existing profile presets are experimental profiles, not clinical measurements linked to VCTK speakers.

The latest controlled audit uses the same saved 32 validation mixtures for classical and neural processing, then applies MATLAB CVBW consistently to clean, noisy, and enhanced signals. Manifest selection is stable across 1 s and 3 s crops (`--duration-invariant-scenes`); this 3 s run used that mode. Results are in `Results/DeepLearning/conditioned_cascade_freqcorrect_validation3s_stable/`:

- Paired aided SI-SDR change: classical +3.1642 dB, neural +4.0876 dB; neural-minus-classical +0.9234 dB mean, with neural higher in 17/32 cases.
- Paired aided STOI change: classical +0.0080, neural +0.0253; neural-minus-classical +0.0173 mean, neural higher in 22/32 cases.
- SI-SDR by profile (neural minus classical): profile 1 +4.0108 dB (7/8 wins), profile 4 -1.8510 dB (1/8), profile 35 +2.6050 dB (6/8), profile 36 -1.0713 dB (3/8).
- Neural model inference: 40.40 ms per 3 s clip (13.47 ms per audio second), 3,741 parameters on the measured CPU. This excludes CVBW; the MATLAB CVBW path is currently the end-to-end runtime bottleneck.

These are validation-only, short-snapshot results with seven speakers/eight cases per profile, not held-out test evidence. The model was not selected using aided metrics. DEMAND environments overlap the current data splits. The output normalization and sound-level conventions have not yet been validated for HASPI/HASQI. No clinical benefit or superiority is established. Profile 4 and 36 regressions need attention rather than being hidden by the aggregate.

## Required fair comparison

1. **Freeze a common protocol:** speaker-disjoint and noise-scene-disjoint train/validation/test manifests; identical noisy mixtures, SNRs, profiles, crop durations, clean references and CVBW implementation for every method. Keep the test manifest sealed until model/objective selection is complete.
2. **Retain the actual CVBW stage:** use the existing MATLAB implementation for inference/evaluation. Validate that the Python training or metric path can represent its exact input/output behavior before using a surrogate. Do not replace the working filter bank.
3. **Fix metric calibration first:** `apply_cvbw_hearing_aid.m` currently peak-normalizes each signal separately. That prevents defensible absolute level-based HASPI/HASQI comparisons. Keep its legacy behavior for reproduction, but add an explicit evaluation mode using a single common, documented calibration factor per case. Confirm metric reference convention with the official implementation; the clean reference should be unamplified when the metric internally applies the audiogram model. Never silently score mismatched levels.
4. **Benchmark AECRN appropriately:** first determine whether a public, licensed implementation and compatible pretrained weights/data are available. Otherwise implement a clearly labeled AECRN-inspired comparator from the supplied paper, disclose incomplete architecture details and target mismatch, and do not call it a faithful reproduction. Use the supplied paper's methodology as the reference protocol where feasible; report any unavoidable deviations. Compare the paper's published numbers only as context, not as direct matched scores.
5. **Improve one existing neural model iteratively:** preserve its working data/model/checkpoint path. Choose one primary enhancement architecture and change one controlled factor at a time (audiogram conditioning, aided objective, multi-resolution/speech-cue loss, or compactness). Keep CVBW in the final forward/evaluation chain. Do not run a broad architecture search that makes selection irreproducible.
6. **Metrics:** report aided intelligibility (validated HASPI; STOI as a secondary proxy), aided quality (validated HASQI and/or PESQ where protocol permits), SI-SDR as a distortion diagnostic, per-profile/per-SNR results, valid/missing counts and uncertainty intervals. Add parameters, MACs/FLOPs with declared counting convention, warm and steady-state latency on declared hardware, real-time factor, and CVBW + neural end-to-end timings. Objective scores are not human or clinical evidence.
7. **Decision rule:** compare the frozen candidate to AECRN and local baselines on untouched held-out data. Accept an outcome only if the improvement is practically meaningful, repeatable, profile-stratified, and not bought by a hidden compute/quality regression. If no outcome wins, report it and revise the hypothesis.

## Next implementation step

Before changing the model objective, repair and validate the aided metric path: expose a non-peak-normalizing CVBW evaluation mode without changing legacy defaults; measure and record input/output RMS/peak and calibrated SPL; run the official Clarity HASPI/HASQI implementation on a small set and verify argument/reference conventions. Then add an exact or numerically validated differentiable CVBW counterpart only if training through the fitting is required; retain MATLAB as the reference implementation and end-to-end benchmark. After this, define noise-scene-disjoint splits and decide the AECRN reproduction boundary. Only then start the first validation-only aided-objective experiment.

## Research/tooling limitations

The literature review used primary publisher/project pages and Firecrawl search/scrape. Hugging Face catalog metadata was checked through Firecrawl; no audiogram-conditioned HF model/data was identified for immediate adoption. Exa and Context7 direct query tools were not exposed in the session. This is not proof no such material exists. AFN-HearNet source licensing needs verification before reuse. The local Python environment did not have the Clarity package installed at last check.
