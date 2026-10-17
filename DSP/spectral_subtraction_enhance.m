function [enhanced, debug] = spectral_subtraction_enhance(noisy, fs, noiseEstimateSeconds, alpha, floorFactor)
%SPECTRAL_SUBTRACTION_ENHANCE Classical DSP noise suppression baseline.

if nargin < 3
    noiseEstimateSeconds = 0.35;
end
if nargin < 4 || isempty(alpha)
    alpha = 1.15;
end
if nargin < 5 || isempty(floorFactor)
    floorFactor = 0.04;
end
if ~isscalar(alpha) || ~isfinite(alpha) || alpha < 0
    error('alpha must be a finite, nonnegative scalar.');
end
if ~isscalar(floorFactor) || ~isfinite(floorFactor) || floorFactor < 0 || floorFactor > 1
    error('floorFactor must be a finite scalar in [0, 1].');
end

noisy = noisy(:);
frameLength = 256;
hopLength = 128;
nfft = 512;
window = hamming(frameLength, 'periodic');
numFrames = 1 + ceil((length(noisy) - frameLength) / hopLength);
paddedLength = (numFrames - 1) * hopLength + frameLength;
x = [noisy; zeros(paddedLength - length(noisy), 1)];

noiseFrames = max(1, floor((noiseEstimateSeconds * fs - frameLength) / hopLength) + 1);
noiseFrames = min(noiseFrames, numFrames);
noiseMag = zeros(nfft, 1);

for k = 1:noiseFrames
    idx = (k-1) * hopLength + (1:frameLength);
    frame = x(idx) .* window;
    noiseMag = noiseMag + abs(fft(frame, nfft));
end
noiseMag = noiseMag / noiseFrames;

y = zeros(paddedLength, 1);
winSum = zeros(paddedLength, 1);

for k = 1:numFrames
    idx = (k-1) * hopLength + (1:frameLength);
    frame = x(idx) .* window;
    Y = fft(frame, nfft);
    mag = abs(Y);
    phase = angle(Y);
    enhancedMag = max(mag - alpha * noiseMag, floorFactor * mag);
    enhancedFrame = real(ifft(enhancedMag .* exp(1j * phase), nfft));
    enhancedFrame = enhancedFrame(1:frameLength) .* window;
    y(idx) = y(idx) + enhancedFrame;
    winSum(idx) = winSum(idx) + window.^2;
end

enhanced = y ./ (winSum + eps);
enhanced = enhanced(1:length(noisy));

peak = max(abs(enhanced));
if peak > 0.95
    enhanced = 0.95 * enhanced / peak;
end

debug = struct();
debug.frameLength = frameLength;
debug.hopLength = hopLength;
debug.nfft = nfft;
debug.alpha = alpha;
debug.floorFactor = floorFactor;
debug.noiseEstimateSeconds = noiseEstimateSeconds;
debug.noiseFrames = noiseFrames;
debug.noiseMag = noiseMag;
end
