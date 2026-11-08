function results = evaluate_direct_aided_prediction(manifestPath, outputCsv)
% Compare direct neural CVBW-target predictions to MATLAB-generated references.
if nargin < 1 || isempty(manifestPath) || nargin < 2 || isempty(outputCsv)
    error('Pass the validation_pairs.csv and output CSV paths.');
end
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repoRoot, 'Evaluation'));
options = delimitedTextImportOptions('NumVariables', 12);
options.Delimiter = ',';
options.DataLines = [2 Inf];
options.VariableNames = {'split','case_id','profile_id','speaker','speech_path', ...
    'noise_path','clean_crop_start_16k','noise_crop_start_16k','input_snr_db', ...
    'clean_file','noisy_file','target_file'};
options.VariableTypes = repmat({'string'}, 1, 12);
rows = readtable(manifestPath, options);
dataRoot = fileparts(manifestPath);
artifactDir = fileparts(fileparts(manifestPath));
audioDir = fullfile(artifactDir, 'audio');
n = height(rows);
caseId = zeros(n, 1);
profileId = zeros(n, 1);
sisdrDb = nan(n, 1);
stoiValue = nan(n, 1);

for k = 1:n
    caseId(k) = str2double(rows.case_id(k));
    profileId(k) = str2double(rows.profile_id(k));
    targetPath = fullfile(dataRoot, rows.target_file(k));
    outputPath = fullfile(audioDir, sprintf('case_%03d_profile_%02d_direct_model.wav', ...
        caseId(k), profileId(k)));
    [reference, fsRef] = audioread(targetPath);
    [estimate, fsEst] = audioread(outputPath);
    if fsRef ~= 16000 || fsEst ~= 16000
        error('Expected 16 kHz target and estimate.');
    end
    L = min(numel(reference), numel(estimate));
    reference = reference(1:L);
    estimate = estimate(1:L);
    sisdrDb(k) = calculate_si_sdr_db(reference, estimate);
    if exist('stoi', 'file') == 2
        try
            stoiValue(k) = stoi(estimate, reference, 16000);
        catch
            stoiValue(k) = NaN;
        end
    end
end
results = table(caseId, profileId, sisdrDb, stoiValue, ...
    'VariableNames', {'case_id','profile_id','direct_aided_sisdr_db','direct_aided_stoi'});
writetable(results, outputCsv);
fprintf('Direct-to-CVBW-target model: mean SI-SDR %.3f dB; mean STOI %.4f (%d valid).\n', ...
    mean(sisdrDb, 'omitnan'), mean(stoiValue, 'omitnan'), sum(isfinite(stoiValue)));
end
