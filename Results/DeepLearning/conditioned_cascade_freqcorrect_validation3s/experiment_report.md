# Three-second aided validation and STOI diagnostic

Date: 2026-11-09
Status: complete; all 32 cases processed through MATLAB CVBW.

## Why this run was needed

The earlier validation used one-second crops. Independent `pystoi` checks of MATLAB NaN cases 2 and 16 emitted the warning that too few STFT frames remained after silence removal and returned the library's 1e-5 fallback sentinel. MATLAB `stoi` returned NaN without throwing. Those sentinel/NaN values are invalid and must not be included as real scores.

## Data and protocol

Created a separate three-second validation snapshot using the same 32 VCTK utterance rows, speakers, four rotating audiogram profiles, and sample-selection seed as the one-second validation. It uses new three-second crop starts. At the time this snapshot was prepared, the generator consumed a duration-dependent random draw before selecting DEMAND clip and SNR: noise file matches the one-second set in 23/32 cases and SNR matches in 25/32. Therefore this is a separate mixture snapshot, not a row-paired extension of the one-second scores. Within this three-second set, noisy, classical, and neural outputs use exactly the same mixtures and each was passed through the same CVBW profile before metric calculation. The already trained frequency-corrected model was evaluated without retraining; no held-out test speakers were accessed.

After this run, added `--duration-invariant-scenes` to the preparation path via separate RNG streams. A 32-case check confirmed that 1-second and 3-second requests then retain the same speaker, speech utterance, DEMAND file, and SNR for every case while changing crop starts/durations. The option is opt-in to preserve the old default sequence and reproduce this report; these reported numbers were not regenerated with the new option.

Preparation is under `Results/DeepLearning/conditioned_cascade_freqcorrect_validation3s/prepared/`; 3-second audio and aided metrics are in this directory. Python summary generation now reports missing STOI dynamically. All 32 paired aided STOI values are finite for this set.

Reproduction from the repository root (after installing the documented Python dependencies and making VCTK/DEMAND available):

```powershell
DeepLearning/.venv/Scripts/python.exe DeepLearning/prepare_audiogram_conditioned_data.py --split validation --limit 32 --seed 271829 --duration-seconds 3 --output-dir Results/DeepLearning/conditioned_cascade_freqcorrect_validation3s/prepared
DeepLearning/.venv/Scripts/python.exe DeepLearning/train_conditioned_cascade.py evaluate --checkpoint Results/DeepLearning/conditioned_cascade_freqcorrect_128/best_model.pt --validation-manifest Results/DeepLearning/conditioned_cascade_freqcorrect_validation3s/prepared/validation_pairs.csv --output-dir Results/DeepLearning/conditioned_cascade_freqcorrect_validation3s
```

The paired MATLAB CVBW evaluation is `addpath('DeepLearning'); evaluate_neural_cvbw_pilot(1:32,fullfile(pwd,'Results','DeepLearning','conditioned_cascade_freqcorrect_validation3s'));`. The neural checkpoint is a local generated artifact and is not committed; retrain it using the documented `conditioned_cascade_128` training command if unavailable. For a future duration-matched scene/SNR comparison, add `--duration-invariant-scenes`; that new option was validated but was not used for the metrics in this report.

## Results

- Classical paired aided SI-SDR change versus noisy: +3.7218 dB (30/32 positive).
- Neural paired aided SI-SDR change versus noisy: +4.0304 dB (30/32 positive).
- Neural-minus-classical aided SI-SDR change: +0.3087 dB mean, median -0.5834 dB; neural higher in 14/32 cases.
- Classical paired aided STOI change versus noisy: +0.0048 (23/32 positive).
- Neural paired aided STOI change versus noisy: +0.0214 (26/32 positive).
- Neural-minus-classical aided STOI change: +0.0166 mean, median +0.0060; neural higher in 19/32 cases.

| Profile | n | Neural-minus-classical SI-SDR (dB) | Neural SI-SDR wins | Neural-minus-classical STOI | Neural STOI wins |
|---:|---:|---:|---:|---:|---:|
| 1 | 8 | +4.0379 | 6/8 | +0.0439 | 7/8 |
| 4 | 8 | -2.6284 | 0/8 | +0.0034 | 3/8 |
| 35 | 8 | +2.5503 | 7/8 | +0.0141 | 6/8 |
| 36 | 8 | -2.7251 | 1/8 | +0.0050 | 3/8 |

## Interpretation

The longer clips resolve the short-clip STOI failure (32 valid paired values) but reveal that neural-versus-classical SI-SDR advantage is small overall and weak for profiles 4 and 36. STOI favors the neural method slightly on average but only in 19/32 paired cases. This is preliminary validation evidence from seven speakers, not an independent test or a robust superiority claim. The 3-second and 1-second tables must not be combined because their mixture crops/noise/SNR differ. Confidence intervals would need to respect speaker-level clustering; eight clips/profile are not enough for a strong generalization claim.

Inference-time summary for this evaluation correctly reports 45.37 ms per 3-second clip (15.12 ms per second of audio), 3,741 parameters. This excludes MATLAB CVBW, which dominates end-to-end runtime.

## Next

Use the longer clips for future STOI comparisons. The opt-in duration-independent RNG mode is now available and verified; use it in future duration-matched comparisons and freeze a noise-scene-aware validation protocol. Diagnose profile-4 and profile-36 aided distortions before further model tuning. Keep all tuning on validation speakers and evaluate untouched speakers only after the method and protocol are frozen.
