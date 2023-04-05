function videoChannelStatic(pairNo, labName, devID)
%% Function for video-mediated interaction across Mordor and Gondor labs, image-only version
%
% USAGE: videoChannelStatic(pairNo, labName, devID='/dev/video0')
%
% Reads in video frames from a v4l2 video device and saves them out.
% Only a static image is shown on screen, not the video.
% To capture video, a custom GStreamer pipeline is called via Psychtoolbox,
% the exact pipeline is HARDCODED! Only the device path ('devID') is controlled via input argument.
%
% Version for webcam connected directly from remote lab to local control PC (via USB repeaters).
%
% Remote control PC is assumed to be present and running the same script, as 
% function UDPhandshake is called to negotiate a shared start time.
% 
% Mandatory inputs:
% pairNo        - Numeric value, pair number, one of [1:999]. 
% labName       - Char array, lab name, one of {"Mordor", "Gondor"}. 
%                   Added to filenames.
%
% Optional inputs:
% devID         - Char array, ID of camera device. Defaults to
%                 "/dev/video0".
%    
% Outputs:
% 


%% Input checks

if ~ismember(nargin, 2:3)
    error('Input args "pairNo" are "labName" are required while "gstSpec" is optional!');
end  % if
if nargin == 2
    devID = "/dev/video0";
end  % if 
if ~isnumeric(pairNo) || ~ismember(pairNo, 1:999)
    error("Input arg pairNo should be one of 1:999!");
end  % if
if ~ischar(labName) || ~ismember(labName, {"Mordor", "Gondor"})
    error("Input arg labName should be one of Mordor/Gondor as char array!");
end  % if


%% Constants, params, setup


gstSpec = ['v4l2src device=', devID, ' ! jpegdec ! video/x-raw',...
    ',width=1920,height=1080,framerate=30/1 ! videoconvert']; 
disp([char(10), 'Custom GStreamer pipeline used: ',... 
	char(10), gstSpec]);

% filename for saving timestamps and other relevant vars
resDir = ["/home/mordor/CommGame/pair", num2str(pairNo), "/"];
savefile = [resDir, "pair", num2str(pairNo), "_", labName, "_freeConv_videoTimes.mat"];

% remote IP, depends on lab name
if strcmp(labName, "Mordor")
    remoteIP = "192.168.0.20";
elseif strcmp(labName, "Gondor")
    remoteIP = "192.168.0.10";
end  % if

% video recording
moviename = [resDir, "pair", num2str(pairNo), "_", labName, "_freeConv.mov"];
vidLength = 10800;  % maximum length for video in secs
codec = ':CodecType=DEFAULTencoder';  % default codec
codec = [moviename, codec];

% video settings
waitForImage = 0;  % setting for Screen('GetCapturedImage'), 0 = polling (non-blocking); 1 = blocking wait for next image
vidSamplingRate = 30;  % expected video sampling rate, real sampling rate will differ
vidDropFrames = 1;  % dropframes flag for StartVideoCapture, 0 = do not drop frames; 1 = drop frame if necessary, only return the last captured frame
vidRecFlags = 16;  % recordingflags arg for OpenVideoCapture, 4 (= only save to disk, do not return image) + 16 (= use parallel thread in background)
vidRes = [0 0 1920 1080];  % frame resolution

% screen params
backgroundColor = [0, 0, 0];  % general screen openwindow background color
windowTextSize = 24;  % general screen openwindow text size

% try to load static image
staticImgPath = ["/home/mordor/CommGame/pair", num2str(pairNo),... 
    "/static_img_pair", num2str(pairNo),"_", labName, ".jpg"];
staticImg = imread(staticImgPath);
if ~isequal(size(staticImg), [vidRes(4),  vidRes(3), 3])
    error(["Static img at ", staticImgPath, " has unexpected size! (",... 
        num2str(size(staticImg)), ") !"]);
end

% preallocate frame info holding vars, adjust for potentially higher-than-expected sampling rate
frameCaptTime = nan((vidLength+60)*vidSamplingRate, 1);
flipTimestamps = nan((vidLength+60)*vidSamplingRate, 3);  % three columns for the three flip timestamps returned by Screen
droppedFrames = frameCaptTime;

% init parallel port control
ppdev_mex('Open', 1);
trigL = 2000;  % microseconds
trigEndSignal = 200;
trigSignal = 100;

devName = 'Logitech Webcam C925e'; 
tmpDevices = Screen('VideoCaptureDevices');
camdevice = [];  
for i = 1:numel(tmpDevices)
  if strncmp(tmpDevices(i).DeviceName, devName, length(devName))
    camdevice = tmpDevices(i).DeviceIndex;
  end  % if
end  % for


%% Psychtoolbox initializations

Priority(1);
PsychDefaultSetup(1);
Screen('Preference', 'Verbosity', 3);
screen=max(Screen('Screens'));
GetSecs; WaitSecs(0.1); KbCheck;  % dummy calls

% Try to set video capture to custom pipeline
try
    Screen('SetVideoCaptureParameter', -1, sprintf('SetNextCaptureBinSpec=%s', gstSpec));
catch ME
    disp('Failed to set Screen(''SetVideoCaptureParameter''), errored out.');
    sca; 
    rethrow(ME);
end

%% Start video capture and put up static image on screen

try
    % Open onscreen window for video playback
    win = Screen('OpenWindow', screen, backgroundColor);
    Screen('TextSize', win, windowTextSize);  % set text size for win
    Screen('Flip', win);  % initial flip to background
    
    % Open video capture device
    grabber = Screen('OpenVideoCapture', win, -9, vidRes, [], [], [], codec, vidRecFlags);
    % grabber = Screen('OpenVideoCapture', win, camdevice, vidRes, [], [], [], codec, vidRecFlags);
    % Wait a bit for OpenVideoCapture to return
    WaitSecs('YieldSecs', 1);
    
    % get a shared start time across machines
    sharedStartTime = UDPhandshake(remoteIP);
    
    % get texture for static image and display it
    imageTexture = Screen('MakeTexture', win, staticImg);
    Screen('DrawTexture', win, imageTexture);  
    staticImgFlip = Screen('Flip', win);
    
    % Start capture 
    [reportedSamplingRate, vidcaptureStartTime] = Screen('StartVideoCapture', grabber, vidSamplingRate, vidDropFrames, sharedStartTime);
    lptwrite(1, trigSignal, trigL);
    disp('Started video capture');
        
    % Check the reported sampling rate, compare to requested rate
    if reportedSamplingRate ~= vidSamplingRate
        warning(['Reported sampling rate from Screen(''StartVideoCapture'') is ', ...
        num2str(reportedSamplingRate), ' fps, not matching the requested rate of ', ...
        num2str(vidSamplingRate), ' fps!']);
    end  % if
    
    % estimate camera latency 
    camlatency = PsychCamSettings('EstimateLatency', grabber);
    fprintf('Estimated camera latency is %f ms.\n', camlatency  * 1000);
    
    % helper variables for the display loop
    lastTriggerTime = vidcaptureStartTime;
    oldtex = 0;
    vidFrameCount = 1;

    % Run until keypress or until maximum allowed time is reached
    while GetSecs < vidcaptureStartTime+vidLength
         
        if GetSecs > lastTriggerTime + 60
            lastTriggerTime = GetSecs;
            lptwrite(1, trigSignal, trigL);
        end
         
        % check for key press (ESCAPE)
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown && keyCode(KbName('ESCAPE'))
            disp([char(10), 'User requested abort...']);
            break;
        end  % if        
       
        % Check for next available image, return it as texture if there was one
        [tex, frameCaptTime(vidFrameCount), droppedFrames(vidFrameCount)] = Screen('GetCapturedImage', win, grabber, waitForImage, oldtex); 
        if tex > 0
            oldtex = tex;
            vidFrameCount = vidFrameCount + 1;
        end  % if        
       
    end  % while 

    
    %% Cleanup, saving out timing information
    
    % get total elapsed time
    elapsedTime = GetSecs - vidcaptureStartTime;
    
    % shutdown video and screen
    Screen('StopVideoCapture', grabber);  % Stop capture engine and recording  
    stopCaptureTime = GetSecs; 
    Screen('CloseVideoCapture', grabber);  % Close engine and recorded movie file
    closeCaptureTime = GetSecs; 
    lptwrite(1, trigEndSignal, trigL);
    ppdev_mex('Close', 1);
    Priority(0);
    sca;

    % save major timestamps
    save(savefile, "vidcaptureStartTime", "sharedStartTime",...
    "stopCaptureTime", "closeCaptureTime", "elapsedTime",...
    "frameCaptTime", "droppedFrames", "vidFrameCount",...
    "flipTimestamps", "staticImgFlip");

    % report start time of capture, elapsed time 
    disp([char(10), 'Requested (shared) start time was: ', num2str(vidcaptureStartTime)]);
    disp([char(10), 'Start of capture was: ', num2str(vidcaptureStartTime)]);
    disp([char(10), 'Difference: ', num2str(vidcaptureStartTime - sharedStartTime)]);
    disp([char(10), 'Total elapsed time from start of capture: ', num2str(elapsedTime)]);     
    
    
catch ME

    % In case of error, close screens, video
    Priority(0);
    lptwrite(1, trigEndSignal, trigL);
    ppdev_mex('Close', 1);
    sca;  % closes video too
    rethrow(ME);
    
    
end  % try



endfunction
