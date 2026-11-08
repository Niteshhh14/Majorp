function generate_cvbw_targets(manifestPath)
% Generate exact project-CVBW clean targets for a prepared pair manifest.
if nargin < 1 || isempty(manifestPath)
    error('Pass the train_pairs.csv or validation_pairs.csv path.');
end
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(repoRoot);
addpath(fullfile(repoRoot, 'DSP'));
manifestPath = char(manifestPath);
options = delimitedTextImportOptions('NumVariables', 12);
options.Delimiter = ',';
options.DataLines = [2 Inf];
options.VariableNames = {'split','case_id','profile_id','speaker','speech_path', ...
    'noise_path','clean_crop_start_16k','noise_crop_start_16k','input_snr_db', ...
    'clean_file','noisy_file','target_file'};
options.VariableTypes = repmat({'string'}, 1, 12);
rows = readtable(manifestPath, options);
dataRoot = fileparts(manifestPath);

for k = 1:height(rows)
    cleanPath = fullfile(dataRoot, rows{k, "clean_file"});
    targetPath = fullfile(dataRoot, rows{k, "target_file"});
    profile = str2double(rows.profile_id(k));
    [clean, fs] = audioread(cleanPath);
    if fs ~= 16000
        error('Expected 16 kHz audio in %s.', cleanPath);
    end
    [target, ~] = apply_cvbw_hearing_aid(clean, fs, profile);
    targetFolder = fileparts(targetPath);
    if ~exist(targetFolder, 'dir')
        mkdir(targetFolder);
    end
    audiowrite(targetPath, target, fs, 'BitsPerSample', 16);
    if mod(k, 16) == 0 || k == height(rows)
        fprintf('CVBW targets %d/%d complete.\n', k, height(rows));
    end
end
fprintf('Saved %d targets under %s\n', height(rows), dataRoot);
end
