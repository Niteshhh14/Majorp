function evaluationSummary = run_evaluation_grid(maxCases)
%RUN_EVALUATION_GRID Evaluate speech/noise/SNR/audiogram combinations.

if nargin < 1
    maxCases = 12;
end

clc;
close all;

disp('-------------------------------------------');
disp(' Multi-Combination MATLAB Evaluation ');
disp('-------------------------------------------');

addpath(genpath('DSP'));
addpath(genpath('Evaluation'));
addpath(genpath('Visualization'));
addpath(genpath('Data'));

targetFs = 16000;
maxDurationSeconds = 1.5;
numSpeechFiles = 5;
snrLevels = [-5 0 5 10];
audiogramNumbers = [1 4 35 36];

speechFiles = dir(fullfile('Data', 'Speech', 'VCTK-Corpus-0.92', ...
    'wav48_silence_trimmed', '**', '*mic1.flac'));
if numel(speechFiles) < numSpeechFiles
    error('Only %d speech files found; requested %d.', numel(speechFiles), numSpeechFiles);
end

noiseFolders = dir(fullfile('Data', 'Noise', 'DEMAND'));
noiseFolders = noiseFolders([noiseFolders.isdir]);
noiseFolders = noiseFolders(~ismember({noiseFolders.name}, {'.','..'}));
noiseFiles = {};
for i = 1:numel(noiseFolders)
    candidate = fullfile(noiseFolders(i).folder, noiseFolders(i).name, 'ch01.wav');
    if isfile(candidate)
        noiseFiles{end+1,1} = candidate; %#ok<AGROW>
    end
end
if isempty(noiseFiles)
    error('No DEMAND ch01.wav noise files found.');
end

rootFolder = fullfile('Results', 'EvaluationGrid');
ensureFolder(rootFolder);

totalFullGridCases = numSpeechFiles * numel(noiseFiles) * numel(snrLevels) * numel(audiogramNumbers);
caseCount = min(maxCases, totalFullGridCases);
evaluationSummary = initializeSummary(caseCount);
selectedCaseIndices = unique(round(linspace(1, totalFullGridCases, caseCount)));
while numel(selectedCaseIndices) < caseCount
    missing = setdiff(1:totalFullGridCases, selectedCaseIndices, 'stable');
    selectedCaseIndices(end+1) = missing(1); %#ok<AGROW>
end
selectedCaseIndices = selectedCaseIndices(1:caseCount);

for caseIdx = 1:caseCount
    linearIdx = selectedCaseIndices(caseIdx);
    [a, q, n, s] = ind2sub([numel(audiogramNumbers), numel(snrLevels), numel(noiseFiles), numSpeechFiles], linearIdx);

    caseId = sprintf('case_%03d', caseIdx);
    resultFolder = fullfile(rootFolder, caseId);
    audioFolder = fullfile(resultFolder, 'Audio');
    logsFolder = fullfile(resultFolder, 'Logs');
    ensureFolder(audioFolder);
    ensureFolder(logsFolder);

    speechFile = fullfile(speechFiles(s).folder, speechFiles(s).name);
    noiseFile = noiseFiles{n};
    snrDb = snrLevels(q);
    audiogramNumber = audiogramNumbers(a);

    fprintf('\nRunning %s of %d\n', caseId, caseCount);
    fprintf('Speech %d/%d, Noise %d/%d, SNR %.1f dB, Audiogram %d\n', ...
        s, numSpeechFiles, n, numel(noiseFiles), snrDb, audiogramNumber);

    [clean, noise, noisy, fs] = prepareNoisyExample( ...
        speechFile, noiseFile, targetFs, snrDb, maxDurationSeconds);

    cleanFile = fullfile(audioFolder, 'clean_16k.wav');
    noiseOutFile = fullfile(audioFolder, 'noise_16k.wav');
    noisyFile = fullfile(audioFolder, sprintf('noisy_%+ddB.wav', snrDb));
    audiowrite(cleanFile, clean, fs);
    audiowrite(noiseOutFile, noise, fs);
    audiowrite(noisyFile, noisy, fs);

    [metrics, outputFiles] = run_full_pipeline(audiogramNumber, cleanFile, noisyFile, resultFolder);

    writeCaseSummary(fullfile(logsFolder, 'case_summary.txt'), ...
        caseId, speechFile, noiseFile, snrDb, audiogramNumber, maxDurationSeconds, metrics, outputFiles);

    evaluationSummary(caseIdx) = makeSummaryRow(caseId, speechFile, noiseFile, ...
        snrDb, audiogramNumber, metrics, resultFolder);
end

finishEvaluation(rootFolder, evaluationSummary, totalFullGridCases);
end

function [clean, noise, noisy, fs] = prepareNoisyExample(speechFile, noiseFile, targetFs, snrDb, maxDurationSeconds)
[clean, speechFs] = audioread(speechFile);
clean = mean(clean, 2);
clean = resampleIfNeeded(clean, speechFs, targetFs);
clean = normalizeRms(clean);

maxSamples = round(maxDurationSeconds * targetFs);
if length(clean) > maxSamples
    clean = clean(1:maxSamples);
end

[noise, noiseFs] = audioread(noiseFile);
noise = mean(noise, 2);
noise = resampleIfNeeded(noise, noiseFs, targetFs);
noise = matchLength(noise, length(clean));
noise = mixAtSnr(clean, noise, snrDb);

noisy = clean + noise;
peak = max(abs(noisy));
if peak > 0.95
    scale = 0.95 / peak;
    clean = clean * scale;
    noise = noise * scale;
    noisy = noisy * scale;
end

fs = targetFs;
end

function y = resampleIfNeeded(x, fs, targetFs)
if fs == targetFs
    y = x;
else
    try
        y = resample(x, targetFs, fs);
    catch ME
        warning('resample failed (%s). Using linear interpolation fallback.', ME.message);
        tIn = (0:length(x)-1)' / fs;
        tOut = (0:round(length(x) * targetFs / fs)-1)' / targetFs;
        y = interp1(tIn, x, tOut, 'linear', 0);
    end
end
end

function y = normalizeRms(x)
x = x - mean(x);
r = sqrt(mean(x.^2) + eps);
y = x / r * 0.05;
end

function y = matchLength(x, targetLength)
if length(x) >= targetLength
    y = x(1:targetLength);
else
    repeats = ceil(targetLength / length(x));
    y = repmat(x, repeats, 1);
    y = y(1:targetLength);
end
end

function noiseOut = mixAtSnr(clean, noise, snrDb)
cleanPower = mean(clean.^2);
noisePower = mean(noise.^2) + eps;
targetNoisePower = cleanPower / (10^(snrDb / 10));
noiseOut = noise * sqrt(targetNoisePower / noisePower);
end

function summary = initializeSummary(caseCount)
summary = repmat(struct( ...
    'caseId', '', 'speechFile', '', 'noiseFile', '', ...
    'snrDb', NaN, 'audiogramNumber', NaN, ...
    'inputSnrDb', NaN, 'denoisedSnrDb', NaN, 'processedSnrDb', NaN, ...
    'inputSiSdrDb', NaN, 'denoisedSiSdrDb', NaN, 'processedSiSdrDb', NaN, ...
    'inputStoi', NaN, 'denoisedStoi', NaN, 'processedStoi', NaN, ...
    'inputPesq', NaN, 'denoisedPesq', NaN, 'processedPesq', NaN, ...
    'inputHaspi', NaN, 'denoisedHaspi', NaN, 'processedHaspi', NaN, ...
    'noisyAidedSiSdrDb', NaN, 'processedAidedSiSdrDb', NaN, 'deltaAidedSiSdrDb', NaN, ...
    'noisyAidedStoi', NaN, 'processedAidedStoi', NaN, 'deltaAidedStoi', NaN, ...
    'maxMatchingErrorDb', NaN, 'minMatchingErrorDb', NaN, 'meanAbsMatchingErrorDb', NaN, ...
    'resultFolder', ''), caseCount, 1);
end

function row = makeSummaryRow(caseId, speechFile, noiseFile, snrDb, audiogramNumber, metrics, resultFolder)
row = initializeSummary(1);
row.caseId = caseId;
row.speechFile = speechFile;
row.noiseFile = noiseFile;
row.snrDb = snrDb;
row.audiogramNumber = audiogramNumber;
row.inputSnrDb = metrics.inputSnrDb;
row.denoisedSnrDb = metrics.denoisedSnrDb;
row.processedSnrDb = metrics.processedSnrDb;
row.inputSiSdrDb = metrics.inputSiSdrDb;
row.denoisedSiSdrDb = metrics.denoisedSiSdrDb;
row.processedSiSdrDb = metrics.processedSiSdrDb;
row.inputStoi = metrics.inputStoi;
row.denoisedStoi = metrics.denoisedStoi;
row.processedStoi = metrics.processedStoi;
row.inputPesq = metrics.inputPesq;
row.denoisedPesq = metrics.denoisedPesq;
row.processedPesq = metrics.processedPesq;
row.inputHaspi = metrics.inputHaspi;
row.denoisedHaspi = metrics.denoisedHaspi;
row.processedHaspi = metrics.processedHaspi;
row.noisyAidedSiSdrDb = metrics.aidedReference.noisyAidedSiSdrDb;
row.processedAidedSiSdrDb = metrics.aidedReference.processedAidedSiSdrDb;
row.deltaAidedSiSdrDb = metrics.aidedReference.deltaAidedSiSdrDb;
row.noisyAidedStoi = metrics.aidedReference.noisyAidedStoi;
row.processedAidedStoi = metrics.aidedReference.processedAidedStoi;
row.deltaAidedStoi = metrics.aidedReference.deltaAidedStoi;
row.maxMatchingErrorDb = metrics.maxMatchingErrorDb;
row.minMatchingErrorDb = metrics.minMatchingErrorDb;
row.meanAbsMatchingErrorDb = metrics.meanAbsMatchingErrorDb;
row.resultFolder = resultFolder;
end

function writeCaseSummary(reportFile, caseId, speechFile, noiseFile, snrDb, audiogramNumber, maxDurationSeconds, metrics, outputFiles)
fid = fopen(reportFile, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'Evaluation Case Summary\n');
fprintf(fid, 'Case ID: %s\n', caseId);
fprintf(fid, 'Speech file: %s\n', speechFile);
fprintf(fid, 'Noise file: %s\n', noiseFile);
fprintf(fid, 'Target SNR: %.2f dB\n', snrDb);
fprintf(fid, 'Audiogram preset: %d\n', audiogramNumber);
fprintf(fid, 'Maximum duration: %.2f seconds\n', maxDurationSeconds);
fprintf(fid, 'Input SNR: %.2f dB\n', metrics.inputSnrDb);
fprintf(fid, 'Denoised SNR: %.2f dB\n', metrics.denoisedSnrDb);
fprintf(fid, 'Processed SNR: %.2f dB\n', metrics.processedSnrDb);
fprintf(fid, 'Spectral-subtraction alpha: %.2f\n', metrics.noiseReductionAlpha);
fprintf(fid, 'Spectral-subtraction floor factor: %.2f\n', metrics.noiseReductionFloorFactor);
fprintf(fid, 'Input SI-SDR: %.2f dB\n', metrics.inputSiSdrDb);
fprintf(fid, 'Denoised SI-SDR: %.2f dB\n', metrics.denoisedSiSdrDb);
fprintf(fid, 'Processed SI-SDR: %.2f dB\n', metrics.processedSiSdrDb);
fprintf(fid, 'Input STOI: %.4f\n', metrics.inputStoi);
fprintf(fid, 'Denoised STOI: %.4f\n', metrics.denoisedStoi);
fprintf(fid, 'Processed STOI: %.4f\n', metrics.processedStoi);
fprintf(fid, 'Matched aided-reference SI-SDR change after denoising: %.2f dB\n', ...
    metrics.aidedReference.deltaAidedSiSdrDb);
fprintf(fid, 'Matched aided-reference STOI change after denoising: %.4f\n', ...
    metrics.aidedReference.deltaAidedStoi);
fprintf(fid, 'Input PESQ: %.4f\n', metrics.inputPesq);
fprintf(fid, 'Denoised PESQ: %.4f\n', metrics.denoisedPesq);
fprintf(fid, 'Processed PESQ: %.4f\n', metrics.processedPesq);
fprintf(fid, 'Input HASPI: %.4f\n', metrics.inputHaspi);
fprintf(fid, 'Denoised HASPI: %.4f\n', metrics.denoisedHaspi);
fprintf(fid, 'Processed HASPI: %.4f\n', metrics.processedHaspi);
fprintf(fid, 'Maximum matching error: %.2f dB\n', metrics.maxMatchingErrorDb);
fprintf(fid, 'Minimum matching error: %.2f dB\n', metrics.minMatchingErrorDb);
fprintf(fid, 'Mean absolute matching error: %.2f dB\n', metrics.meanAbsMatchingErrorDb);
fprintf(fid, 'Metric notes: %s\n', metrics.metricNotes);
fprintf(fid, 'Clean audio: %s\n', outputFiles.clean);
fprintf(fid, 'Noisy audio: %s\n', outputFiles.noisy);
fprintf(fid, 'Denoised audio: %s\n', outputFiles.denoised);
fprintf(fid, 'Processed audio: %s\n', outputFiles.processed);
fprintf(fid, 'Waveform figure: %s\n', outputFiles.waveforms);
fprintf(fid, 'Spectrogram figure: %s\n', outputFiles.spectrograms);
fprintf(fid, 'Prototype response figure: %s\n', outputFiles.prototypeResponse);
fprintf(fid, 'CVBW audiogram fit figure: %s\n', outputFiles.cvbwAudiogramFit);
fprintf(fid, 'Audiogram matching error figure: %s\n', outputFiles.audiogramMatchingError);
fprintf(fid, 'CVBW sub-band RMS figure: %s\n', outputFiles.cvbwSubbandRms);
end

function finishEvaluation(rootFolder, evaluationSummary, totalFullGridCases)
csvFile = fullfile(rootFolder, 'evaluation_summary.csv');
matFile = fullfile(rootFolder, 'evaluation_summary.mat');
reportFile = fullfile(rootFolder, 'evaluation_report.txt');

writeEvaluationCsv(csvFile, evaluationSummary);
save(matFile, 'evaluationSummary');

fid = fopen(reportFile, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'Multi-Combination MATLAB Evaluation Report\n');
fprintf(fid, 'Cases executed: %d\n', numel(evaluationSummary));
fprintf(fid, 'Full grid size if expanded: %d\n', totalFullGridCases);
fprintf(fid, 'SNR levels: -5, 0, 5, 10 dB\n');
fprintf(fid, 'Audiogram profiles: 1, 4, 35, 36\n');
fprintf(fid, 'Metrics: SNR, SI-SDR, optional STOI, optional PESQ, optional HASPI\n');
fprintf(fid, 'Mean denoised SNR gain: %.2f dB\n', mean([evaluationSummary.denoisedSnrDb] - [evaluationSummary.inputSnrDb], 'omitnan'));
fprintf(fid, 'Mean processed SNR delta: %.2f dB\n', mean([evaluationSummary.processedSnrDb] - [evaluationSummary.inputSnrDb], 'omitnan'));
fprintf(fid, 'Mean matched aided-reference SI-SDR change: %.2f dB\n', ...
    mean([evaluationSummary.deltaAidedSiSdrDb], 'omitnan'));
fprintf(fid, 'Mean matched aided-reference STOI change: %.4f\n', ...
    mean([evaluationSummary.deltaAidedStoi], 'omitnan'));
fprintf(fid, ['Raw processed-versus-clean metrics are diagnostic only after audiogram shaping; ' ...
    'use matched aided-reference changes to evaluate denoising after CVBW.\n']);

fprintf('Evaluation summary saved to %s\n', csvFile);
fprintf('Evaluation report saved to %s\n', reportFile);
disp('Multi-combination evaluation complete.');
end

function writeEvaluationCsv(csvFile, summary)
fid = fopen(csvFile, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, ['case_id,snr_db,audiogram_number,input_snr_db,denoised_snr_db,processed_snr_db,' ...
    'input_si_sdr_db,denoised_si_sdr_db,processed_si_sdr_db,' ...
    'input_stoi,denoised_stoi,processed_stoi,input_pesq,denoised_pesq,processed_pesq,' ...
    'input_haspi,denoised_haspi,processed_haspi,aided_noisy_si_sdr_db,aided_processed_si_sdr_db,' ...
    'aided_delta_si_sdr_db,aided_noisy_stoi,aided_processed_stoi,aided_delta_stoi,' ...
    'max_matching_error_db,min_matching_error_db,mean_abs_matching_error_db,result_folder\n']);
for i = 1:numel(summary)
    fprintf(fid, '%s,%.1f,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.4f,%.4f,%.4f,%.6f,%.6f,%.6f,%.4f,%.4f,%.4f,%s\n', ...
        summary(i).caseId, summary(i).snrDb, summary(i).audiogramNumber, ...
        summary(i).inputSnrDb, summary(i).denoisedSnrDb, summary(i).processedSnrDb, ...
        summary(i).inputSiSdrDb, summary(i).denoisedSiSdrDb, summary(i).processedSiSdrDb, ...
        summary(i).inputStoi, summary(i).denoisedStoi, summary(i).processedStoi, ...
        summary(i).inputPesq, summary(i).denoisedPesq, summary(i).processedPesq, ...
        summary(i).inputHaspi, summary(i).denoisedHaspi, summary(i).processedHaspi, ...
        summary(i).noisyAidedSiSdrDb, summary(i).processedAidedSiSdrDb, summary(i).deltaAidedSiSdrDb, ...
        summary(i).noisyAidedStoi, summary(i).processedAidedStoi, summary(i).deltaAidedStoi, ...
        summary(i).maxMatchingErrorDb, summary(i).minMatchingErrorDb, summary(i).meanAbsMatchingErrorDb, ...
        summary(i).resultFolder);
end
end

function ensureFolder(folderPath)
if ~exist(folderPath, 'dir')
    mkdir(folderPath);
end
end
