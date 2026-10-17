function batchSummary = run_batch_samples(numSamples)
%RUN_BATCH_SAMPLES Run the MATLAB pipeline on multiple VCTK/DEMAND examples.

if nargin < 1
    numSamples = 5;
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
audiogramNumber = 4;
maxDurationSeconds = 2.5;

speechFiles = dir(fullfile('Data', 'Speech', 'VCTK-Corpus-0.92', ...
    'wav48_silence_trimmed', '**', '*mic1.flac'));
if numel(speechFiles) < numSamples
    error('Only %d speech files found; requested %d.', numel(speechFiles), numSamples);
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
    'resultFolder', ''), numSamples, 1);

for i = 1:numSamples
    sampleId = sprintf('sample_%02d', i);
    resultFolder = fullfile('Results', 'Samples', sampleId);
    audioFolder = fullfile(resultFolder, 'Audio');
    logsFolder = fullfile(resultFolder, 'Logs');
    ensureFolder(audioFolder);
    ensureFolder(logsFolder);

    speechFile = fullfile(speechFiles(i).folder, speechFiles(i).name);
    noiseFile = noiseFiles{mod(i-1, numel(noiseFiles)) + 1};

    fprintf('\nRunning %s\n', sampleId);
    fprintf('Speech: %s\n', speechFile);
    fprintf('Noise: %s\n', noiseFile);

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
        sampleId, speechFile, noiseFile, targetSnrDb, maxDurationSeconds, metrics, outputFiles);

    batchSummary(i).sampleId = sampleId;
    batchSummary(i).speechFile = speechFile;
    batchSummary(i).noiseFile = noiseFile;
    batchSummary(i).inputSnrDb = metrics.inputSnrDb;
    batchSummary(i).denoisedSnrDb = metrics.denoisedSnrDb;
    batchSummary(i).denoisedDeltaSnrDb = metrics.denoisedDeltaSnrDb;
    batchSummary(i).processedSnrDb = metrics.processedSnrDb;
    batchSummary(i).processedDeltaSnrDb = metrics.deltaSnrDb;
    batchSummary(i).resultFolder = resultFolder;
end

writeBatchSummary(fullfile('Results', 'Samples', 'batch_summary.csv'), batchSummary);
save(fullfile('Results', 'Samples', 'batch_summary.mat'), 'batchSummary');

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

figure('Name', 'Prepared Audio', 'Color', 'w');
tiledlayout(3,1);
nexttile;
plot(t, clean, 'k');
title('Clean Speech');
xlabel('Time (s)');
ylabel('Amplitude');
formatAxes(gca);

nexttile;
plot(t, noise, 'Color', [0.35 0.35 0.35]);
title('Noise');
xlabel('Time (s)');
ylabel('Amplitude');
formatAxes(gca);

nexttile;
plot(t, noisy, 'b');
title('Noisy Speech');
xlabel('Time (s)');
ylabel('Amplitude');
formatAxes(gca);

safeExportFigure(gcf, fullfile(outputFolder, 'prepared_audio_waveforms.png'));
end

function writeSampleSummary(reportFile, sampleId, speechFile, noiseFile, targetSnrDb, maxDurationSeconds, metrics, outputFiles)
fid = fopen(reportFile, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'Sample Pipeline Summary\n');
fprintf(fid, 'Sample ID: %s\n', sampleId);
fprintf(fid, 'Speech file: %s\n', speechFile);
fprintf(fid, 'Noise file: %s\n', noiseFile);
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
fid = fopen(csvFile, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'sample_id,input_snr_db,denoised_snr_db,denoised_delta_snr_db,processed_snr_db,processed_delta_snr_db,result_folder\n');
for i = 1:numel(batchSummary)
    fprintf(fid, '%s,%.4f,%.4f,%.4f,%.4f,%.4f,%s\n', ...
        batchSummary(i).sampleId, ...
        batchSummary(i).inputSnrDb, ...
        batchSummary(i).denoisedSnrDb, ...
        batchSummary(i).denoisedDeltaSnrDb, ...
        batchSummary(i).processedSnrDb, ...
        batchSummary(i).processedDeltaSnrDb, ...
        batchSummary(i).resultFolder);
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
set(groot, 'defaultAxesFontSize', 10);
set(groot, 'defaultLineLineWidth', 1.0);
end

function formatAxes(ax)
set(ax, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
    'FontName', 'Times New Roman', 'FontSize', 10, ...
    'LineWidth', 0.75, 'Box', 'on', 'GridColor', [0.75 0.75 0.75]);
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
    exportgraphics(figHandle, outputFile, 'Resolution', 300);
catch exportError
    try
        saveas(figHandle, outputFile);
    catch saveError
        warning('Could not export figure %s. exportgraphics: %s saveas: %s', ...
            outputFile, exportError.message, saveError.message);
    end
end
end
