function onsets = toneTimingTest(eventNo, period, ttl)

%% Function for testing audio tone onset timing
%
% USAGE: onsets = toneTimingTest(eventNo, period, ttl)
%
% The function plays short tones "eventNo" times, with "period" interval 
% between subsequent ones. Tones are accompanied by a TTL-type trigger.
% Tones are 50 ms long and are composed of a 1000 Hz beep.
%
% Inputs:
% eventNo       - Numeric value, integer in range 1:10^4. Number of flashes 
%                   and corresponding triggers
% period        - Numeric value, interval between events in secs. Should be 
%                   between 0.1 and 10. 
% ttl               - Char array, one of {'ttl', 'nottl'}. Controlr if TTL triggers are used
%                   or not.
%
% Outputs:
% onsets        - Numeric vector, contains the onset timestamps for tones, as 
%                   reported by PsychPortAudio('Start').
%
%


%% Input checks

if nargin ~= 3
    error('Function toneTimingTest requires inputs "eventNo", "period" and "ttl"!');
endif
if ~ismember(eventNo, 1:10^4)
    error('Input arg "eventNo" should be an integer value in range 1:10^4!');
endif
if ~isnumeric(period) || period < 0.1 || period > 10
    error('Input arg "period" should be between 0.1 and 10!');
endif
if ~ischar(ttl) || ~ismember(ttl, {'ttl', 'nottl'})
    error('Input arg "ttl" should be one of {"ttl", "nottl"}!');
endif

if strcmp(ttl, 'ttl')
    ttlFlag = true;
else
    ttlFlag = false;
endif

disp([char(10), 'Called toneTimingTest with input args: ', ...
    char(10), 'Event number: ', num2str(eventNo), ...
    char(10), 'Period: ', num2str(period), ' secs.', ...
    char(10), 'Triggers: ', num2str(ttlFlag)]);


%% Generate sine wave for beep

fs = 44100;  % sampling in Hz
dt = 1/fs;  % seconds per sample
beepLength = 0.050;  % sec
t = (0:dt:beepLength-dt)'; % time vector
beepF = 1000;  % beep freq, Hz
beepSine = sin(2*pi*beepF*t);  % column vector
% onset and offset ramp
rampSamples = fs * 0.01;  % no. of samples in ramp
onsetRamp = sin(linspace(0, 1, rampSamples) * pi / 2);
onsetOffsetRamp = [onsetRamp, ones(1, fs * beepLength - 2*rampSamples), fliplr(onsetRamp)]';  % column vector
% adjust beep with ramp
audioStim = beepSine .* onsetOffsetRamp;  % column vector
audioStim = [audioStim'; audioStim'];  % two rows from same vector for stereo


%% Trigger setup

if ttlFlag
    triggerL = 2000;  % trigger length in microseconds
    triggerVal = 10;  % trigger value
    % init parallel port control
    ppdev_mex('Open', 1);
endif


%% PsychPortAudio setup

PsychDefaultSetup(1);
Priority(1);
InitializePsychSound(1);

% get correct audio device
%% we only change audio device in the lab, when we see the correct audio
device = [];  % system default is our default as well
tmpDevices = PsychPortAudio('GetDevices');
% get card
targetDev = 'samplerate';
%targetDev = 'HDA Intel PCH: ALC3246 Analog';
%targetDev = 'MAYA22 USB';
for i = 1:numel(tmpDevices)
    if strncmp(tmpDevices(i).DeviceName, targetDev, length(targetDev))
        device = tmpDevices(i).DeviceIndex;
    end
end

% mode is simple playback
mode = 1;
% reqlatencyclass is set to low-latency
reqLatencyClass = 2;
% 2 channels output
nrChannels = 2;

% open PsychPortAudio device for playback
pahandle = PsychPortAudio('Open', device, mode, reqLatencyClass, fs, nrChannels);

% get and display device status
pahandleStatus = PsychPortAudio('GetStatus', pahandle);
disp([char(10), 'PsychPortAudio device status: ']);
disp(pahandleStatus);

% initial start & stop of audio device to avoid potential initial latencies
tmpSound = zeros(2, fs/10);  % silence
tmpBuffer = PsychPortAudio('CreateBuffer', pahandle, tmpSound);  % create buffer
PsychPortAudio('FillBuffer', pahandle, tmpBuffer);  % fill the buffer of audio device with silence
PsychPortAudio('Start', pahandle, 1);  % start immediately
PsychPortAudio('Stop', pahandle, 1);  % stop when playback is over

% create buffer for stimulus
stimBuffer = PsychPortAudio('CreateBuffer', pahandle, audioStim);

% Force costly mex functions into memory to avoid latency later on
GetSecs; WaitSecs(0.1); KbCheck();


%% Audio stimuli loop

onsets = zeros(eventNo, 1);

disp([char(10), 'Starting in 3 secs...']);
startTime = GetSecs + 3;

for eventIdx = 1:eventNo

        % fill audio buffer
        PsychPortAudio('FillBuffer', pahandle, stimBuffer);

        % blocking playback start for precision
        onsets(eventIdx) = PsychPortAudio('Start', pahandle, 1, startTime, 1);
        if ttlFlag
            lptwrite(1, triggerVal, triggerL);
        endif

        % adjust stimulus start time
        startTime = onsets(eventIdx) + period;

endfor


%% cleanup

if ttlFlag
    ppdev_mex('Close', 1);
endif
Priority(0);
PsychPortAudio('Close', pahandle);




endfunction
