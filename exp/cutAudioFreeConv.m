function cutAudioFreeConv(pairNo, localLab)
%% Function to segment the two channels of audio in the free conversation task
%
% USAGE: cutAudioFreeConv(pairNo, localLab)
%
% NEW VERSION USED FROM 2023.05.02.
% CONSIDERS UNEQUAL SAMPLING RATES
%
% In the free conversation task, participants' microphone channels are recorded
% separately at the two control PCs. Following the task, for the replay 
% condition, we need to copy and edit the audio recordings so that we have one 
% audio file containing both speech streams, synchronized to the start of the 
% video. The copy part is handled by "audioCopy.sh", this function performs 
% the editing.
% 
% Inputs:
% pairNo    - Numeric value, pair number, one of 1:99.
% localLab   - Char array, name of lab where the function is called, one of 
%           {"Mordor", "Gondor"}.
%
% The output is the edited, synched audio file.
%


%% Input checks

if nargin ~= 2
    error("Input args pairNo and localLab are required!");
end
if ~ismember(pairNo, 1:999)
    error("Input arg pairNo should be one of 1:999!");
end
if ~ismember(localLab, {"Mordor", "Gondor"})
    error("Input arg localLab should be one of Mordor / Gondor!");
end

%% Basic params

pkg load signal;

% remote lab name
if strcmp(localLab, 'Mordor')
    remoteLab = 'Gondor';
elseif strcmp(localLab, 'Gondor')
    remoteLab = 'Mordor';
end

% amount of transmission delay from remote lab (intentional, in order to match video stream, parameter of experimental scripts)
%audioDelay = 0.320;  % in secs
audioDelay = 0.190;  % this value removes the echo from the remote audio, but doesn't perfectly match the video stream

% expected sampling freq
fs = 44100;

% threshold for detecting and correcting for harmful underflows in the recordings
timeDiffThr = 0.020; 
missingSampleThr = 220;

% allowed deviation from nominal sampling frequency, in Hz
samplingTol = 0.5;

% hardcoded location for the pair folder on both local and remote PCs, only depending on the pair number
baseFolder = ['/home/mordor/CommGame/pair', num2str(pairNo), '/'];

% output path for edited / synced / corrected audio
syncedAudioF = [baseFolder, 'pair', num2str(pairNo), '_', localLab, '_freeConv_syncedAudio.wav'];

% expected path of audio files, local and remote
remoteAudioF = [baseFolder, 'pair', num2str(pairNo), '_', localLab, '_freeConv_audio.wav'];
remoteAudioTimeF = [baseFolder, 'pair', num2str(pairNo), '_', localLab, '_freeConv_audio.mat'];
localAudioF = [baseFolder, 'pair', num2str(pairNo), '_', remoteLab, '_freeConv_audio.wav'];
localAudioTimeF = [baseFolder, 'pair', num2str(pairNo), '_', remoteLab, '_freeConv_audio.mat'];

% expected path to video timestamps file
vidTimesF = [baseFolder, 'pair', num2str(pairNo), '_', localLab, '_freeConv_videoTimes.mat'];


%% Extract timestamps and load audio

% Get video length based on timestamps of first and last video flip.
% If condition was Audio Only ("Static"), there are no flip times for video frames we can use, the var is filled with NaNs 
% In that case, we rely on "elapsedTimes"
tmp = load(vidTimesF);
if all(all(isnan(tmp.flipTimestamps), 1), 2)  % if data is from Audio Only ("Static") condition
    vidLength = tmp.elapsedTime;
    vidStart = tmp.vidcaptureStartTime;
else
    vidStart = tmp.flipTimestamps(1, 1);
    vidEnd = tmp.flipTimestamps(end, 1);
    vidLength = vidEnd - vidStart;
end  % if

% timestamp of first recorded audio frame, local
tmp = load(localAudioTimeF);
localAudioStart = tmp.perf.firstFrameTiming;
localTstats = tmp.perf.tstats;
% timestamp of first recorded audio frame, remote
tmp = load(remoteAudioTimeF);
remoteAudioStart = tmp.perf.firstFrameTiming;
remoteTstats = tmp.perf.tstats;

% Correct for missing audio packets (occasional underflows) that 
% correspond to jumps in stream timings without audio data 
% First, detect "jumps", that is, audio frames where there is a 
% "large" change in streaming time from frame to frame, while the number of 
% elapsed samples does not match it.

% local
localAudioTimes = localTstats(2, :)';
localElapsedSamples = localTstats(1, :)';
localSuspectFrames = find(diff(localAudioTimes) > timeDiffThr);
% localAudioRepair = nan(length(localSuspectFrames), 2);
counter = 1;
% check each suspect audioframe for skipped material
if ~isempty(localSuspectFrames)
    for i = 1:length(localSuspectFrames)
        timingDiff = localAudioTimes(localSuspectFrames(i)+1) - localAudioTimes(localSuspectFrames(i));
        sampleDiff = localElapsedSamples(localSuspectFrames(i)+1) - localElapsedSamples(localSuspectFrames(i));
        expectedSamples = timingDiff*fs;
        if expectedSamples - sampleDiff > missingSampleThr
           localAudioRepair(counter, 1:2) = [localSuspectFrames(i), expectedSamples-sampleDiff];
           counter = counter + 1;
        end
    end
end          

% remote
remoteAudioTimes = remoteTstats(2, :)';
remoteElapsedSamples = remoteTstats(1, :)';
remoteSuspectFrames = find(diff(remoteAudioTimes) > timeDiffThr);
% remoteAudioRepair = nan(length(remoteSuspectFrames), 2);
counter = 1;
% check each suspect audioframe for skipped material
if ~isempty(remoteSuspectFrames)
    for i = 1:length(remoteSuspectFrames)
        timingDiff = remoteAudioTimes(remoteSuspectFrames(i)+1) - remoteAudioTimes(remoteSuspectFrames(i));
        sampleDiff = remoteElapsedSamples(remoteSuspectFrames(i)+1) - remoteElapsedSamples(remoteSuspectFrames(i));
        expectedSamples = timingDiff*fs;
        if expectedSamples - sampleDiff > missingSampleThr
           remoteAudioRepair(counter, 1:2) = [remoteSuspectFrames(i), expectedSamples-sampleDiff];
           counter = counter + 1;
        end
    end
end     


% load local audio
[localAudio, tmp] = audioread(localAudioF); 
if tmp ~= fs
    error(["Unexpected sampling freq (", num2str(tmp), ") in audio file at ", localAudioF ]);
end
% load remote audio
[remoteAudio, tmp] = audioread(remoteAudioF); 
if tmp ~= fs
    error(["Unexpected sampling freq (", num2str(tmp), ") in audio file at ", remoteAudioF ]);
end
% sanity check - audio recordings must have started before video stream
if localAudioStart >= vidStart || remoteAudioStart >= vidStart
    error("Insane audio versus video stream start times!");
end


%% Repair loaded audio for missing frames (underflows)

% local
if exist("localAudioRepair", "var")
    % for inserting audio samples, do it in reverse order, otherwise 
    % the indices get screwed
    for i = size(localAudioRepair, 1):-1:1
        % sample to insert silence at
        startSample = localElapsedSamples(localAudioRepair(i, 1) + 1);
        % define silence (zeros)
        silentFrame = zeros(round(localAudioRepair(i, 2)), 2);
        % special rule for inserting silent frames when those would be at the very end, 
        % potentially out of bounds of recorded audio
        if startSample > size(localAudio, 1) + 1
            localAudio = [localAudio; silentFrame];
        % otherwise we insert silent frames to their expected location
        else
            localAudio = [localAudio(1:startSample, 1:2); silentFrame; localAudio(startSample+1:end, 1:2)];
        end
    end
end

% remote
if exist("remoteAudioRepair", "var")
    % for inserting audio samples, do it in reverse order, otherwise 
    % the indices get screwed
    for i = size(remoteAudioRepair, 1):-1:1
        % sample to insert silence at
        startSample = remoteElapsedSamples(remoteAudioRepair(i, 1) + 1);
        % define silence (zeros)
        silentFrame = zeros(round(remoteAudioRepair(i, 2)), 2);
        % special rule for inserting silent frames when those would be at the very end, 
        % potentially out of bounds of recorded audio
        if startSample > size(remoteAudio, 1) + 1
            remoteAudio = [remoteAudio; silentFrame];
        % otherwise we insert silent frames to their expected location
        else
            remoteAudio = [remoteAudio(1:startSample, 1:2); silentFrame; remoteAudio(startSample+1:end, 1:2)];
        end
    end
end   


%% Estimate real (empirical) sampling frequency 

% LOCAL
% estimate sampling frequency based on the size of the (repaired) audio
% data and the total time elapsed while recording
streamTimesL = localTstats(2, :)';
totalSamplesL =size(localAudio, 1);
totalTimeL = streamTimesL(end)-streamTimesL(1);
fsEmpLocal = totalSamplesL/totalTimeL;
disp(['Estimated sampling frequency for LOCAL audio: ',... 
    num2str(fsEmpLocal), ' Hz']);

% REMOTE
streamTimesR = remoteTstats(2, :)';
totalSamplesR =size(remoteAudio, 1);
totalTimeR = streamTimesR(end)-streamTimesR(1);
fsEmpRemote = totalSamplesR/totalTimeR;
disp(['Estimated sampling frequency for REMOTE audio: ',... 
    num2str(fsEmpRemote), ' Hz']);


%% Resample audio channels, if needed

% LOCAL
if abs(fsEmpLocal - fs) > samplingTol
    % tx = 0:1/fsEmpLocal:totalTimeL;
    data = localAudio;
    % if numel(tx) ~= size(data, 1)
    %     tx = tx(1:size(data, 1));
    % end
    newFs = fs;
    resampledLocalAudio = resample(data, newFs, round(fsEmpLocal));
    % resampledLocalAudio = resample(data, tx, newFs);  % only works in Matlab
    disp(['Resampled LOCAL audio to nominal (', num2str(fs),... 
        ' Hz) sampling frequency']);
    localAudio = resampledLocalAudio;
end

% REMOTE
if abs(fsEmpRemote - fs) > samplingTol
    % tx = 0:1/fsEmpRemote:totalTimeR;
    data = remoteAudio;
    % if numel(tx) ~= size(data, 1)
    %     tx = tx(1:size(data, 1));
    % end
    newFs = fs;
    resampledRemoteAudio = resample(data, newFs, round(fsEmpRemote));
    % resampledRemoteAudio = resample(data, tx, newFs);
    disp(['Resampled REMOTE audio to nominal (', num2str(fs),... 
    ' Hz) sampling frequency']);
    remoteAudio = resampledRemoteAudio;
end


%% Edit audio to video start:
% - Local audio is simply synced to videoChannel
% - Remote audio is synced then delayed with audioDelay seconds

% local audio editing
startDiff = vidStart - localAudioStart;
maxSize = min([round(startDiff*fs+vidLength*fs), size(localAudio, 1), size(remoteAudio, 1)]);
localAudioEdited = localAudio(round(startDiff*fs)+1:maxSize, :);
localAudioEdited = mean(localAudioEdited, 2);
localAudioEdited = localAudioEdited/max(localAudioEdited);

% remote audio editing - first sync
startDiff = vidStart - remoteAudioStart;
remoteAudioEdited = remoteAudio(round(startDiff*fs)+1:maxSize, :);
remoteAudioEdited = mean(remoteAudioEdited, 2);
remoteAudioEdited = remoteAudioEdited/max(remoteAudioEdited);

% check length, there might be a difference of one due to rounding
if length(localAudioEdited) ~= length(remoteAudioEdited)
    l1 = length(localAudioEdited);
    l2 = length(remoteAudioEdited);
    if l1 < l2
        remoteAudioEdited = remoteAudioEdited(1:l1);
    elseif l1 > l2
        localAudioEdited = localAudioEdited(1:l2);
    end
end

% delay remote audio
% delaySamples = round(audioDelay*fs)-0.050*fs;
delaySamples = round(audioDelay*fs);
remoteAudioEdited = [zeros(delaySamples, 1); remoteAudioEdited(1:end-delaySamples)];

% combine and save audio
syncedAudio = (localAudioEdited + remoteAudioEdited)/2;
syncedAudio = [syncedAudio, syncedAudio];

audiowrite(syncedAudioF, syncedAudio, fs);


return




