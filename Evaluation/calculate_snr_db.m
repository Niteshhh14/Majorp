function snrDb = calculate_snr_db(clean, degraded)
%CALCULATE_SNR_DB Compute global SNR using clean speech as reference.

clean = clean(:);
degraded = degraded(:);
L = min(length(clean), length(degraded));
clean = clean(1:L);
degraded = degraded(1:L);

errorSignal = degraded - clean;
snrDb = 10 * log10((sum(clean.^2) + eps) / (sum(errorSignal.^2) + eps));
end
