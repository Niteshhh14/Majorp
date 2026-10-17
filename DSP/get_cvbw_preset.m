function preset = get_cvbw_preset(audiogramNumber)
%GET_CVBW_PRESET Return manually tuned CVBW parameters from the reference code.

preset = struct();
preset.BW_val = [200 300 400 500 600 800];
preset.fixedBW = preset.BW_val(1);
preset.audiogramNumber = audiogramNumber;

switch audiogramNumber
    case 1
        preset.name = 'Mild hearing loss at all frequencies';
        preset.BW = [300 300 300 300 300 400];
        preset.shift = [-0.011 0.1185 0.21 0.289 0.366 0.484];
        preset.gainDb = [25 33.49 24.4 20.8 25.6 29.3];
    case 2
        preset.name = 'Mild hearing loss at high frequencies';
        preset.BW = [200 400 200 200 300 400];
        preset.shift = [-0.03 0.098 0.1764 0.252 0.330 0.42];
        preset.gainDb = [1 2.9 6.5 27.77 27 13.7];
    case 3
        preset.name = 'Mild to moderate hearing loss at low frequencies';
        preset.BW = [200 300 300 300 400 600];
        preset.shift = [0.006 0.059 0.1405 0.2093 0.3225 0.496];
        preset.gainDb = [27.3 26.7 18.2 12.5 14.7 19];
    case 4
        preset.name = 'Moderate hearing loss at high frequencies';
        preset.BW = [200 200 400 500 500 500];
        preset.shift = [0.02 0.12 0.153 0.274 0.38 0.52];
        preset.gainDb = [2 16 38.25 47.5 53 64];
    case 35
        preset.name = 'Profound hearing loss';
        preset.BW = [200 200 300 300 300 400];
        preset.shift = [0.02649 0.1248 0.2 0.28 0.36 0.48];
        preset.gainDb = [86.73 86.5 91 85 89 93.7];
    case 36
        preset.name = 'Severe hearing loss in mid to high frequencies';
        preset.BW = [300 300 300 200 300 500];
        preset.shift = [0.0612 0.11 0.1992 0.251 0.32 0.439];
        preset.gainDb = [16.3 42.35 72.25 86.5 79.1 68.2];
    otherwise
        error('No CVBW preset is defined for audiogram number %d.', audiogramNumber);
end
end
