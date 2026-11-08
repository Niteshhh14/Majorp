# Direct-to-CVBW model probe

Date: 2026-11-08. Validation only; no held-out test speakers were used.

This first model took noisy speech plus a six-point example audiogram and predicted the magnitude of clean speech after project CVBW. It trained on 32 distinct training clips repeated across profiles 1/4/35/36 (128 rows), three epochs, and selected the checkpoint by validation spectral loss. Clean CVBW targets came from the project's MATLAB implementation. Validation used 32 one-second mixtures from seven validation speakers.

The model was fast (mean inference 27.4 ms per one-second clip, CPU; 6,785 parameters), but output quality was poor. MATLAB compared its direct output to the MATLAB-generated CVBW target without applying CVBW a second time: mean SI-SDR was -46.124 dB and mean STOI was 0.5330 (30 valid cases). On the same 32 mixtures, classical and previous neural aided SI-SDR means were about 5.93 dB and 9.26 dB; their mean aided STOI values were about 0.788 and 0.844 on valid cases. The model kept the noisy input phase while the target's CVBW processing changes phase, which likely explains a large part of the error. More training alone is not justified until the architecture can represent the required phase behavior. MATLAB metrics are saved in `direct_target_matlab_metrics.csv`.

MATLAB CSV import initially treated the header as generated names; explicit column imports fixed it. A filename collision was also caught: the first temporary train/validation file layout reused case IDs and overwrote some temporary targets. All pairs and targets were regenerated into split-specific folders before training the reported models; validation clean/noisy file hashes then matched the earlier audit exactly. One initial profile-35 threshold vector was transcribed incorrectly; it was corrected and the direct probe rerun. Results here use the corrected audiogram values.

Conclusion: this direct-output approach is a failed quality/intelligibility design. Its speed cannot count as a useful computation improvement because it produces unacceptable output. The follow-up keeps CVBW in the processing chain and uses the audiogram to condition the denoiser.
