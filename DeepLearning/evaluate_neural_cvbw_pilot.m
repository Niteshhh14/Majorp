function results = evaluate_neural_cvbw_pilot(caseIndices, artifactDir)
% EVALUATE_NEURAL_CVBW_PILOT Compare neural/classical denoising after shared CVBW.
% Reads the deterministic WAVs exported by evaluate_speech_enhancer.py, applies
% the same profile-specific CVBW transformation to clean/noisy/classical/neural
% signals, then reports paired aided-reference SI-SDR and optional STOI.

if nargin < 1 || isempty(caseIndices)
    caseIndices = 1:4; % One example for each profile; increase after timing check.
end
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(repoRoot);
addpath(fullfile(repoRoot, 'DSP'));
addpath(fullfile(repoRoot, 'Evaluation'));
if nargin < 2 || isempty(artifactDir)
    artifactDir = fullfile(repoRoot, 'Results', 'DeepLearning', 'pilot_sisdr_crops');
end
audioDir = fullfile(artifactDir, 'audio');
manifest = readtable(fullfile(artifactDir, 'validation_metrics.csv'));

if any(caseIndices < 1) || any(caseIndices > height(manifest))
    error('caseIndices must be between 1 and %d.', height(manifest));
end

caseId = zeros(numel(caseIndices), 1);
profileId = zeros(numel(caseIndices), 1);
inputSnrDb = zeros(numel(caseIndices), 1);
noisyAidedSiSdrDb = nan(numel(caseIndices), 1);
classicalAidedSiSdrDb = nan(numel(caseIndices), 1);
neuralAidedSiSdrDb = nan(numel(caseIndices), 1);
noisyAidedStoi = nan(numel(caseIndices), 1);
classicalAidedStoi = nan(numel(caseIndices), 1);
neuralAidedStoi = nan(numel(caseIndices), 1);

for k = 1:numel(caseIndices)
    row = caseIndices(k);
    id = manifest.case_id(row);
    profile = manifest.audiogram_profile(row);
    prefix = sprintf('case_%03d_', id);
    clean = read_audio(fullfile(audioDir, [prefix 'clean.wav']));
    noisy = read_audio(fullfile(audioDir, [prefix 'noisy.wav']));
    classical = read_audio(fullfile(audioDir, [prefix 'spectral_subtraction.wav']));
    neural = read_audio(fullfile(audioDir, [prefix 'neural.wav']));

    [cleanAided, ~] = apply_cvbw_hearing_aid(clean, 16000, profile);
    [noisyAided, ~] = apply_cvbw_hearing_aid(noisy, 16000, profile);
    [classicalAided, ~] = apply_cvbw_hearing_aid(classical, 16000, profile);
    [neuralAided, ~] = apply_cvbw_hearing_aid(neural, 16000, profile);
    L = min([numel(cleanAided), numel(noisyAided), ...
             numel(classicalAided), numel(neuralAided)]);
    cleanAided = cleanAided(1:L);
    noisyAided = noisyAided(1:L);
    classicalAided = classicalAided(1:L);
    neuralAided = neuralAided(1:L);

    caseId(k) = id;
    profileId(k) = profile;
    inputSnrDb(k) = manifest.input_snr_db(row);
    noisyAidedSiSdrDb(k) = calculate_si_sdr_db(cleanAided, noisyAided);
    classicalAidedSiSdrDb(k) = calculate_si_sdr_db(cleanAided, classicalAided);
    neuralAidedSiSdrDb(k) = calculate_si_sdr_db(cleanAided, neuralAided);
    noisyAidedStoi(k) = optional_stoi(noisyAided, cleanAided);
    classicalAidedStoi(k) = optional_stoi(classicalAided, cleanAided);
    neuralAidedStoi(k) = optional_stoi(neuralAided, cleanAided);
    fprintf('case %03d profile %d: paired aided SI-SDR classical %.2f dB, neural %.2f dB\n', ...
        id, profile, classicalAidedSiSdrDb(k), neuralAidedSiSdrDb(k));
end

results = table(caseId, profileId, inputSnrDb, noisyAidedSiSdrDb, ...
    classicalAidedSiSdrDb, neuralAidedSiSdrDb, ...
    classicalAidedSiSdrDb - noisyAidedSiSdrDb, ...
    neuralAidedSiSdrDb - noisyAidedSiSdrDb, ...
    noisyAidedStoi, classicalAidedStoi, neuralAidedStoi, ...
    classicalAidedStoi - noisyAidedStoi, neuralAidedStoi - noisyAidedStoi, ...
    'VariableNames', {'case_id','profile_id','input_snr_db', ...
    'noisy_aided_sisdr_db','classical_aided_sisdr_db','neural_aided_sisdr_db', ...
    'classical_delta_sisdr_db','neural_delta_sisdr_db', ...
    'noisy_aided_stoi','classical_aided_stoi','neural_aided_stoi', ...
    'classical_delta_stoi','neural_delta_stoi'});
writetable(results, fullfile(artifactDir, 'aided_reference_metrics.csv'));
end

function x = read_audio(path)
[x, fs] = audioread(path);
if fs ~= 16000
    error('Expected 16 kHz audio: %s', path);
end
x = x(:);
end

function value = optional_stoi(degraded, reference)
if exist('stoi', 'file') ~= 2
    value = NaN;
    return;
end
try
    value = stoi(degraded, reference, 16000);
catch
    value = NaN;
end
end
