# Clarity aided metrics: setup and interpretation

Updated 2026-11-09. The project uses the official pyClarity implementation (`pyclarity` 0.9.0) for HASPI v2 and HASQI v2. PyPI currently declares Python >=3.11; the project Python 3.12 environment meets that requirement. The upstream repo README recommends a Python 3.11 environment and `pip install pyclarity`.

## Install

The project's working model environment already contains NumPy 2.x, SciPy, PyTorch, SoundFile and pystoi. pyClarity's full package declares many optional challenge/training dependencies, including torchaudio. To avoid needlessly replacing the project's existing PyTorch stack, metric-only installation can be done in the existing venv with:

```powershell
python -m pip install --no-deps pyclarity==0.9.0
python -m pip install "numba>=0.60"
```

The second command installs numba and its compatible llvmlite dependency, required by Clarity's HASPI auditory model. If the selected Python lacks pip, bootstrap pip in an isolated environment first. The current machine's `.venv` had no pip, so an ignored temporary installer environment under `DeepLearning/.runtime/` was used; only pyClarity's source and numba runtime were added to the ignored project venv. The import/signature check for both official functions passed. No environment binaries are tracked.

## Run

1. From MATLAB, in the repository root:

   ```matlab
   addpath('DeepLearning');
   evaluate_neural_cvbw_pilot(1:32, fullfile(pwd,'Results','DeepLearning', ...
       'conditioned_cascade_freqcorrect_validation3s_stable'), true);
   ```

   This applies the existing **default peak-normalized CVBW path** consistently and saves unamplified clean references plus all CVBW outputs as per-case MAT files in `cvbw_peak_normalized_mat/`. `true` preserves the legacy production behavior. `false` is a separate level-preservation diagnostic and must not be confused with the current pipeline.

2. From the repository root:

   ```powershell
   DeepLearning/.venv/Scripts/python.exe DeepLearning/evaluate_clarity_metrics.py `
       --artifact-dir Results/DeepLearning/conditioned_cascade_freqcorrect_validation3s_stable `
       --cvbw-mode peak_normalized --level1-db-spl 65
   ```

   This writes `clarity_aided_metrics.csv`. Every metric comparison uses one scale per case: the unamplified clean reference is scaled to RMS=1, which is assumed to correspond to 65 dB SPL, and the **same exact scalar** is applied to noisy/classical/neural CVBW outputs. This is a standardized simulation reference, not physical SPL calibration from a measured hearing aid/microphone. Do not RMS-normalize methods separately.

3. Summarize overall and profile-stratified comparisons:

   ```powershell
   DeepLearning/.venv/Scripts/python.exe DeepLearning/summarize_clarity_metrics.py `
       Results/DeepLearning/conditioned_cascade_freqcorrect_validation3s_stable/clarity_aided_metrics.csv
   ```

   This writes `clarity_aided_summary.md` and reports per-profile wins, means, and the metric/prescription limitations.

## Metric semantics and limits

- HASPI v2 uses the original clean target as the unamplified reference, the CVBW output as processed signal, the profile's six-frequency audiogram, and the common `level1` reference. Clarity's documentation requires the reference and processed paths to use the same SPL calibration. Do not pass the CVBW-clean target as HASPI's reference; the HASPI auditory model applies hearing-loss simulation internally.
- HASQI v2 with `equalisation=1` adds NAL-R to its clean reference internally. It is recorded as `hasqi_nalr_reference_*`. The project output uses CVBW, not NAL-R, so this is a standard external quality comparator with a prescription mismatch—not a CVBW-matched quality target. Keep SI-SDR/STOI against the same CVBW-processed clean reference as separate project-specific distortion/intelligibility diagnostics.
- The optional level-preserving CVBW path currently produces extremely high predicted output levels for severe profiles (around 145–149 dB SPL RMS under the standardized reference assumption). Such raw-mode metric scores are diagnostic only and not physically credible. The current run uses the exact peak-normalized default pipeline, which keeps outputs in a plausible simulated range; still, the hardware SPL mapping is not measured.
- Neither HASPI nor HASQI predicts clinical benefit with certainty. Human-listener validation remains necessary for user-benefit claims.

## Current validation status

The full 32-case actual-pipeline audit completed. Overall means (noisy/classical/neural) were HASPI 0.1179/0.1285/0.1172 and HASQI with NAL-R reference 0.0165/0.0145/0.0131. Neural minus classical was -0.0114 HASPI (18/32 neural wins) and -0.0014 HASQI (15/32 wins); neural was not better on these aided metric means. By profile, HASPI deltas were -0.0506, +0.0042, +0.0010, -0.0002 for profiles 1/4/35/36. See `Results/DeepLearning/conditioned_cascade_freqcorrect_validation3s_stable/clarity_aided_summary.md` and `WALKTHROUGH.md`. These are validation-only estimates under the declared SPL assumption, not clinical results.
