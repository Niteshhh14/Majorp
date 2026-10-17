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
set(groot, 'defaultAxesFontSize', 10);
set(groot, 'defaultLineLineWidth', 1.0);

t = (0:length(clean)-1) / fs;

if isempty(denoised)
    figure('Name','Full Pipeline Waveforms', 'Color', 'w');
    tiledlayout(3,1);
else
    figure('Name','Full Pipeline Waveforms', 'Color', 'w');
    tiledlayout(4,1);
end
nexttile;
plot(t, clean);
title('Clean Speech');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;
formatAxes(gca);

nexttile;
plot(t, noisy);
title(sprintf('Noisy Speech, SNR %.2f dB', metrics.inputSnrDb));
xlabel('Time (s)');
ylabel('Amplitude');
grid on;
formatAxes(gca);

if ~isempty(denoised)
    nexttile;
    plot(t, denoised);
    title(sprintf('Denoised Speech, SNR %.2f dB', metrics.denoisedSnrDb));
    xlabel('Time (s)');
    ylabel('Amplitude');
    grid on;
    formatAxes(gca);
end

nexttile;
plot(t, processed);
title(sprintf('Processed Speech, SNR %.2f dB', metrics.processedSnrDb));
xlabel('Time (s)');
ylabel('Amplitude');
grid on;
formatAxes(gca);
safeExportFigure(gcf, fullfile(outputFolder, 'full_pipeline_waveforms.png'));

figure('Name','Full Pipeline Spectrograms', 'Color', 'w');
tiledlayout(3 + ~isempty(denoised), 1);
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
    'FontName', 'Times New Roman', 'FontSize', 10, ...
    'LineWidth', 0.75, 'Box', 'on', 'GridColor', [0.75 0.75 0.75]);
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
