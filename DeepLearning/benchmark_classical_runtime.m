function results = benchmark_classical_runtime(pairManifest, outputCsv, maxCases)
% Benchmark spectral-subtraction plus actual CVBW runtime (audio I/O excluded).
if nargin < 1 || isempty(pairManifest)
    error('Pass the validation_pairs.csv path.');
end
if nargin < 2 || isempty(outputCsv)
    outputCsv = fullfile(fileparts(pairManifest), 'classical_runtime.csv');
end
if nargin < 3 || isempty(maxCases)
    maxCases = 8;
end
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repoRoot, 'DSP'));
opts = delimitedTextImportOptions('NumVariables', 12);
opts.Delimiter = ',';
opts.DataLines = [2 Inf];
opts.VariableNames = {'split','case_id','profile_id','speaker','speech_path', ...
    'noise_path','clean_crop_start_16k','noise_crop_start_16k','input_snr_db', ...
    'clean_file','noisy_file','target_file'};
opts.VariableTypes = repmat({'string'}, 1, 12);
rows = readtable(pairManifest, opts);
dataRoot = fileparts(pairManifest);
n = min(height(rows), maxCases);
caseId = zeros(n, 1);
profileId = zeros(n, 1);
spectralSubtractionMs = zeros(n, 1);
cvbwMs = zeros(n, 1);
totalMs = zeros(n, 1);

for k = 1:n
    noisyPath = fullfile(dataRoot, rows.noisy_file(k));
    [noisy, fs] = audioread(noisyPath);
    profile = str2double(rows.profile_id(k));
    if k == 1
        spectral_subtraction_enhance(noisy, fs, 0.35, 1.15, 0.04);
        apply_cvbw_hearing_aid(noisy, fs, profile);
    end
    t0 = tic;
    enhanced = spectral_subtraction_enhance(noisy, fs, 0.35, 1.15, 0.04);
    spectralSubtractionMs(k) = toc(t0) * 1000;
    t0 = tic;
    apply_cvbw_hearing_aid(enhanced, fs, profile);
    cvbwMs(k) = toc(t0) * 1000;
    totalMs(k) = spectralSubtractionMs(k) + cvbwMs(k);
    caseId(k) = str2double(rows.case_id(k));
    profileId(k) = profile;
end
results = table(caseId, profileId, spectralSubtractionMs, cvbwMs, totalMs, ...
    'VariableNames', {'case_id','profile_id','spectral_subtraction_ms', ...
    'cvbw_ms','classical_total_ms'});
writetable(results, outputCsv);
fprintf('Mean classical pipeline %.2f ms for %.2f s clips (RTF %.4f).\n', ...
    mean(totalMs), numel(noisy) / fs, mean(totalMs) / (1000 * numel(noisy) / fs));
end
