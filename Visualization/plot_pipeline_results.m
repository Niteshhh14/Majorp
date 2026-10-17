function plot_pipeline_results(clean, noisy, processed, fs, metrics, outputFolder, denoised)
%PLOT_PIPELINE_RESULTS Save waveform and spectrogram comparison figures.

if nargin < 7
    denoised = [];
end

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

set(groot, 'defaultFigureColor', 'w');
set(groot, 'defaultAxesColor', 'w');
set(groot, 'defaultAxesXColor', 'k');
set(groot, 'defaultAxesYColor', 'k');
set(groot, 'defaultTextColor', 'k');
set(groot, 'defaultAxesFontName', 'Times New Roman');
set(groot, 'defaultTextFontName', 'Times New Roman');
set(groot, 'defaultAxesFontSize', 8);
set(groot, 'defaultLineLineWidth', 1.0);

t = (0:length(clean)-1) / fs;

if isempty(denoised)
    figure('Name','Full Pipeline Waveforms', 'Color', 'w', ...
        'Units', 'inches', 'Position', [0.5 0.5 7.16 5.4]);
    tiledlayout(3,1, 'TileSpacing', 'compact', 'Padding', 'compact');
else
    figure('Name','Full Pipeline Waveforms', 'Color', 'w', ...
        'Units', 'inches', 'Position', [0.5 0.5 7.16 6.2]);
    tiledlayout(4,1, 'TileSpacing', 'compact', 'Padding', 'compact');
end
nexttile;
plot(t, clean, 'Color', [0.00 0.25 0.45], 'LineWidth', 0.9);
title('Clean Speech');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;
formatAxes(gca);

nexttile;
plot(t, noisy, 'Color', [0.78 0.27 0.07], 'LineWidth', 0.9);
title(sprintf('Noisy Speech, SNR %.2f dB', metrics.inputSnrDb));
xlabel('Time (s)');
ylabel('Amplitude');
grid on;
formatAxes(gca);

if ~isempty(denoised)
    nexttile;
    plot(t, denoised, 'Color', [0.00 0.43 0.32], 'LineWidth', 0.9);
    title(sprintf('Denoised Speech, SNR %.2f dB', metrics.denoisedSnrDb));
    xlabel('Time (s)');
    ylabel('Amplitude');
    grid on;
    formatAxes(gca);
end

nexttile;
plot(t, processed, 'Color', [0.58 0.08 0.12], 'LineWidth', 0.9);
title(sprintf('Processed Speech, SNR %.2f dB', metrics.processedSnrDb));
xlabel('Time (s)');
ylabel('Amplitude');
grid on;
formatAxes(gca);
safeExportFigure(gcf, fullfile(outputFolder, 'full_pipeline_waveforms.png'));

figure('Name','Full Pipeline Spectrograms', 'Color', 'w', ...
    'Units', 'inches', 'Position', [0.5 0.5 7.16 8.5]);
tiledlayout(3 + ~isempty(denoised), 1, 'TileSpacing', 'compact', 'Padding', 'compact');
plotSpectrogram(clean, fs, 'Clean Speech');
plotSpectrogram(noisy, fs, 'Noisy Speech');
if ~isempty(denoised)
    plotSpectrogram(denoised, fs, 'Denoised Speech');
end
plotSpectrogram(processed, fs, 'Processed Speech');
safeExportFigure(gcf, fullfile(outputFolder, 'full_pipeline_spectrograms.png'));
end

function plotSpectrogram(x, fs, plotTitle)
nexttile;
windowLength = min(512, max(128, 2^nextpow2(floor(length(x) / 16))));
overlapLength = floor(0.75 * windowLength);
nfft = max(512, windowLength);
spectrogram(x, hamming(windowLength), overlapLength, nfft, fs, 'yaxis');
title(plotTitle);
colorbar;
formatAxes(gca);
end

function formatAxes(ax)
set(ax, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
    'FontName', 'Times New Roman', 'FontSize', 8, ...
    'LineWidth', 0.9, 'Box', 'on', 'GridColor', [0.68 0.68 0.68]);
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
