function regenerate_sample_figures(sampleNumbers)
%REGENERATE_SAMPLE_FIGURES Rebuild audiogram/CVBW figures from saved runs.

if nargin < 1 || isempty(sampleNumbers)
    sampleNumbers = 1:10;
end

addpath(genpath('DSP'));
addpath(genpath('Visualization'));
close all;

for sampleNumber = sampleNumbers
    sampleId = sprintf('sample_%02d', sampleNumber);
    resultFolder = fullfile('Results', 'Samples', sampleId);
    metricsFolder = fullfile(resultFolder, 'Metrics');
    metricsFiles = dir(fullfile(metricsFolder, 'full_pipeline_audiogram_*.mat'));
    if isempty(metricsFiles)
        warning('Skipping %s: saved pipeline MAT file not found.', sampleId);
        continue;
    end
    [~, latestIdx] = max([metricsFiles.datenum]);
    metricsFile = fullfile(metricsFiles(latestIdx).folder, metricsFiles(latestIdx).name);
    saved = load(metricsFile, 'fs', 'audiogramNumber', 'debug');

    removeStaleProfileOutputs(resultFolder, saved.audiogramNumber);
    plot_cvbw_fitting_results(saved.debug, saved.audiogramNumber, ...
        saved.fs, fullfile(resultFolder, 'Figures'));
    fprintf('Regenerated audiogram/CVBW figures for %s (profile %d).\n', ...
        sampleId, saved.audiogramNumber);
end
end

function removeStaleProfileOutputs(resultFolder, activeProfile)
metricsFolder = fullfile(resultFolder, 'Metrics');
audioFolder = fullfile(resultFolder, 'Audio');
files = [dir(fullfile(metricsFolder, 'full_pipeline_audiogram_*.mat')); ...
    dir(fullfile(metricsFolder, 'full_pipeline_audiogram_*_report.txt')); ...
    dir(fullfile(audioFolder, 'processed_audiogram_*.wav'))];
for i = 1:numel(files)
    token = regexp(files(i).name, 'audiogram_(\d+)', 'tokens', 'once');
    if isempty(token) || str2double(token{1}) ~= activeProfile
        delete(fullfile(files(i).folder, files(i).name));
    end
end
end
