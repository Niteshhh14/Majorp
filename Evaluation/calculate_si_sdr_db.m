function siSdrDb = calculate_si_sdr_db(clean, degraded)
%CALCULATE_SI_SDR_DB Compute scale-invariant signal-to-distortion ratio.

clean = clean(:);
degraded = degraded(:);
L = min(length(clean), length(degraded));
clean = clean(1:L);
degraded = degraded(1:L);

clean = clean - mean(clean);
degraded = degraded - mean(degraded);

targetEnergy = sum(clean.^2) + eps;
projection = (sum(degraded .* clean) / targetEnergy) * clean;
noise = degraded - projection;

siSdrDb = 10 * log10((sum(projection.^2) + eps) / (sum(noise.^2) + eps));
end
