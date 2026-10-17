function metrics = evaluate_aided_reference(clean, noisy, processed, fs, audiogramNumber)
%EVALUATE_AIDED_REFERENCE Compare outputs after a common audiogram transform.
% Raw SNR/SI-SDR against unprocessed clean speech are not comparable once an
% audiogram transform has intentionally changed the spectrum. This helper
% applies the same CVBW preset to clean and noisy references, then measures
% the noisy and denoised aided signals against the aided clean reference.

clean = clean(:);
noisy = noisy(:);
processed = processed(:);
L = min([numel(clean), numel(noisy), numel(processed)]);
clean = clean(1:L);
noisy = noisy(1:L);
processed = processed(1:L);

[cleanAided, ~] = apply_cvbw_hearing_aid(clean, fs, audiogramNumber);
[noisyAided, ~] = apply_cvbw_hearing_aid(noisy, fs, audiogramNumber);
cleanAided = cleanAided(:);
noisyAided = noisyAided(:);
processed = processed(:);
L = min([numel(cleanAided), numel(noisyAided), numel(processed)]);
cleanAided = cleanAided(1:L);
noisyAided = noisyAided(1:L);
processed = processed(1:L);

metrics = struct();
metrics.referenceDescription = 'Clean speech passed through the same audiogram preset';
metrics.audiogramNumber = audiogramNumber;
metrics.noisyAidedSiSdrDb = calculate_si_sdr_db(cleanAided, noisyAided);
metrics.processedAidedSiSdrDb = calculate_si_sdr_db(cleanAided, processed);
metrics.deltaAidedSiSdrDb = metrics.processedAidedSiSdrDb - metrics.noisyAidedSiSdrDb;
metrics.noisyAidedStoi = calculate_optional_stoi(cleanAided, noisyAided, fs);
metrics.processedAidedStoi = calculate_optional_stoi(cleanAided, processed, fs);
metrics.deltaAidedStoi = metrics.processedAidedStoi - metrics.noisyAidedStoi;
end

function value = calculate_optional_stoi(reference, degraded, fs)
if exist('stoi', 'file') ~= 2
    value = NaN;
    return;
end
try
    value = stoi(degraded, reference, fs);
catch
    value = NaN;
end
end
