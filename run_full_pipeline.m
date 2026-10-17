function [metrics, outputFiles] = run_full_pipeline(audiogramNumber, cleanFile, noisyFile, resultFolder)
%RUN_FULL_PIPELINE Run denoising plus CVBW audiogram fitting on prepared audio.

if nargin < 1
    audiogramNumber = 4;
end
if nargin < 2 || isempty(cleanFile)
    cleanFile = 'Results/Audio/clean_16k.wav';
end
if nargin < 3 || isempty(noisyFile)
    noisyFile = 'Results/Audio/noisy_0dB.wav';
end
if nargin < 4 || isempty(resultFolder)
    resultFolder = 'Results';
end

disp('-------------------------------------------');
disp(' Full MATLAB Hearing Aid Pipeline ');
disp('-------------------------------------------');

addpath(genpath('DSP'));
addpath(genpath('Evaluation'));
addpath(genpath('Visualization'));
addpath(genpath('Data'));

fs = 16000;
audioFolder = fullfile(resultFolder, 'Audio');
figuresFolder = fullfile(resultFolder, 'Figures');
metricsFolder = fullfile(resultFolder, 'Metrics');

if ~isfile(cleanFile) || ~isfile(noisyFile)
    error('Run main.m first to generate clean/noisy audio files.');
end

[clean, cleanFs] = audioread(cleanFile);
[noisy, noisyFs] = audioread(noisyFile);

if cleanFs ~= fs || noisyFs ~= fs
    error('Expected 16 kHz input files. Run main.m again to regenerate prepared audio.');
end

clean = mean(clean, 2);
noisy = mean(noisy, 2);
L = min(length(clean), length(noisy));
clean = clean(1:L);
noisy = noisy(1:L);

preset = get_cvbw_preset(audiogramNumber);
fprintf('Applying audiogram preset %d: %s\n', audiogramNumber, preset.name);

fprintf('Running spectral-subtraction noise suppression...\n');
[denoised, noiseReductionDebug] = spectral_subtraction_enhance(noisy, fs, 0.35);

fprintf('Running CVBW audiogram fitting...\n');
[processed, debug] = apply_cvbw_hearing_aid(denoised, fs, audiogramNumber);
processed = processed(1:L);
denoised = denoised(1:L);

metrics = evaluate_basic_metrics(clean, noisy, processed, fs, denoised);

ensureFolder(audioFolder);
ensureFolder(metricsFolder);
ensureFolder(figuresFolder);

processedFile = fullfile(audioFolder, sprintf('processed_audiogram_%02d.wav', audiogramNumber));
denoisedFile = fullfile(audioFolder, 'denoised_spectral_subtraction.wav');
audiowrite(denoisedFile, denoised, fs);
audiowrite(processedFile, processed, fs);

plot_pipeline_results(clean, noisy, processed, fs, metrics, figuresFolder, denoised);
fittingFigures = plot_cvbw_fitting_results(debug, audiogramNumber, fs, figuresFolder);
metrics.maxMatchingErrorDb = fittingFigures.maxMatchingErrorDb;
metrics.minMatchingErrorDb = fittingFigures.minMatchingErrorDb;
metrics.meanAbsMatchingErrorDb = fittingFigures.meanAbsMatchingErrorDb;

metricsFile = fullfile(metricsFolder, sprintf('full_pipeline_audiogram_%02d.mat', audiogramNumber));
reportFile = fullfile(metricsFolder, sprintf('full_pipeline_audiogram_%02d_report.txt', audiogramNumber));

save(metricsFile, ...
    'fs', 'audiogramNumber', 'preset', 'metrics', 'debug', ...
    'noiseReductionDebug', 'fittingFigures', ...
    'cleanFile', 'noisyFile', 'denoisedFile', 'processedFile');

writePipelineReport(reportFile, fs, audiogramNumber, preset, metrics, denoisedFile, processedFile);

fprintf('Input SNR     = %.2f dB\n', metrics.inputSnrDb);
fprintf('Denoised SNR  = %.2f dB\n', metrics.denoisedSnrDb);
fprintf('Denoised gain = %.2f dB\n', metrics.denoisedDeltaSnrDb);
fprintf('Processed SNR = %.2f dB\n', metrics.processedSnrDb);
fprintf('Delta SNR     = %.2f dB\n', metrics.deltaSnrDb);
fprintf('Denoised audio saved to %s\n', denoisedFile);
fprintf('Processed audio saved to %s\n', processedFile);
fprintf('Report saved to %s\n', reportFile);
disp('Full pipeline complete.');

outputFiles = struct();
outputFiles.clean = cleanFile;
outputFiles.noisy = noisyFile;
outputFiles.denoised = denoisedFile;
outputFiles.processed = processedFile;
outputFiles.metrics = metricsFile;
outputFiles.report = reportFile;
outputFiles.waveforms = fullfile(figuresFolder, 'full_pipeline_waveforms.png');
outputFiles.spectrograms = fullfile(figuresFolder, 'full_pipeline_spectrograms.png');
outputFiles.prototypeResponse = fittingFigures.prototype;
outputFiles.cvbwAudiogramFit = fittingFigures.bands;
outputFiles.audiogramMatchingError = fittingFigures.error;
outputFiles.cvbwSubbandRms = fittingFigures.subbandRms;
end

function ensureFolder(folderPath)
if ~exist(folderPath, 'dir')
    mkdir(folderPath);
end
end

function writePipelineReport(reportFile, fs, audiogramNumber, preset, metrics, denoisedFile, processedFile)
fid = fopen(reportFile, 'w');
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'Full MATLAB Hearing Aid Pipeline Report\n');
fprintf(fid, 'Audiogram preset: %d - %s\n', audiogramNumber, preset.name);
fprintf(fid, 'Sampling frequency: %d Hz\n', fs);
fprintf(fid, 'Input SNR: %.2f dB\n', metrics.inputSnrDb);
fprintf(fid, 'Denoised SNR: %.2f dB\n', metrics.denoisedSnrDb);
fprintf(fid, 'Denoised delta SNR: %.2f dB\n', metrics.denoisedDeltaSnrDb);
fprintf(fid, 'Processed SNR: %.2f dB\n', metrics.processedSnrDb);
fprintf(fid, 'Delta SNR: %.2f dB\n', metrics.deltaSnrDb);
fprintf(fid, 'Input SI-SDR: %.2f dB\n', metrics.inputSiSdrDb);
fprintf(fid, 'Denoised SI-SDR: %.2f dB\n', metrics.denoisedSiSdrDb);
fprintf(fid, 'Processed SI-SDR: %.2f dB\n', metrics.processedSiSdrDb);
fprintf(fid, 'Input STOI: %.4f\n', metrics.inputStoi);
fprintf(fid, 'Denoised STOI: %.4f\n', metrics.denoisedStoi);
fprintf(fid, 'Processed STOI: %.4f\n', metrics.processedStoi);
fprintf(fid, 'Maximum matching error: %.2f dB\n', metrics.maxMatchingErrorDb);
fprintf(fid, 'Minimum matching error: %.2f dB\n', metrics.minMatchingErrorDb);
fprintf(fid, 'Mean absolute matching error: %.2f dB\n', metrics.meanAbsMatchingErrorDb);
fprintf(fid, 'Metric notes: %s\n', metrics.metricNotes);
fprintf(fid, 'Denoised audio: %s\n', denoisedFile);
fprintf(fid, 'Processed audio: %s\n', processedFile);
end
