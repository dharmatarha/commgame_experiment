function audioDuplex(devName, lat)

%% Function for passing audio through (duplex mode) with PsychPortAudio
%
% USAGE: perf = audioDuplex(devName='MAYA22 USB', lat=0.1)
%
% Function for testing Psychtoolbox's PsychPortAudio for duplex mode audio with
% the sound cards in the lab. 
% The function openes an audio device in recording + playback mode and tries
% to push the input out with "lat" latency. Builds heavily upon PsychDemos
% examples. 
%
% Inputs:
% devName       - Char array, name of the audio device to use. Defaults to
%                       'MAYA22 USB', that is, the current USB sound cards in the lab.
% lat                   - Numeric value, requested latency in seconds. PsychPortAudio
%                       will complain if it thinks the latency is too short. Defaults to 
%                       0.1 sec.
%
% Outputs:
% perf                 - Struct, storing various performance-related variables. 
%
%















endfunction









%function onsets = toneTimingTest(eventNo, period)
%
%%% Function for testing microphone - playback loop latency
%%
%% USAGE: onsets = toneTimingTestDouble(eventNo, period)
%%
%% The function does two things:
%% (1) It plays short tones "eventNo" times, with "period" interval between
%% subsequent ones. Tones are accompanied by a TTL-type trigger. Tones
%% are 50 ms long and are composed of a 1000 Hz beep.
%% (2) It records and plays back from a microphone, using a secondary
%% audio device.
%%
%% Combine the usage of this script with an independent audio onset
%% measuring device (e.g. StimTrak from Brain Products). If the
%% measurement device is set to respond to the output from the primary
%% device, it tests the reliability of stimulus onset relative to the TTL trigger.
%% If it is set to respond to the secondary output, it measures the latency of
%% the microphone - playback loop (after adjusting with initial playback
%% delay).
%%
%% Inputs:
%% eventNo       - Numeric value, integer in range 1:10^4. Number of flashes 
%%               and corresponding triggers
%% period        - Numeric value, interval between events in secs. Should be 
%%               between 0.1 and 10. 
%%
%% Outputs:
%% onsets        - Numeric vector, contains the onset timestamps for tones, as 
%%               reported by PsychPortAudio('Start').
%%
%%
%
%
%%% Input checks
%
%if nargin ~= 2
%    error('Function toneTimingTest requires inputs "eventNo" and "period"!');
%endif
%if ~ismember(eventNo, 1:10^4)
%    error('Input arg "eventNo" should be an integer value in range 1:10^4!');
%endif
%if ~isnumeric(period) || period < 0.1 || period > 10
%    error('Input arg "period" should be between 0.1 and 10!');
%endif
%
%disp([char(10), 'Called toneTimingTest with input args: ', ...
%    char(10), 'Event number: ', num2str(eventNo), ...
%    char(10), 'Period: ', num2str(period), ' secs.']);
%
%
%%% Generate sine wave for beep
%
%fs = 44100;  % sampling in Hz
%dt = 1/fs;  % seconds per sample
%beepLength = 0.050;  % sec
%t = (0:dt:beepLength-dt)'; % time vector
%beepF = 1000;  % beep freq, Hz
%beepSine = sin(2*pi*beepF*t);  % column vector
%% onset and offset ramp
%rampSamples = fs * 0.01;  % no. of samples in ramp
%onsetRamp = sin(linspace(0, 1, rampSamples) * pi / 2);
%onsetOffsetRamp = [onsetRamp, ones(1, fs * beepLength - 2*rampSamples), fliplr(onsetRamp)]';  % column vector
%% adjust beep with ramp
%audioStim = beepSine .* onsetOffsetRamp;  % column vector
%audioStim = [audioStim'; audioStim'];  % two rows from same vector for stereo
%
%
%%% Trigger setup
%
%triggerL = 2000;  % trigger length in microseconds
%triggerVal = 10;  % trigger value
%% init parallel port control
%ppdev_mex('Open', 1);
%
%
%%% PsychPortAudio setup
%
%PsychDefaultSetup(1);
%Priority(1);
%% Force costly mex functions into memory to avoid latency later on
%GetSecs; WaitSecs(0.1); KbCheck();
%
%% get correct audio devices
%% change these for your setup
%primaryDev = 'samplerate';  % used for stimulus playback
%secondaryDev = 'MAYA22 USB';  % used for  separate microphone - playback loop
%devIdx = nan(2, 1);  % device indices vector
%
%% iterate over detected devices, set device indices
%tmpDevices = PsychPortAudio('GetDevices');
%for i = 1:numel(tmpDevices)
%    % check for primary and secondary device
%    if strncmp(tmpDevices(i).DeviceName, primaryDev, length(primaryDev))
%        devIdx(1) = tmpDevices(i).DeviceIndex;
%     elseif strncmp(tmpDevices(i).DeviceName, secondaryDev, length(secondaryDev))
%        devIdx(2) = tmpDevices(i).DeviceIndex;
%    end
%end
%% check if devices were found
%if any(isnan(devIdx))
%    error(['Could not find a specified audio device: ',...
%        char(10), 'detected ids were ', num2str(devIdx(1)), ' ', num2str(devIdx(2))]);
%end
%
%
%%% Set up primary device
%
%% mode is simple playback
%primMode = 1;
%% reqlatencyclass is set to low-latency
%primReqLatencyClass = 2;
%% 2 channels output
%primNrChannels = 2;
%
%% open PsychPortAudio device for playback
%primPahandle = PsychPortAudio('Open', devIdx(1), primMode, primReqLatencyClass, fs, primNrChannels);
%
%% get and display device status
%primPahandleStatus = PsychPortAudio('GetStatus', primPahandle);
%disp([char(10), 'PsychPortAudio device status: ']);
%disp(primPahandleStatus);
%
%% initial start & stop of audio device to avoid potential initial latencies
%tmpSound = zeros(2, fs/10);  % silence
%tmpBuffer = PsychPortAudio('CreateBuffer', primPahandle, tmpSound);  % create buffer
%PsychPortAudio('FillBuffer', primPahandle, tmpBuffer);  % fill the buffer of audio device with silence
%PsychPortAudio('Start', primPahandle, 1);  % start immediately
%PsychPortAudio('Stop', primPahandle, 1);  % stop when playback is over
%
%% create buffer for stimulus
%stimBuffer = PsychPortAudio('CreateBuffer', primPahandle, audioStim);
%
%
%%% Set up secondary device
%
%% maximum playback length, with lots of extra space
%maxLength = eventNo*period + 20;
%% preallocate audio data var, for two channels
%recordedaudio = zeros(2, maxLength*fs);
%recAudioCounter = 0;
%
%% mode is simple playback
%secMode = 3;
%% reqlatencyclass is set to low-latency
%secReqLatencyClass = 2;
%% 2 channels output
%secNrChannels = 2;
%% intended latency for audio recording - playback loop, in secs
%audioLatency = 0.025;
%
%% open PsychPortAudio device for playback
%secPahandle = PsychPortAudio('Open', devIdx(2), secMode, secReqLatencyClass, fs, secNrChannels);
%%secPahandle = PsychPortAudio('Open', [], secMode, secReqLatencyClass, fs, secNrChannels);
%
%% get and display device status
%secPahandleStatus = PsychPortAudio('GetStatus', secPahandle);
%disp([char(10), 'PsychPortAudio device status: ']);
%disp(secPahandleStatus);
%
%
%%% Init secondary device and test its performance with requested latency
%
%% Preallocate an internal audio recording  buffer with a capacity of at least
%% 10 seconds, possibly more if requested latency is higher:
%PsychPortAudio('GetAudioData', secPahandle, max(2 * audioLatency, 10));
%
%% Allocate a zero-filled (ie. silence) output audio buffer of more than
%% sufficient size: Three times the requested latency, but at least 30 seconds.
%% One could do this more clever, but this is a safe no-brainer and memory
%% is cheap:
%outbuffersize = floor(fs * 3 * max(audioLatency, 10));
%PsychPortAudio('FillBuffer', secPahandle, zeros(2, outbuffersize));    
%
%% start audio playback right away
%playbackstart = PsychPortAudio('Start', secPahandle, 0, [], 1);
%
%% Wait until at least captureQuantum seconds of sound are available from the capture
%% device and then quickly fetch it from the capture device. captureQuantum
%% is the minimum amount of sound data that the driver can capture. If you'd
%% ask for less you'd get at least this amount anyway + possibly extra
%% delays:
%s2 = PsychPortAudio('GetStatus', secPahandle);
%headroom = 10;
%headroom = round(headroom);
%captureQuantum = headroom * (s.BufferSize / s.SampleRate);
%fprintf('CaptureQuantum (Duty cycle length) is %f msecs, for a buffersize of %i samples.\n', captureQuantum * 1000, s.BufferSize);
%[audiodata offset overflow capturestart] = PsychPortAudio('GetAudioData', secPahandle, [], captureQuantum);
%
%% Sanity check returned values: audiodata should be at least headroom * s.BufferSize
%% samples, offset should be zero as this is the first 'GetAudioData' call
%% since 'Start' of capture. overflow should be zero, otherwise we screwed
%% up our timing already in the first few milliseconds because the system is
%% not up to the task / overloaded for the requested latency settings.
%% 'capturestart' contains the estimated time when the first returned audio
%% sample hit the microphone / line-in connector:
%if (size(audiodata, 2) < headroom * s.BufferSize) || (offset~=0) || (overflow > 0)
%  fprintf('WARNING: SOUND ONSET TIMING SCREWED!! THE SYSTEM IS NOT UP TO THE TASK/OVERLOADED!\n');
%  fprintf('Realsize samples %i < Expected size %i? Or offset %i ~= 0 ? Or overflow %i > 0 ?\n', size(audiodata, 2), headroom * s.BufferSize, offset, overflow);
%  timingfailed = 1;
%end
%
%% Ok, we have our initial batch of audio samples in 'audiodata', recorded
%% at time 'capturestart'. The sound output is currently feeding zeroes
%% (=silence) from the zero-filled output buffer to the speakers and the
%% first zero-sample in that buffer will hit the speakers at time
%% 'playbackstart'. We now need to copy our 'audiodata' batch of samples
%% into the output buffer, but at an offset from the start that is selected
%% to exactly achieve output of our first 'audiodata' sample at the
%% requested latency.
%%
%% The first sample was captured at time 'capturestart' and the requested
%% latency for output is 'lat': Therefore the wanted playback time for this
%% first sample is...
%reqonsettime = capturestart + audioLatency;
%
%% Sanity check: Are we ahead of the playback stream with our requested
%% onset time of reqonsettime? If not, then the system won't be able to
%% achieve the requested audioLatency and we'll be late!
%s2 = PsychPortAudio('GetStatus', secPahandle);
%if s.CurrentStreamTime > reqonsettime
%  fprintf('WARNING: SOUND ONSET TIMING SCREWED!! THE SYSTEM IS NOT UP TO THE TASK/OVERLOADED!\n');
%  fprintf(['Requested onset at time %f seconds, but audio stream is already at time %f seconds\n--> ' ...
%  'We will be at least %f msecs too late!\n'], reqonsettime, s.CurrentStreamTime, 1000 * (s.CurrentStreamTime - reqonsettime));
%  timingfailed = 2;
%end
%
%% The first sample from the output buffer will playback at time
%% 'playbackstart', therefore our first sample should be placed at a
%% timeoffset relative to the start of the outputbuffer of...
%reqtimeoffset = reqonsettime - playbackstart;
%
%% Our first audio sample needs to be placed at a time offset of
%% 'reqtimeoffset' in the audio output buffer, overwriting the "silence"
%% there. Map offset in seconds to offset in samples: The system plays out
%% s.SampleRate samples per second, so we need to place our audio at an
%% offset of...
%reqsampleoffset = round(reqtimeoffset * s.SampleRate);
%
%if reqsampleoffset < 0
%  fprintf('If sound feedback works at all, then extra latency will be at least %f msecs, probably more!\n', 1000 * abs(reqtimeoffset));    
%end
%
%% Make sure the offset is positive, ie at least zero:
%reqsampleoffset = max(reqsampleoffset, 0);
%
%% Overwrite the output buffer with our captured audiodata, starting at
%% sample index 'reqsampleoffset'. Need to set the 'streamingrefill' flag to
%% 1 in order to enable this special overwrite mode. The 'underflow' flag
%% will tell us if we made the refill in time, or if we "missed the train"
%% in the last microsecond: A non-zero value means we missed.
%[underflow, nextSampleStartIndex, nextSampleETASecs] = PsychPortAudio('FillBuffer', secPahandle, audiodata, 1, reqsampleoffset);
%
%s2 = PsychPortAudio('GetStatus', secPahandle);
%if underflow > 0
%  fprintf('WARNING: SOUND ONSET TIMING SCREWED!! THE SYSTEM IS NOT UP TO THE TASK/OVERLOADED!\n');
%  fprintf(['Requested onset at time %f seconds, but audio stream is already at time %f seconds\n--> ' ...
%  'We will lose at least the first %f msecs of the sound signal!\n'], reqonsettime, s.CurrentStreamTime, 1000 * (s.CurrentStreamTime - reqonsettime));
%  timingfailed = 3;
%end
%
%% Ok, if we made it until here without a non-zero 'timingfailed' flag, then
%% at least the first few milliseconds of captured sound should play at
%% exactly the desired 'lat'ency between capture and playback.
%
%% From now on we'll just need to periodically fetch chunks of audio data
%% from the capture device and feed it into the output device without any
%% complex math or tricks involved. However in order to avoid dropouts and
%% other audible artifacts we need to make sure that we feed new data fast
%% enough. We will now execute a loop that tries to fetch audio in the
%% smallest possible quantity from the capturedevice, then immediately
%% append it to the output buffer:
%updateQuantum = s.BufferSize / s.SampleRate;
%captureQuantum = updateQuantum;
%
%% Get current status of outputdevice:
%s2 = PsychPortAudio('GetStatus', secPahandle);
%
%%    oldcaptureQuantum = -1;
%cumoverrun   = 0;
%cumunderflow = 0;
%
%
%%% Prepare stimulus onset times
%
%startTime = GetSecs;
%onsetTimes = [startTime + 1:period:(startTime + 1 + (eventNo-1)*period)]
%nextStimOnset = onsetTimes(1);
%
%%% Audio loop
%
%xruns = 0;
%eventCounter = 1;
%
%while ~KbCheck && eventCounter <= eventNo
%
%    % if the next stimulus onset time is closer than 50 ms, issue playback Start in advance
%    if GetSecs >= nextStimOnset - 0.05
%        PsychPortAudio('FillBuffer', primPahandle, stimBuffer);
%        PsychPortAudio('Start', primPahandle, 1, nextStimOnset, 0);  % schedule audio stim playback, non-blocking
%        eventCounter = eventCounter + 1;
%        nextStimOnset = onsetTimes(eventCounter);
%    end
%
%    %        captureQuantum = updateQuantum;
%
%    %        if captureQuantum ~= oldcaptureQuantum
%    %            oldcaptureQuantum = captureQuantum;
%    %                if verbose > 1
%    %                  fprintf('Duty cycle adapted to %f msecs...\n', 1000 * captureQuantum);
%    %                end
%    %        end
%
%    % Get new captured sound data...
%%        fetchDelay = GetSecs;
%    [audiodata, offset, overrun] = PsychPortAudio('GetAudioData', secPahandle, [], captureQuantum);
%%        fetchDelay = GetSecs - fetchDelay;
%    underflow = 0;
%    % ... and stream it into our output buffer:
%    curunderflow = PsychPortAudio('FillBuffer', secPahandle, audiodata, 1);
%    underflow = underflow + curunderflow;
%
%    % store audio
%    recordedaudio(:, recAudioCounter+1:recAudioCounter+size(audiodata,2)) = audiodata;
%    recAudioCounter = recAudioCounter + size(audiodata, 2);
%
%    % Check for xrun conditions from low-level sound hardware:
%    s2 = PsychPortAudio('GetStatus', secPahandle);
%    xruns = xruns + s2.XRuns;
%
%    cumoverrun = cumoverrun + overrun;
%    cumunderflow = cumunderflow + underflow;
%
%    % Done. Next iteration...
%
%end  % while
%
%% close audio devices
%PsychPortAudio('Stop', primPahandle);
%PsychPortAudio('Stop', secPahandle);
%% Drain apture buffer...
%PsychPortAudio('GetAudioData', secPahandle);
%% Done - Close device and driver:
%PsychPortAudio('Close', primPahandle);
%PsychPortAudio('Close', secPahandle);
%
%% store recorded audio in wavfile
%if recAudioCounter < size(recordedaudio, 2)
%    recordedaudio(:, recAudioCounter+1:end) = [];
%endif
%psychwavwrite(transpose(recordedaudio), fs, 16, wavfilename);
%
%% Done, report elapsed time
%telapsed = GetSecs - startTime;
%disp([char(10), 'Elapsed time: ', num2str(telapsed)]);
%
%% set priority to default, close ttl trigger port
%Priority(0);
%ppdev_mex('Close', 1);
%
%
%%% cleanup
%
%
%
%
%
%
%endfunction