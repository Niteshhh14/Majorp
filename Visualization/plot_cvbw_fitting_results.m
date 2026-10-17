function fittingFigures = plot_cvbw_fitting_results(debug, audiogramNumber, fs, outputFolder)
%PLOT_CVBW_FITTING_RESULTS Save IEEE-style CVBW and audiogram-fitting figures.

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

setPaperStyle();

preset = debug.preset;
[x2, y2, ~] = get_audiogram(audiogramNumber);
[hh, ~] = prototype_filter(fs, preset.fixedBW);

[bandFrequency, bandDb, matchingDb, targetDb, matchingError] = ...
    calculateMatchingCurves(preset, hh, x2, y2);

fittingFigures = struct();
fittingFigures.prototype = fullfile(outputFolder, 'cvbw_prototype_filter_response.png');
fittingFigures.bands = fullfile(outputFolder, 'cvbw_band_responses_and_audiogram_fit.png');
fittingFigures.error = fullfile(outputFolder, 'audiogram_matching_error.png');
fittingFigures.subbandRms = fullfile(outputFolder, 'cvbw_audio_subband_rms.png');
matchingError = matchingError(:).';
fittingFigures.maxMatchingErrorDb = max(matchingError);
fittingFigures.minMatchingErrorDb = min(matchingError);
fittingFigures.meanAbsMatchingErrorDb = mean(abs(matchingError), 'omitnan');

figure('Name', 'CVBW Prototype Filter Response', 'Color', 'w', ...
    'Units', 'inches', 'Position', [0.5 0.5 7.16 4.2]);
[H, W] = freqz(hh, 1, 2048);
plot(W / (2*pi) * fs, mag2db(abs(H) + eps), 'Color', [0.00 0.24 0.48], 'LineWidth', 1.25);
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Shared Prototype FIR Low-Pass Response');
grid on;
formatAxes(gca);
safeExportFigure(gcf, fittingFigures.prototype);
close(gcf);

figure('Name', 'CVBW Audiogram Fitting', 'Color', 'w', ...
    'Units', 'inches', 'Position', [0.5 0.5 7.16 4.2]);
hold on;
bandColors = [0.00 0.28 0.50; 0.78 0.26 0.08; 0.00 0.43 0.32; ...
    0.49 0.22 0.56; 0.58 0.38 0.05; 0.00 0.48 0.62];
bandStyles = {'-', '--', '-.', ':', '-', '--'};
pBand = gobjects(size(bandDb, 1), 1);
for i = 1:size(bandDb, 1)
    pBand(i) = plot(bandFrequency, bandDb(i,:), 'Color', bandColors(i,:), ...
        'LineStyle', bandStyles{i}, 'LineWidth', 1.2);
end
pTarget = plot(bandFrequency, targetDb, 'k', 'LineWidth', 1.7);
pMatch = plot(bandFrequency, matchingDb, '--', 'Color', [0.72 0.08 0.12], 'LineWidth', 1.7);
xlabel('Normalized frequency');
ylabel('Magnitude (dB)');
title(sprintf('CVBW Fit for Audiogram Profile %d', audiogramNumber), ...
    'FontSize', 9, 'FontWeight', 'bold');
bandLabels = arrayfun(@(k) sprintf('Band %d', k), 1:size(bandDb, 1), 'UniformOutput', false);
legend([pTarget pMatch pBand.'], [{'Audiogram target', 'Combined response'}, bandLabels], ...
    'Location', 'northeast', 'NumColumns', 2, 'FontSize', 7.5, ...
    'TextColor', 'k', 'Color', 'w', 'Box', 'on');
allFitValues = [bandDb(:); matchingDb(:); targetDb(:)];
allFitValues = allFitValues(isfinite(allFitValues));
yMin = max(-20, floor((min(allFitValues) - 5) / 10) * 10);
yMax = ceil((max(allFitValues) + 5) / 10) * 10;
axis([0 0.5 yMin yMax]);
grid on;
formatAxes(gca);
safeExportFigure(gcf, fittingFigures.bands);
close(gcf);

figure('Name', 'Audiogram Matching Error', 'Color', 'w', ...
    'Units', 'inches', 'Position', [0.5 0.5 7.16 4.2]);
plot(bandFrequency, matchingError, 'Color', [0.00 0.28 0.50], 'LineWidth', 1.5);
hold on;
plot([0 0.5], [0 0], 'k-', 'LineWidth', 0.75);
xlabel('Normalized frequency');
ylabel('Error (dB)');
title('Audiogram Matching Error');
axis([0 0.5 -15 15]);
grid on;
formatAxes(gca);
safeExportFigure(gcf, fittingFigures.error);
close(gcf);

if isfield(debug, 'bands') && ~isempty(debug.bands)
    figure('Name', 'CVBW Audio Sub-Band RMS', 'Color', 'w', ...
        'Units', 'inches', 'Position', [0.5 0.5 7.16 4.2]);
    bandRms = sqrt(mean(debug.bands.^2, 2));
    bar(1:numel(bandRms), bandRms, 'FaceColor', [0.00 0.35 0.58], 'EdgeColor', 'k');
    xlabel('CVBW band');
    ylabel('RMS amplitude');
    title('Audio Energy Captured by Each CVBW Band');
    grid on;
    formatAxes(gca);
    safeExportFigure(gcf, fittingFigures.subbandRms);
    close(gcf);
end
end

function [freq, bandDb, matchingDb, targetDb, matchingError] = calculateMatchingCurves(preset, hh, x2, y2)
ln = 1024;
impulse = [1 zeros(1, ln)];
rf = 2 * preset.fixedBW ./ preset.BW_val;

bbsSelected = zeros(1, length(preset.BW));
for r = 1:length(preset.BW)
    idx = find(preset.BW_val == preset.BW(r), 1);
    if isempty(idx)
        error('Bandwidth %g Hz is not present in BW_val.', preset.BW(r));
    end
    bbsSelected(r) = idx;
end

bandDb = zeros(length(preset.BW), ln);
for i = 1:length(preset.BW)
    temp = VariableSRC_Farrow_8_sub(impulse, hh, rf(bbsSelected(i)), preset.shift(i), ln);
    response = temp(1:ln);
    [gh, w] = freqz(response, 1, ln);
    bandDb(i,:) = preset.gainDb(i) + mag2db(abs(gh') + eps);
end

freq = w(:).' / (2*pi);
linearSum = sum(10.^(bandDb / 20), 1);
matchingDb = mag2db(linearSum + eps);
targetDb = interp1(x2, y2, freq, 'linear', 'extrap');
matchingError = targetDb - matchingDb;
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
set(groot, 'defaultLineLineWidth', 1.25);
end

function formatAxes(ax)
set(ax, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
    'FontName', 'Times New Roman', 'FontSize', 8, ...
    'LineWidth', 0.9, 'Box', 'on', 'GridColor', [0.68 0.68 0.68]);
end

function safeExportFigure(figHandle, outputFile)
outputFolder = fileparts(outputFile);
tempFile = [tempname(outputFolder) '.png'];

try
    exportgraphics(figHandle, tempFile, 'Resolution', 320);
catch exportError
    try
        print(figHandle, tempFile, '-dpng', '-r300');
    catch saveError
        warning('Could not export figure %s. exportgraphics: %s saveas: %s', ...
            outputFile, exportError.message, saveError.message);
        return;
    end
end

fileInfo = dir(tempFile);
if isempty(fileInfo) || fileInfo.bytes == 0
    warning('Exported figure is empty: %s', outputFile);
    return;
end

if isfile(outputFile)
    delete(outputFile);
end
movefile(tempFile, outputFile, 'f');
end
