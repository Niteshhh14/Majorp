clc;
clear;
close all;

disp('-------------------------------------------');
disp(' DSP Validation: CVBW Audiogram Matching ');
disp('-------------------------------------------');

addpath(genpath('DSP'));
addpath(genpath('Visualization'));
addpath(genpath('Results'));

fs = 16000;
BW_val = [200 300 400 500 600 800];
fixedBW = BW_val(1);

[hh, protoInfo] = prototype_filter(fs, fixedBW);
fprintf('Prototype FIR order = %d\n', protoInfo.order);
fprintf('Passband = %.5f normalized, Stopband = %.5f normalized\n', ...
    protoInfo.passband, protoInfo.stopband);

Q = Farrow_diff(4);
fprintf('Farrow coefficient matrix size = %d x %d\n', size(Q,1), size(Q,2));

audiogramNumber = 35;
[x2,y2,audiogram_type] = get_audiogram(audiogramNumber);
fprintf('Audiogram %d:%s\n', audiogramNumber, audiogram_type);

BW = [200 200 300 300 300 400];
shift1 = [0.02649 0.1248 0.2 0.28 0.36 0.48];
gain = [86.73 86.5 91 85 89 93.7];

[matchingError, maximumError] = audiogram_matching( ...
    BW, BW_val, fixedBW, shift1, gain, hh, x2, y2, audiogram_type);

fprintf('Maximum matching error = %.2f dB\n', maximumError(1));
fprintf('Minimum matching error = %.2f dB\n', maximumError(2));

figuresFolder = fullfile(pwd, 'Results', 'Figures');
if ~exist(figuresFolder,'dir')
    mkdir(figuresFolder);
end

figures = findall(0, 'Type', 'figure');
for k = 1:numel(figures)
    pngFile = fullfile(figuresFolder, sprintf('dsp_validation_figure_%02d.png', k));
    try
        exportgraphics(figures(k), pngFile, 'Resolution', 300);
    catch ME
        warning('Could not export %s (%s). Saving MATLAB figure instead.', pngFile, ME.message);
        savefig(figures(k), fullfile(figuresFolder, sprintf('dsp_validation_figure_%02d.fig', k)));
    end
end

save(fullfile(pwd, 'Results', 'dsp_validation.mat'), ...
    'fs', 'BW_val', 'fixedBW', 'BW', 'shift1', 'gain', ...
    'protoInfo', 'matchingError', 'maximumError', ...
    'audiogramNumber', 'audiogram_type');

disp('DSP validation complete.');
