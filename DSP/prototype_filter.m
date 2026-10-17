function [hh, info] = prototype_filter(fs, fixedBW)
%PROTOTYPE_FILTER Design the fixed low-pass FIR used by the CVBW reference.

PbRip_dB = 0.05;
SbRip_dB = 80;
PbRip = 10^(PbRip_dB / 20) - 1;
SbRip = 10^(-SbRip_dB / 20);

cf = fixedBW / fs;
pb = cf;
del = 2600 / fs;
sb = pb + del;

[n,fo,mo,w] = firpmord([pb sb], [1 0], [PbRip,SbRip], 1);
hh = firpm(n, fo, mo, w);

info = struct();
info.order = n;
info.passband = pb;
info.stopband = sb;
info.passbandRippleDb = PbRip_dB;
info.stopbandAttenuationDb = SbRip_dB;
end
