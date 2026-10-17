function [processed, debug] = apply_cvbw_hearing_aid(noisy, fs, audiogramNumber)
%APPLY_CVBW_HEARING_AID Apply the MATLAB CVBW reference bank to an audio signal.

preset = get_cvbw_preset(audiogramNumber);
[hh, protoInfo] = prototype_filter(fs, preset.fixedBW);

bbs_selected = zeros(1, length(preset.BW));
for r = 1:length(preset.BW)
    idx = find(preset.BW_val == preset.BW(r), 1);
    if isempty(idx)
        error('Bandwidth %g Hz is not present in BW_val.', preset.BW(r));
    end
    bbs_selected(r) = idx;
end

rf = 2 * preset.fixedBW ./ preset.BW_val;
ln = length(noisy);
x = noisy(:).';
bands = zeros(length(preset.BW), ln);

for i = 1:length(preset.BW)
    temp = VariableSRC_Farrow_8_sub(x, hh, rf(bbs_selected(i)), preset.shift(i), ln);
    temp = real(temp(:).');
    bands(i,:) = matchBandLength(temp, ln);
end

linearGain = 10.^(preset.gainDb(:) / 20);
processedRaw = sum(bands .* linearGain, 1).';
processed = processedRaw - mean(processedRaw);

peak = max(abs(processed));
if peak > 0
    processed = 0.95 * processed / peak;
end

debug = struct();
debug.preset = preset;
debug.prototypeInfo = protoInfo;
debug.rf = rf;
debug.selectedRf = rf(bbs_selected);
debug.bands = bands;
debug.processedRaw = processedRaw;
end

function y = matchBandLength(x, targetLength)
if length(x) >= targetLength
    y = x(1:targetLength);
else
    y = zeros(1, targetLength);
    y(1:length(x)) = x;
end
end
