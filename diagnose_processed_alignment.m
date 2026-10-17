function diagnostics = diagnose_processed_alignment(sampleNumbers, maxLagSeconds)
%DIAGNOSE_PROCESSED_ALIGNMENT Compare raw and lag-aligned CVBW SI-SDR.
% This diagnostic determines whether the low end-to-end score is mostly a
% fixed delay or remains after best-lag alignment. Alignment does not alter
% the audio; it is reported separately so a real timing defect is not hidden.

if nargin < 1 || isempty(sampleNumbers)
    sampleNumbers = 1:10;
end
if nargin < 2 || isempty(maxLagSeconds)
    maxLagSeconds = 0.5;
end

addpath(genpath('Evaluation'));
diagnostics = table('Size', [0 8], ...
    'VariableTypes', {'string','double','double','double','double','double','double','double'}, ...
    'VariableNames', {'sample_id','audiogram_number','best_lag_ms','max_abs_correlation', ...
    'input_si_sdr_db','denoised_si_sdr_db','processed_si_sdr_db', ...
    'aligned_processed_si_sdr_db'});

for sampleNumber = sampleNumbers
    sampleId = sprintf('sample_%02d', sampleNumber);
    resultFolder = fullfile('Results', 'Samples', sampleId);
    metricsFiles = dir(fullfile(resultFolder, 'Metrics', 'full_pipeline_audiogram_*.mat'));
    if isempty(metricsFiles)
        warning('Skipping %s: saved pipeline MAT file not found.', sampleId);
        continue;
    end
    [~, latestIdx] = max([metricsFiles.datenum]);
    metricsFile = fullfile(metricsFiles(latestIdx).folder, metricsFiles(latestIdx).name);

    saved = load(metricsFile, 'fs', 'audiogramNumber', 'cleanFile', 'noisyFile', ...
        'denoisedFile', 'processedFile');
    [clean, fs] = audioread(saved.cleanFile);
    [noisy, noisyFs] = audioread(saved.noisyFile);
    [denoised, denoisedFs] = audioread(saved.denoisedFile);
    [processed, processedFs] = audioread(saved.processedFile);
    if any([fs noisyFs denoisedFs processedFs] ~= saved.fs)
        error('%s contains audio with inconsistent sample rates.', sampleId);
    end

    clean = mean(clean, 2);
    noisy = mean(noisy, 2);
    denoised = mean(denoised, 2);
    processed = mean(processed, 2);
    commonLength = min([numel(clean), numel(noisy), numel(denoised), numel(processed)]);
    clean = clean(1:commonLength);
    noisy = noisy(1:commonLength);
    denoised = denoised(1:commonLength);
    processed = processed(1:commonLength);

    maxLag = min(round(maxLagSeconds * fs), commonLength - 1);
    [correlation, lags] = xcorr(clean - mean(clean), processed - mean(processed), ...
        maxLag, 'coeff');
    [maxCorrelation, peakIndex] = max(abs(correlation));
    bestLag = lags(peakIndex);
    [alignedClean, alignedProcessed] = alignToLag(clean, processed, bestLag);

    diagnostics(end+1,:) = {string(sampleId), saved.audiogramNumber, ...
        1000*bestLag/fs, maxCorrelation, ...
        calculate_si_sdr_db(clean, noisy), calculate_si_sdr_db(clean, denoised), ...
        calculate_si_sdr_db(clean, processed), ...
        calculate_si_sdr_db(alignedClean, alignedProcessed)}; %#ok<AGROW>
end

outputFolder = fullfile('Results', 'Diagnostics');
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end
writetable(diagnostics, fullfile(outputFolder, 'processed_alignment_diagnostic.csv'));
disp(diagnostics);
end

function [referenceAligned, signalAligned] = alignToLag(reference, signal, lag)
if lag > 0
    referenceAligned = reference(1+lag:end);
    signalAligned = signal(1:end-lag);
elseif lag < 0
    referenceAligned = reference(1:end+lag);
    signalAligned = signal(1-lag:end);
else
    referenceAligned = reference;
    signalAligned = signal;
end
end
