% Load audio file using UI dialog
[filename, pathname] = uigetfile('*.wav', 'Select a WAV file');
if isequal(filename, 0)
    error('No file selected.');
end
[audioData, fs] = audioread(fullfile(pathname, filename));

% Convert to mono if stereo
if size(audioData, 2) > 1
    audioData = mean(audioData, 2);
end

% Parameters for MFCC extraction
frameLength = 256; % Length of each frame (in samples)
frameShift = 128; % Frame shift (in samples)
numFilters = 26; % Number of Mel filterbank filters
numCoeffs = 13; % Number of MFCC coefficients to keep
fftSize = 512; % Size of FFT (next power of 2)

% Step 1: Pre-emphasis (high-pass filter)
preEmphasis = 0.97;
audioData = filter([1, -preEmphasis], 1, audioData);

% Step 2: Framing
numFrames = floor((length(audioData) - frameLength) / frameShift) + 1;
frames = zeros(frameLength, numFrames);

for i = 1:numFrames
    startIdx = (i - 1) * frameShift + 1;
    endIdx = startIdx + frameLength - 1;
    frames(:, i) = audioData(startIdx:endIdx);
end

% Step 3: Apply Hamming window
window = hamming(frameLength);
frames = frames .* repmat(window, 1, numFrames);

% Step 4: Fourier Transform and Magnitude Spectrum
magnitudeSpectrum = abs(fft(frames, fftSize));

% Step 5: Mel Filterbank
lowFreq = 0; % Lower frequency limit of the Mel scale
highFreq = fs / 2; % Upper frequency limit (Nyquist frequency)

% Create Mel filterbank
melFilters = melFilterbank(lowFreq, highFreq, numFilters, fftSize, fs);

% Apply Mel filterbank to the magnitude spectrum
melSpectrum = melFilters * magnitudeSpectrum(1:fftSize/2, :);

% Step 6: Logarithmic compression
melSpectrum = log(melSpectrum + eps); % Add eps to avoid log(0)

% Step 7: Discrete Cosine Transform (DCT)
mfccFeatures = dct(melSpectrum);

% Keep the first 'numCoeffs' MFCC coefficients
mfccFeatures = mfccFeatures(1:numCoeffs, :);

% Step 8: Plot MFCC features
figure;
imagesc(mfccFeatures);
axis xy;
colorbar;
xlabel('Frame Index');
ylabel('MFCC Coefficients');
title('MFCC Feature Extraction');

% Mel filterbank function
function melFilters = melFilterbank(lowFreq, highFreq, numFilters, fftSize, fs)
    % Convert frequency limits to Mel scale
    lowMel = hz2mel(lowFreq);
    highMel = hz2mel(highFreq);

    % Create Mel-spaced points
    melPoints = linspace(lowMel, highMel, numFilters + 2);

    % Convert Mel points back to Hz
    freqPoints = mel2hz(melPoints);

    % Convert Hz to FFT bin indices
    bin = floor((fftSize + 1) * freqPoints / fs);

    % Ensure bin indices are valid (positive integers and within range)
    bin = max(1, bin); % Ensure bin indices are at least 1
    bin = min(fftSize/2, bin); % Ensure bin indices do not exceed fftSize/2

    % Initialize Mel filterbank
    melFilters = zeros(numFilters, fftSize / 2);

    % Create triangular filters
    for m = 1:numFilters
        filterStart = bin(m);
        filterPeak = bin(m + 1);
        filterEnd = bin(m + 2);

        % Rising slope
        melFilters(m, filterStart:filterPeak) = ...
            linspace(0, 1, filterPeak - filterStart + 1);

        % Falling slope
        melFilters(m, filterPeak:filterEnd) = ...
            linspace(1, 0, filterEnd - filterPeak + 1);
    end
end

% Mel to Hz conversion
function mel = hz2mel(hz)
    mel = 1127 * log(1 + hz / 700);
end

% Hz to Mel conversion
function hz = mel2hz(mel)
    hz = 700 * (exp(mel / 1127) - 1);
end