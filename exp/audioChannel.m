function [recordedaudio, perf] = audioChannel(varargin)

%% Function for passing audio through (duplex mode) with PsychPortAudio
%
% USAGE: [recordedaudio, perf] = audioChannel(devName='MAYA22 USB', lat=0.1, maxLength=150)
%
% Based on DelayedSoundFeedbackDemo of Psychtoolbox.
%
% Function for testing Psychtoolbox's PsychPortAudio for duplex mode audio with
% the sound cards in the lab. 
% The function openes an audio device in recording + playback mode and tries
% to push the input out with "lat" latency. Builds heavily upon PsychDemos
% examples. 
%
% Aborts for "q".
%
% Inputs:
% devName       - Char array, name of the audio device to use. Defaults to
%                       'MAYA22 USB', that is, the current USB sound cards in the lab.
% lat           - Numeric value, requested latency in seconds. PsychPortAudio
%                       will complain if it thinks the latency is too short. Defaults to 
%                       0.1 sec. Should be in range [0 10]
% maxLength     - Numeric value, maximum time of audio device operation in
%                       seconds. Function aborts when "maxLength" is reached. Defaults
%                       to 150 secs. Should be in range ]10 11000]
%
% Outputs:
% perf                 - Struct, storing various performance-related variables. 
%
%


%% Input checks

% sort varargs
if ~isempty(varargin)
    for v = 1:length(varargin)
        if ischar(varargin{v}) && ~exist('devName', 'var')
            devName = varargin{v};
        elseif isnumeric(varargin{v}) && varargin{v} >= 0 && varargin{v} <= 10 && ~exist('lat', 'var')
            lat = varargin{v};
        elseif isnumeric(varargin{v}) && varargin{v} > 10 && varargin{v} <=11000 && ~exist('maxLength', 'var')
            maxLength = varargin{v};
        else
            error('At least one input arg to function audioChannel could not be matched with its expected args ("devName", "lat" and "maxLength")!');
        endif
    endfor
endif
% define defaults
if ~exist('devName', 'var')
    devName = 'MAYA22 USB';
end
if ~exist('lat', 'var')
    lat = 0.1;
end
if ~exist('maxLength', 'var')
    maxLength = 150;
end

disp([char(10), 'Called audioChannel with input args: ',...
    char(10), 'Device name: ', devName, ...
    char(10), 'Latency: ', num2str(lat), ' secs', ...
    char(10), 'Maximum length: ', num2str(maxLength), ' secs']);
    
    
%% Basic settings, params

% store diagnostic timestamps in a huge array:
tc = 0;
tstats = zeros(7, 1000000);  % with a captureQuantum of  ~3 ms, this is enough for ~50 mins

% PsychPortAudio device and other options
mode = 3;  % recording + playback
reqLatencyClass = 1;  % KEEP AT A MAXIMUM OF 2! Controls how strongly PsychPortAudio should push for control and low latency, settings 3 and 4 break things regularly
nrChannels = 2;  % number of channels
fs = 44100;  % sampling rate in Hz
headroom = 4;  % multiplicator for minimal buffer size 


%% Psychtoolbox / PsychPortAudio setup

try

    PsychDefaultSetup(1);
    Priority(50);
    InitializePsychSound(1);
    % Force costly mex functions into memory to avoid latency later on
    GetSecs; WaitSecs(0.1); KbCheck();


    % get correct audio device
    % fall back to system default if the requested device is not found
    device = [];  % empty means default
    tmpDevices = PsychPortAudio('GetDevices');
    for i = 1:numel(tmpDevices)
        if strncmp(tmpDevices(i).DeviceName, devName, length(devName))
            device = tmpDevices(i).DeviceIndex;
        endif
    endfor
    % error out if system default was selected, not the target device
    if isempty(device)
        Priority(0);
        error(['Requested device (', devName, ') was not found!']);
    endif

    % open PsychPortAudio device 
    pahandle = PsychPortAudio('Open', device, mode, reqLatencyClass, fs, nrChannels);

    % get and display device status
    s = PsychPortAudio('GetStatus', pahandle);
    disp([char(10), 'PsychPortAudio device status: ']);
    disp(s);

    % check selected frequency
    if s.SampleRate ~= fs
        fs = s.SampleRate;
        warning(['Sampling rate overriden by audio device, sampling rate is ', num2str(fs)]);
    endif
    
    % preallocate audio data var, for two channels
    recordedaudio = zeros(2, (maxLength+3)*fs);
    recAudioCounter = 0;  % counter for recorded samples used later    
    
       
    %% Test the performance if audio device with requested latency
    
    % Preallocate an internal audio recording  buffer with a capacity of at least
    % 10 seconds, possibly more if requested lat'ency is higher:
    PsychPortAudio('GetAudioData', pahandle, max(2 * lat, 10));    
    fprintf('\nAllocated internal audio buffer for recording\n');
    
    % Allocate a zero-filled (ie. silence) output audio buffer of more than
    % sufficient size: Three times the requested latency, but at least 30 seconds.
    % One could do this more clever, but this is a safe no-brainer and memory
    % is cheap:
    outbuffersize = floor(fs * 3 * max(lat, 10));
    PsychPortAudio('FillBuffer', pahandle, zeros(2, outbuffersize));    
    fprintf('\nAllocated zero-filled audio buffer for playback\n');
    
    % start audio playback right away
    playbackstart = PsychPortAudio('Start', pahandle, 0, 0, 1);
    fprintf('\nStarted playback successfully\n');

    % This flag will indicate failure to achieve the wanted sound onset timing
    % / latency. An experiment script would abort or reject a trial with a
    % non-zero timingfailed flag:
    timingfailed = 0;    
    
    % Wait until at least captureQuantum seconds of sound are available from the capture
    % device and then quickly fetch it from the capture device. captureQuantum
    % is the minimum amount of sound data that the driver can capture. If you'd
    % ask for less you'd get at least this amount anyway + possibly extra
    % delays:
    s = PsychPortAudio('GetStatus', pahandle);
    captureQuantum = headroom * (s.BufferSize / s.SampleRate);
    fprintf('CaptureQuantum (Duty cycle length) is %f msecs, for a buffersize of %i samples.\n', captureQuantum * 1000, s.BufferSize);
    [audiodata offset overflow capturestart] = PsychPortAudio('GetAudioData', pahandle, [], captureQuantum);

    % Sanity check returned values: audiodata should be at least headroom * s.BufferSize
    % samples, offset should be zero as this is the first 'GetAudioData' call
    % since 'Start' of capture. overflow should be zero, otherwise we screwed
    % up our timing already in the first few milliseconds because the system is
    % not up to the task / overloaded for the requested latency settings.
    % 'capturestart' contains the estimated time when the first returned audio
    % sample hit the microphone / line-in connector:
    if (size(audiodata, 2) < headroom * s.BufferSize) || (offset~=0) || (overflow > 0)
      fprintf('WARNING: SOUND ONSET TIMING SCREWED!! THE SYSTEM IS NOT UP TO THE TASK/OVERLOADED!\n');
      fprintf('Realsize samples %i < Expected size %i? Or offset %i ~= 0 ? Or overflow %i > 0 ?\n', size(audiodata, 2), headroom * s.BufferSize, offset, overflow);
      timingfailed = 1;
    endif

    % Ok, we have our initial batch of audio samples in 'audiodata', recorded
    % at time 'capturestart'. The sound output is currently feeding zeroes
    % (=silence) from the zero-filled output buffer to the speakers and the
    % first zero-sample in that buffer will hit the speakers at time
    % 'playbackstart'. We now need to copy our 'audiodata' batch of samples
    % into the output buffer, but at an offset from the start that is selected
    % to exactly achieve output of our first 'audiodata' sample at the
    % requested latency.
    %
    % The first sample was captured at time 'capturestart' and the requested
    % latency for output is 'lat': Therefore the wanted playback time for this
    % first sample is...
    reqonsettime = capturestart + lat;

    % Sanity check: Are we ahead of the playback stream with our requested
    % onset time of reqonsettime? If not, then the system won't be able to
    % achieve the requested audioLatency and we'll be late!
    s = PsychPortAudio('GetStatus', pahandle);
    if s.CurrentStreamTime > reqonsettime
      fprintf('WARNING: SOUND ONSET TIMING SCREWED!! THE SYSTEM IS NOT UP TO THE TASK/OVERLOADED!\n');
      fprintf(['Requested onset at time %f seconds, but audio stream is already at time %f seconds\n--> ' ...
      'We will be at least %f msecs too late!\n'], reqonsettime, s.CurrentStreamTime, 1000 * (s.CurrentStreamTime - reqonsettime));
      timingfailed = 2;
    endif

    % The first sample from the output buffer will playback at time
    % 'playbackstart', therefore our first sample should be placed at a
    % timeoffset relative to the start of the outputbuffer of...
    reqtimeoffset = reqonsettime - playbackstart;

    % Our first audio sample needs to be placed at a time offset of
    % 'reqtimeoffset' in the audio output buffer, overwriting the "silence"
    % there. Map offset in seconds to offset in samples: The system plays out
    % s.SampleRate samples per second, so we need to place our audio at an
    % offset of...
    reqsampleoffset = round(reqtimeoffset * s.SampleRate);

    if reqsampleoffset < 0
      fprintf('If sound feedback works at all, then extra latency will be at least %f msecs, probably more!\n', 1000 * abs(reqtimeoffset));    
    endif

    % Make sure the offset is positive, ie at least zero:
    reqsampleoffset = max(reqsampleoffset, 0);

    % Overwrite the output buffer with our captured audiodata, starting at
    % sample index 'reqsampleoffset'. Need to set the 'streamingrefill' flag to
    % 1 in order to enable this special overwrite mode. The 'underflow' flag
    % will tell us if we made the refill in time, or if we "missed the train"
    % in the last microsecond: A non-zero value means we missed.
    [underflow, nextSampleStartIndex, nextSampleETASecs] = PsychPortAudio('FillBuffer', pahandle, audiodata, 1, reqsampleoffset);

    s = PsychPortAudio('GetStatus', pahandle);
    if underflow > 0
      fprintf('WARNING: SOUND ONSET TIMING SCREWED!! THE SYSTEM IS NOT UP TO THE TASK/OVERLOADED!\n');
      fprintf(['Requested onset at time %f seconds, but audio stream is already at time %f seconds\n--> ' ...
      'We will lose at least the first %f msecs of the sound signal!\n'], reqonsettime, s.CurrentStreamTime, 1000 * (s.CurrentStreamTime - reqonsettime));
      timingfailed = 3;
    endif

    % Ok, if we made it until here without a non-zero 'timingfailed' flag, then
    % at least the first few milliseconds of captured sound should play at
    % exactly the desired 'lat'ency between capture and playback.

    % From now on we'll just need to periodically fetch chunks of audio data
    % from the capture device and feed it into the output device without any
    % complex math or tricks involved. However in order to avoid dropouts and
    % other audible artifacts we need to make sure that we feed new data fast
    % enough. We will now execute a loop that tries to fetch audio in the
    % smallest possible quantity from the capturedevice, then immediately
    % append it to the output buffer:
    updateQuantum = headroom * s.BufferSize / s.SampleRate;
    captureQuantum = updateQuantum;

    % Get current status of outputdevice:
    s = PsychPortAudio('GetStatus', pahandle);

    oldcaptureQuantum = -1;
    cumoverrun   = 0;
    cumunderflow = 0;
    xruns = 0;

    %% Audio fetch + push loop

    startTime = GetSecs;
    firstFrameTiming = 0;
    while GetSecs < startTime + maxLength
        
        % check for abort
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown && keyCode(KbName('q'))
            disp([char(10), 'User requested abort...']);
            break;
        endif

##        % Try to dynamically adapt the amount of sound data that needs to be
##        % fetched in each loop iteration. We fetch and process in larger chunks
##        % if we have enough headroom. Fetching in larger 'captureQuantum'
##        % chunks allows the driver to "sleep" for a few milliseconds between
##        % iterations within 'GetAudioData', thereby reducing the load on the
##        % operating system and cpu. This is mostly needed on MS-Windows with
##        % its highly deficient scheduling and timing systems:
##        s = PsychPortAudio('GetStatus', pahandle);
##        captureQuantum = headroom * (s.BufferSize / s.SampleRate);
##
##        if captureQuantum ~= oldcaptureQuantum
##            oldcaptureQuantum = captureQuantum;
##            fprintf('Duty cycle adapted to %f msecs...\n', 1000 * captureQuantum);
##        endif

        % Get new captured sound data ...
        fetchDelay = GetSecs;
        [audiodata, offset, overrun, cstarttime] = PsychPortAudio('GetAudioData', pahandle, [], captureQuantum);
        if firstFrameTiming == 0
            firstFrameTiming = cstarttime;
        endif
        fetchDelay = GetSecs - fetchDelay;
    
        % store audio
        recordedaudio(:, recAudioCounter+1:recAudioCounter+size(audiodata,2)) = audiodata;
        recAudioCounter = recAudioCounter + size(audiodata, 2);    
    
        % ... and stream it into our output buffer:
        while size(audiodata, 2) > 0
            % Make sure to never push more data in the buffer than it can
            % actually hold, ie not more than half its maximum capacity:
            fetch = min(size(audiodata, 2), floor(outbuffersize / 2));
            % We feed data in chunks of 'fetch' samples:
            pushdata = audiodata(:, 1:fetch);
            % audiodata is the remainder which will be pushed in the next loop
            % iteration:
            audiodata = audiodata(:, fetch+1:end);

            % Perform streaming buffer refill. As long as we don't push more
            % than a buffer size, the driver will take care of the rest...
            [curunderflow, nextSampleStartIndex, nextSampleETASecs] = PsychPortAudio('FillBuffer', pahandle, pushdata, 1);
        endwhile

        % Check for xrun conditions from low-level sound hardware:
        s1 = PsychPortAudio('GetStatus', pahandle);
        xruns = xruns + s1.XRuns;

        % Any dropouts or other audible artifacts?
        if ((overrun + curunderflow + xruns) > 0) && (timingfailed == 0)
            fprintf('WARNING: SOUND DROPOUTS! THE SYSTEM IS NOT UP TO THE TASK/OVERLOADED!\n');
            fprintf('Run %i: Overruns of capture buffer: %i. Underruns of audio output buffer: %i. Hardware xruns = %i\n', tc, overrun, curunderflow, xruns);
            timingfailed = 4;
        endif   
        
        % accumulate overrun / underflow events
        cumoverrun = cumoverrun + overrun;
        cumunderflow = cumunderflow + curunderflow;        
        
        % Log some timing samples:
        tc = tc + 1;
        if tc <= size(tstats, 2)
            tstats(:, tc) = [ s1.ElapsedOutSamples ; s1.CurrentStreamTime ; fetchDelay; nextSampleETASecs - s1.CurrentStreamTime; offset; cstarttime; GetSecs];
        endif        
        
        % Done. Next iteration...

    endwhile  % while    
    
    % Stop, drain and close audio device
    PsychPortAudio('Stop', pahandle);
    PsychPortAudio('GetAudioData', pahandle);
    PsychPortAudio('Close', pahandle);
    Priority(0);

    if timingfailed > 0
        % There was trouble during execution
        fprintf('There were timingproblems or audio dropouts during the demo [Condition %i]!\nYour system is not capable of reliable operation at a\n', timingfailed);
        fprintf('requested roundtrip feedback latency of %f msecs.\n\n', 1000 * lat);
        fprintf('\nOverruns of capture buffer: %i. Underruns of audio output buffer: %i. Hardware xruns = %i\n', cumoverrun, cumunderflow, xruns);
    else
        fprintf('Requested roundtrip feedback latency of %f msecs seems to have worked. Please double-check with external equipment.\n\n', 1000 * lat);
    endif

    % Prune recorded audio
    if recAudioCounter < size(recordedaudio, 2)
        recordedaudio(:, recAudioCounter+1:end) = [];
    endif
    
    % Prune tstats to valid range:
    fprintf('Total of %i timesamples.\n', tc);
    tstats = tstats(:, 1:tc);
##    tstats(2,:) = tstats(2,:) - tstats(2,1);
##    tstats(1,:) = tstats(1,:) - tstats(1,1);
##    [tout(1,:), idx] = unique(tstats(1,:));
##    tout(2:4,:) = tstats(2:4,idx);
##    tstats = tout;    
    
    % Collect various performance-related flags / vars into a struct
    perf = struct;
    perf.tstats = tstats;
    perf.tc = tc;
    perf.timingfailed = timingfailed;
    perf.cumoverrun = cumoverrun;
    perf.cumunderflow = cumunderflow;
    perf.xruns = xruns;
    perf.playbackstart = playbackstart;
    perf.capturestart = capturestart;
    perf.offset = offset;
    perf.reqonsettime = reqonsettime;
    perf.firstFrameTiming = firstFrameTiming;
    
    % Done!
    disp([char(10), 'Done, closing shop']);
    
    
catch ME
    
    disp([char(10), char(10), 'Oops, stg went wrong!', char(10), char(10)]);

    % clean up audio device if it exists at this point
    if exist('pahandle', 'var')
        PsychPortAudio('Stop', pahandle);
        PsychPortAudio('GetAudioData', pahandle);
        PsychPortAudio('Close', pahandle);
    endif
    
    sca;
    Priority(0);
    rethrow(ME);
    
    
end  % try


endfunction

