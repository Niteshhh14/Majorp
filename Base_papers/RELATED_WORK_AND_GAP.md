# Direct related work and project gap

Research check recorded 2026-10-27. This note is for selecting a defensible comparison and must be updated when the AECRN full text/code is inspected.

## The papers that directly challenge the current novelty claim

| Work | What it did | Why it matters here | What it does not establish for our implementation |
|---|---|---|---|
| Lai et al., “Improving the Performance of Hearing Aids in Noisy Environments Based on Deep Learning Technology,” IEEE EMBC 2018, DOI [10.1109/EMBC.2018.8512277](https://doi.org/10.1109/EMBC.2018.8512277) | Deep denoising autoencoder (DDAE); evaluated HASPI and HASQI for two high-frequency hearing-loss audiograms; compared against two classical enhancement methods. | Establishes that neural denoising versus classical baselines using hearing-loss-aware metrics is not new. | It does not by itself test the current CVBW bank or the current VCTK/DEMAND training split. |
| Cao et al., “AECRN: A Unified Neural-Network for Improving Hearing Aid Speech Enhancement,” IEEE SiPS 2025, DOI [10.1109/SiPS66314.2025.11261312](https://doi.org/10.1109/SiPS66314.2025.11261312) | Audiogram-Embedded Convolutional Recurrent Network; audiogram is an input, and noisy speech maps directly to compensated clean speech; trained against NAL-NL2 prescription targets. IEEE's abstract reports 50–60% improvements in HASPI/HASQI over cascaded systems. | This is the closest direct overlap. A claim such as “we combine a neural denoiser with audiogram-based compensation” is already substantially covered. A comparison should include a faithful AECRN-like/direct-conditioned baseline, if enough method detail can be obtained. | Published aggregate percentages cannot be compared numerically with our scores unless data, targets, metrics, preprocessing, fitting and protocol match. The IEEE abstract alone is insufficient to reproduce the full method. |
| Ashkanichenarlogh et al., “Objective Evaluation of a Deep Learning-Based Noise Reduction Algorithm for Hearing Aids Under Diverse Fitting and Listening Conditions,” *Trends in Hearing* 2025, DOI [10.1177/23312165251396644](https://doi.org/10.1177/23312165251396644) | Compared DNN processing with adaptive filtering and beamforming under noise, SNR, room and fitting variations; five audiograms and 1,152 KEMAR manikin recordings; estimated intelligibility with HASPI and also reported HASQI/pMOS. | Makes evaluation across fitting/listening conditions and hearing-loss-aware objective metrics expected, rather than novel by itself. | It evaluates a commercial DNN pipeline; it is not the same architecture, data, or audiogram-conditioned end-to-end model as AECRN. |

## What our code currently does

- Classical reference: spectral subtraction (`alpha=1.15`, `floorFactor=0.04`) followed by the MATLAB CVBW audiogram preset.
- Neural pilot: a small profile-independent STFT magnitude-mask CNN trained to denoise VCTK/DEMAND mixtures using waveform/spectral/SI-SDR losses, then the same MATLAB CVBW stage is applied afterward.
- It does **not** currently take an audiogram as a neural input, predict NAL-NL2 compensated clean speech, or jointly optimize the denoiser and fitting stage. The selected model was tuned with pre-CVBW metrics.
- The 32-case validation-only aided audit gives +4.887 dB mean paired aided SI-SDR change for neural versus +1.566 dB classical; neural is higher on 19/32. Profile 4 reverses the trend (neural minus classical −1.454 dB; 1/8 cases higher). Paired aided STOI is finite for 30 cases; the neural-minus-classical change averages +0.0556. These are exploratory VCTK/DEMAND validation results, not a test-set result or clinical claim.

## Defensible next study

Do not pitch “deep learning + audiogram fitting” as the novelty. First obtain and read the AECRN full paper/method details (the IEEE record is accessible, but the abstract alone does not specify enough to replicate it). Then run a controlled, same-data comparison with:

1. Current classical spectral subtraction + CVBW.
2. Current profile-independent neural denoiser + the same CVBW.
3. An AECRN-style audiogram-conditioned direct compensated-speech model, trained with explicit audiogram/prescription targets.
4. A smaller/cheaper variant of that model, if the full comparator establishes an appropriate quality-versus-computation target.

Keep speech speakers disjoint across train/validation/test. Use common noisy mixtures and the same audiogram profiles for every method. Report per-case and aggregate SI-SDR plus hearing-loss-aware quality/intelligibility metrics (HASQI/HASPI where valid implementations are available), missing-metric counts, parameter count, multiply-accumulate estimate, and measured runtime. Analyze profile 4 separately because the current pilot is weak there. Select architecture and settings on validation only; evaluate held-out speakers once after freezing the method.

Potential contribution, conditional on evidence: a lower-compute audiogram-conditioned enhancement method that preserves or improves aided intelligibility/quality across audiograms and SNRs. This is a hypothesis, not yet a novelty claim. If reproducing AECRN requires unavailable method details, data or prescription software, narrow the project to a transparent benchmark/ablation study and ask the guide to approve that scope rather than claiming to beat AECRN with non-matched scores. Claims about user benefit require human listening validation; objective simulations alone cannot support clinical effectiveness.
