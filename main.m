clc;
clear;
close all;

disp('-------------------------------------------');
disp(' Hybrid Hearing Aid Framework ');
disp('-------------------------------------------');

%% Add project folders

addpath(genpath('DSP'));
addpath(genpath('Evaluation'));
addpath(genpath('Visualization'));
addpath(genpath('Data'));

setPaperStyle();

%% Settings

targetFs = 16000;
targetSnrDb = 0;
audiogramNumber = 4;
runProcessingPipeline = true;
speechFile = 'Data/Speech/sample.wav';
noiseFile = 'Data/Noise/DEMAND/DKITCHEN/ch01.wav';

%% Load clean speech

if ~isfile(speechFile)
    speechFile = findFirstFile('Data/Speech/VCTK-Corpus-0.92/wav48_silence_trimmed', '*mic1.flac');
end

[x,Fs]=audioread(speechFile);
x = mean(x, 2);
x = resampleIfNeeded(x, Fs, targetFs);
x = normalizeRms(x);
Fs = targetFs;

disp('Speech Loaded');
fprintf('Speech File = %s\n',speechFile);

fprintf('Sampling Frequency = %d Hz\n',Fs);

fprintf('Signal Length = %d Samples\n',length(x));

%% Load noise and generate noisy speech

[n,noiseFs] = audioread(noiseFile);
n = mean(n, 2);
n = resampleIfNeeded(n, noiseFs, targetFs);
n = matchLength(n, length(x));
n = mixAtSnr(x, n, targetSnrDb);
noisy = x + n;
peak = max(abs(noisy));
if peak > 0.95
    scale = 0.95 / peak;
    x = x * scale;
    n = n * scale;
    noisy = noisy * scale;
end

disp('Noise Loaded');
fprintf('Noise File = %s\n',noiseFile);
fprintf('Target SNR = %.1f dB\n',targetSnrDb);

%% Save prepared audio

if ~exist('Results/Audio','dir')
    mkdir('Results/Audio');
end
if ~exist('Results/Logs','dir')
    mkdir('Results/Logs');
end

audiowrite('Results/Audio/clean_16k.wav', x, Fs);
audiowrite('Results/Audio/noise_16k.wav', n, Fs);
audiowrite('Results/Audio/noisy_0dB.wav', noisy, Fs);
writeMainSummary('Results/Logs/main_data_preparation_summary.txt', ...
    speechFile, noiseFile, Fs, targetSnrDb, length(x));

%% Plot signals

if ~exist('Results/Figures','dir')
    mkdir('Results/Figures');
end

figure('Name','Prepared Audio Waveforms','Color','w');
subplot(3,1,1);
plot((0:length(x)-1)/Fs, x, 'k');
title('Clean Speech');
xlabel('Time (s)');
ylabel('Amplitude');
formatAxes(gca);

subplot(3,1,2);
plot((0:length(n)-1)/Fs, n, 'Color', [0.35 0.35 0.35]);
title('Noise');
xlabel('Time (s)');
ylabel('Amplitude');
formatAxes(gca);

subplot(3,1,3);
plot((0:length(noisy)-1)/Fs, noisy, 'b');
title('Noisy Speech');
xlabel('Time (s)');
ylabel('Amplitude');
formatAxes(gca);
safeExportFigure(gcf, 'Results/Figures/prepared_audio_waveforms.png');

%% Play noisy speech

if usejava('desktop')
    sound(noisy,Fs);
else
    disp('Audio playback skipped outside MATLAB Desktop.');
end

if runProcessingPipeline
    [metrics, outputFiles] = run_full_pipeline(audiogramNumber);
    writeMainPipelineSummary('Results/Logs/main_full_run_summary.txt', ...
        audiogramNumber, metrics, outputFiles);
end

disp('Done');

function filePath = findFirstFile(rootFolder, pattern)
files = dir(fullfile(rootFolder, '**', pattern));
if isempty(files)
    error('No file matching %s found under %s', pattern, rootFolder);
end
filePath = fullfile(files(1).folder, files(1).name);
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

function writeMainSummary(reportFile, speechFile, noiseFile, fs, targetSnrDb, signalLength)
fid = fopen(reportFile, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'Main Data Preparation Summary\n');
fprintf(fid, 'Speech file: %s\n', speechFile);
fprintf(fid, 'Noise file: %s\n', noiseFile);
fprintf(fid, 'Sampling frequency: %d Hz\n', fs);
fprintf(fid, 'Target SNR: %.2f dB\n', targetSnrDb);
fprintf(fid, 'Signal length: %d samples\n', signalLength);
fprintf(fid, 'Clean audio: Results/Audio/clean_16k.wav\n');
fprintf(fid, 'Noise audio: Results/Audio/noise_16k.wav\n');
fprintf(fid, 'Noisy audio: Results/Audio/noisy_0dB.wav\n');
end

function writeMainPipelineSummary(reportFile, audiogramNumber, metrics, outputFiles)
fid = fopen(reportFile, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'Main Full Run Summary\n');
fprintf(fid, 'Audiogram preset: %d\n', audiogramNumber);
fprintf(fid, 'Input SNR: %.2f dB\n', metrics.inputSnrDb);
fprintf(fid, 'Denoised SNR: %.2f dB\n', metrics.denoisedSnrDb);
fprintf(fid, 'Denoised delta SNR: %.2f dB\n', metrics.denoisedDeltaSnrDb);
fprintf(fid, 'Processed SNR: %.2f dB\n', metrics.processedSnrDb);
fprintf(fid, 'Processed delta SNR: %.2f dB\n', metrics.deltaSnrDb);
fprintf(fid, 'Clean audio: %s\n', outputFiles.clean);
fprintf(fid, 'Noisy audio: %s\n', outputFiles.noisy);
fprintf(fid, 'Denoised audio: %s\n', outputFiles.denoised);
fprintf(fid, 'Processed audio: %s\n', outputFiles.processed);
fprintf(fid, 'Metrics MAT: %s\n', outputFiles.metrics);
fprintf(fid, 'Pipeline report: %s\n', outputFiles.report);
fprintf(fid, 'Waveform figure: %s\n', outputFiles.waveforms);
fprintf(fid, 'Spectrogram figure: %s\n', outputFiles.spectrograms);
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
