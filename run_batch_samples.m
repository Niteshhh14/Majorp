function batchSummary = run_batch_samples(numSamples, startSample, audiogramNumbers)
%RUN_BATCH_SAMPLES Run the MATLAB pipeline on multiple VCTK/DEMAND examples.
% Audiograms default to a reproducible cycle through the profiles under study.

if nargin < 1
    numSamples = 5;
end
if nargin < 2
    startSample = 1;
end
profileCycle = [1 4 35 36];
if nargin < 3 || isempty(audiogramNumbers)
    sampleNumbers = startSample:(startSample + numSamples - 1);
    audiogramNumbers = profileCycle(mod(sampleNumbers - 1, numel(profileCycle)) + 1);
elseif isscalar(audiogramNumbers)
    audiogramNumbers = repmat(audiogramNumbers, 1, numSamples);
elseif numel(audiogramNumbers) ~= numSamples
    error('Provide one audiogram number per sample, or a scalar to repeat.');
end
validProfiles = [1 2 3 4 35 36];
if any(~ismember(audiogramNumbers, validProfiles))
    error('Audiogram profiles must be selected from: 1, 2, 3, 4, 35, 36.');
end
if numSamples < 1 || startSample < 1 || ...
        numSamples ~= floor(numSamples) || startSample ~= floor(startSample)
    error('numSamples and startSample must be positive integers.');
end

clc;
close all;

disp('-------------------------------------------');
disp(' Batch MATLAB Hearing Aid Evaluation ');
disp('-------------------------------------------');

addpath(genpath('DSP'));
addpath(genpath('Evaluation'));
addpath(genpath('Visualization'));
addpath(genpath('Data'));

targetFs = 16000;
targetSnrDb = 0;
maxDurationSeconds = 2.5;

speechFiles = dir(fullfile('Data', 'Speech', 'VCTK-Corpus-0.92', ...
    'wav48_silence_trimmed', '**', '*mic1.flac'));
if numel(speechFiles) < startSample + numSamples - 1
    error('Only %d speech files found; requested sample range %d-%d.', ...
        numel(speechFiles), startSample, startSample + numSamples - 1);
end

noiseFiles = {
    fullfile('Data','Noise','DEMAND','DKITCHEN','ch01.wav')
    fullfile('Data','Noise','DEMAND','DLIVING','ch01.wav')
    fullfile('Data','Noise','DEMAND','OOFFICE','ch01.wav')
    fullfile('Data','Noise','DEMAND','PCAFETER','ch01.wav')
    fullfile('Data','Noise','DEMAND','STRAFFIC','ch01.wav')
    fullfile('Data','Noise','DEMAND','TBUS','ch01.wav')
};

ensureFolder(fullfile('Results', 'Samples'));

batchSummary = repmat(struct( ...
    'sampleId', '', ...
    'speechFile', '', ...
    'noiseFile', '', ...
    'inputSnrDb', NaN, ...
    'denoisedSnrDb', NaN, ...
    'denoisedDeltaSnrDb', NaN, ...
    'processedSnrDb', NaN, ...
    'processedDeltaSnrDb', NaN, ...
    'resultFolder', '', ...
    'audiogramNumber', NaN), numSamples, 1);

for i = 1:numSamples
    sampleNumber = startSample + i - 1;
    sampleId = sprintf('sample_%02d', sampleNumber);
    resultFolder = fullfile('Results', 'Samples', sampleId);
    audioFolder = fullfile(resultFolder, 'Audio');
    logsFolder = fullfile(resultFolder, 'Logs');
    ensureFolder(audioFolder);
    ensureFolder(logsFolder);

    speechFile = fullfile(speechFiles(sampleNumber).folder, speechFiles(sampleNumber).name);
    noiseFile = noiseFiles{mod(sampleNumber-1, numel(noiseFiles)) + 1};
    audiogramNumber = audiogramNumbers(i);
    preset = get_cvbw_preset(audiogramNumber);

    fprintf('\nRunning %s\n', sampleId);
    fprintf('Speech: %s\n', speechFile);
    fprintf('Noise: %s\n', noiseFile);
    fprintf('Audiogram preset %d: %s\n', audiogramNumber, preset.name);

    [clean, noise, noisy, fs] = prepareNoisyExample( ...
        speechFile, noiseFile, targetFs, targetSnrDb, maxDurationSeconds);

    cleanFile = fullfile(audioFolder, 'clean_16k.wav');
    noiseOutFile = fullfile(audioFolder, 'noise_16k.wav');
    noisyFile = fullfile(audioFolder, 'noisy_0dB.wav');
    audiowrite(cleanFile, clean, fs);
    audiowrite(noiseOutFile, noise, fs);
    audiowrite(noisyFile, noisy, fs);

    [metrics, outputFiles] = run_full_pipeline(audiogramNumber, cleanFile, noisyFile, resultFolder);
    plotPreparedAudio(clean, noise, noisy, fs, fullfile(resultFolder, 'Figures'));

    writeSampleSummary(fullfile(logsFolder, 'sample_summary.txt'), ...
        sampleId, speechFile, noiseFile, audiogramNumber, preset.name, ...
        targetSnrDb, maxDurationSeconds, metrics, outputFiles);

    batchSummary(i).sampleId = sampleId;
    batchSummary(i).speechFile = speechFile;
    batchSummary(i).noiseFile = noiseFile;
    batchSummary(i).inputSnrDb = metrics.inputSnrDb;
    batchSummary(i).denoisedSnrDb = metrics.denoisedSnrDb;
    batchSummary(i).denoisedDeltaSnrDb = metrics.denoisedDeltaSnrDb;
    batchSummary(i).processedSnrDb = metrics.processedSnrDb;
    batchSummary(i).processedDeltaSnrDb = metrics.deltaSnrDb;
    batchSummary(i).resultFolder = resultFolder;
    batchSummary(i).audiogramNumber = audiogramNumber;
end

summaryCsv = fullfile('Results', 'Samples', 'batch_summary.csv');
writeBatchSummary(summaryCsv, batchSummary);
summaryMat = fullfile('Results', 'Samples', 'batch_summary.mat');
if isfile(summaryMat)
    previous = load(summaryMat, 'batchSummary');
    batchSummary = mergeBatchSummaries(previous.batchSummary, batchSummary);
end
save(summaryMat, 'batchSummary');

disp('Batch evaluation complete.');
end

function [clean, noise, noisy, fs] = prepareNoisyExample(speechFile, noiseFile, targetFs, targetSnrDb, maxDurationSeconds)
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
noise = mixAtSnr(clean, noise, targetSnrDb);

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

function plotPreparedAudio(clean, noise, noisy, fs, outputFolder)
ensureFolder(outputFolder);
setPaperStyle();
t = (0:length(clean)-1) / fs;

figure('Name', 'Prepared Audio', 'Color', 'w', ...
    'Units', 'inches', 'Position', [0.5 0.5 7.16 5.4]);
tiledlayout(3,1, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;
plot(t, clean, 'Color', [0.00 0.25 0.45], 'LineWidth', 0.9);
title('Clean Speech');
xlabel('Time (s)');
ylabel('Amplitude');
formatAxes(gca);

nexttile;
plot(t, noise, 'Color', [0.78 0.27 0.07], 'LineWidth', 0.9);
title('Noise');
xlabel('Time (s)');
ylabel('Amplitude');
formatAxes(gca);

nexttile;
plot(t, noisy, 'Color', [0.00 0.43 0.32], 'LineWidth', 0.9);
title('Noisy Speech');
xlabel('Time (s)');
ylabel('Amplitude');
formatAxes(gca);

safeExportFigure(gcf, fullfile(outputFolder, 'prepared_audio_waveforms.png'));
end

function writeSampleSummary(reportFile, sampleId, speechFile, noiseFile, audiogramNumber, audiogramName, targetSnrDb, maxDurationSeconds, metrics, outputFiles)
fid = fopen(reportFile, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'Sample Pipeline Summary\n');
fprintf(fid, 'Sample ID: %s\n', sampleId);
fprintf(fid, 'Speech file: %s\n', speechFile);
fprintf(fid, 'Noise file: %s\n', noiseFile);
fprintf(fid, 'Audiogram preset: %d - %s\n', audiogramNumber, audiogramName);
fprintf(fid, 'Target SNR: %.2f dB\n', targetSnrDb);
fprintf(fid, 'Maximum duration: %.2f seconds\n', maxDurationSeconds);
fprintf(fid, 'Input SNR: %.2f dB\n', metrics.inputSnrDb);
fprintf(fid, 'Denoised SNR: %.2f dB\n', metrics.denoisedSnrDb);
fprintf(fid, 'Denoised delta SNR: %.2f dB\n', metrics.denoisedDeltaSnrDb);
fprintf(fid, 'Processed SNR: %.2f dB\n', metrics.processedSnrDb);
fprintf(fid, 'Processed delta SNR: %.2f dB\n', metrics.deltaSnrDb);
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

function writeBatchSummary(csvFile, batchSummary)
oldLines = strings(0, 1);
if isfile(csvFile)
    oldLines = readlines(csvFile);
    oldLines(oldLines == "") = [];
    if ~isempty(oldLines)
        oldLines(1) = [];
    end
end
newIds = string({batchSummary.sampleId});
keepOld = true(size(oldLines));
for k = 1:numel(oldLines)
    fields = split(oldLines(k), ',');
    if ~isempty(fields) && any(fields(1) == newIds)
        keepOld(k) = false;
    end
end
oldLines = oldLines(keepOld);
fid = fopen(csvFile, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'sample_id,audiogram_number,input_snr_db,denoised_snr_db,denoised_delta_snr_db,processed_snr_db,processed_delta_snr_db,result_folder\n');
for k = 1:numel(oldLines)
    fields = split(oldLines(k), ',');
    if numel(fields) == 7
        % Legacy batch outputs were all run with hardcoded preset 4.
        oldProfile = 4;
        fields = [fields(1); string(oldProfile); fields(2:end)];
    end
    fprintf(fid, '%s\n', strjoin(fields, ','));
end
for i = 1:numel(batchSummary)
    fprintf(fid, '%s,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%s\n', ...
        batchSummary(i).sampleId, ...
        batchSummary(i).audiogramNumber, ...
        batchSummary(i).inputSnrDb, ...
        batchSummary(i).denoisedSnrDb, ...
        batchSummary(i).denoisedDeltaSnrDb, ...
        batchSummary(i).processedSnrDb, ...
        batchSummary(i).processedDeltaSnrDb, ...
        batchSummary(i).resultFolder);
end
end

function merged = mergeBatchSummaries(existing, current)
merged = existing;
if ~isfield(merged, 'audiogramNumber')
    [merged.audiogramNumber] = deal(NaN);
    for j = 1:numel(merged)
        idParts = regexp(merged(j).sampleId, 'sample_(\d+)', 'tokens', 'once');
        if ~isempty(idParts)
            % Legacy batch outputs were all run with hardcoded preset 4.
            merged(j).audiogramNumber = 4;
        end
    end
end
for k = 1:numel(current)
    idx = find(strcmp({merged.sampleId}, current(k).sampleId), 1);
    if isempty(idx)
        merged(end+1, 1) = current(k); %#ok<AGROW>
    else
        merged(idx) = current(k);
    end
end
end

function ensureFolder(folderPath)
if ~exist(folderPath, 'dir')
    mkdir(folderPath);
end
end

function setPaperStyle()
set(groot, 'defaultFigureColor', 'w');
set(groot, 'defaultAxesColor', 'w');
set(groot, 'defaultAxesXColor', 'k');
set(groot, 'defaultAxesYColor', 'k');
set(groot, 'defaultTextColor', 'k');
set(groot, 'defaultAxesFontName', 'Times New Roman');
set(groot, 'defaultTextFontName', 'Times New Roman');
set(groot, 'defaultAxesFontSize', 8);
set(groot, 'defaultLineLineWidth', 1.0);
end

function formatAxes(ax)
set(ax, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
    'FontName', 'Times New Roman', 'FontSize', 8, ...
    'LineWidth', 0.9, 'Box', 'on', 'GridColor', [0.68 0.68 0.68]);
grid(ax, 'on');
end

function safeExportFigure(figHandle, outputFile)
try
    if isfile(outputFile)
        delete(outputFile);
    end
catch
end

try
    exportgraphics(figHandle, outputFile, 'Resolution', 320);
catch exportError
    try
        saveas(figHandle, outputFile);
    catch saveError
        warning('Could not export figure %s. exportgraphics: %s saveas: %s', ...
            outputFile, exportError.message, saveError.message);
    end
end
end
