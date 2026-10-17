function metrics = evaluate_basic_metrics(clean, noisy, processed, fs, denoised)
%EVALUATE_BASIC_METRICS Basic objective checks for the first MATLAB pipeline.

if nargin < 5
    denoised = [];
end

metrics = struct();
metrics.fs = fs;
metrics.inputSnrDb = calculate_snr_db(clean, noisy);
metrics.inputSiSdrDb = calculate_si_sdr_db(clean, noisy);
metrics.processedSnrDb = calculate_snr_db(clean, processed);
metrics.processedSiSdrDb = calculate_si_sdr_db(clean, processed);
metrics.deltaSnrDb = metrics.processedSnrDb - metrics.inputSnrDb;
metrics.deltaSiSdrDb = metrics.processedSiSdrDb - metrics.inputSiSdrDb;
if ~isempty(denoised)
    metrics.denoisedSnrDb = calculate_snr_db(clean, denoised);
    metrics.denoisedSiSdrDb = calculate_si_sdr_db(clean, denoised);
    metrics.denoisedDeltaSnrDb = metrics.denoisedSnrDb - metrics.inputSnrDb;
    metrics.denoisedDeltaSiSdrDb = metrics.denoisedSiSdrDb - metrics.inputSiSdrDb;
end

metrics.inputStoi = calculate_optional_stoi(clean, noisy, fs);
metrics.processedStoi = calculate_optional_stoi(clean, processed, fs);
metrics.deltaStoi = metrics.processedStoi - metrics.inputStoi;
if ~isempty(denoised)
    metrics.denoisedStoi = calculate_optional_stoi(clean, denoised, fs);
    metrics.denoisedDeltaStoi = metrics.denoisedStoi - metrics.inputStoi;
end

metrics.inputPesq = calculate_optional_pesq(clean, noisy, fs);
metrics.processedPesq = calculate_optional_pesq(clean, processed, fs);
metrics.deltaPesq = metrics.processedPesq - metrics.inputPesq;
if ~isempty(denoised)
    metrics.denoisedPesq = calculate_optional_pesq(clean, denoised, fs);
    metrics.denoisedDeltaPesq = metrics.denoisedPesq - metrics.inputPesq;
end

metrics.inputHaspi = calculate_optional_haspi(clean, noisy, fs);
metrics.processedHaspi = calculate_optional_haspi(clean, processed, fs);
metrics.deltaHaspi = metrics.processedHaspi - metrics.inputHaspi;
if ~isempty(denoised)
    metrics.denoisedHaspi = calculate_optional_haspi(clean, denoised, fs);
    metrics.denoisedDeltaHaspi = metrics.denoisedHaspi - metrics.inputHaspi;
end
metrics.metricNotes = 'SNR and SI-SDR are always computed. STOI, PESQ, and HASPI are computed only when compatible MATLAB functions are available; otherwise NaN is stored.';

metrics.cleanRms = sqrt(mean(clean(:).^2));
metrics.noisyRms = sqrt(mean(noisy(:).^2));
metrics.processedRms = sqrt(mean(processed(:).^2));
if ~isempty(denoised)
    metrics.denoisedRms = sqrt(mean(denoised(:).^2));
end
metrics.cleanPeak = max(abs(clean));
metrics.noisyPeak = max(abs(noisy));
metrics.processedPeak = max(abs(processed));
if ~isempty(denoised)
    metrics.denoisedPeak = max(abs(denoised));
end

function value = calculate_optional_pesq(clean, degraded, fs)
if exist('pesq', 'file') ~= 2
    value = NaN;
    return;
end

clean = clean(:);
degraded = degraded(:);
L = min(length(clean), length(degraded));
clean = clean(1:L);
degraded = degraded(1:L);

try
    value = pesq(clean, degraded, fs);
catch
    try
        value = pesq(fs, clean, degraded, 'wb');
    catch
        value = NaN;
    end
end
end

function value = calculate_optional_haspi(clean, degraded, fs)
if exist('haspi', 'file') ~= 2
    value = NaN;
    return;
end

clean = clean(:);
degraded = degraded(:);
L = min(length(clean), length(degraded));
clean = clean(1:L);
degraded = degraded(1:L);

try
    value = haspi(clean, fs, degraded, fs);
catch
    try
        value = haspi(clean, degraded, fs);
    catch
        value = NaN;
    end
end
end
end

function value = calculate_optional_stoi(clean, degraded, fs)
if exist('stoi', 'file') ~= 2
    value = NaN;
    return;
end

clean = clean(:);
degraded = degraded(:);
L = min(length(clean), length(degraded));
clean = clean(1:L);
degraded = degraded(1:L);

try
    value = stoi(degraded, clean, fs);
catch
    try
        value = stoi(clean, degraded, fs);
    catch
        value = NaN;
    end
end
end
