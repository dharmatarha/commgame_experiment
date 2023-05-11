function subjectiveVideoPlaybackStatic(pairNo, labName)
%% Initial video playback script for the free conversation task (or 
%% the Bargaining Game) with subjective evaluation of predictability 
%% aka a slider that moves horizontally with the mouse
%
% - slider position is defined relative to the screen size 
% - exits after video is done playing or max timeout is reached (vidLength) or 
%   if you press ESC
% 
% Usage:
%         pairNo (1:999), labName ("Mordor", "Gondor") is required
%         - rn the script looks for video and audio in the same folder ('/home/mordor/CommGame/pair99/...')
%         - with filenames such as: pair99_Common_freeConv_audio.wav or pair99_Gondor_freeConv.mov
% Output:
%         pair99Gondor_sliderPosition.mat 
%         - vector containing numeric mouse position data (0-100) for every video frame 
%         - 0: "egyáltalán nem lepődtem meg", 100: "nagyon meglepődtem"
%
%         pair99Gondor_subjtimes.mat
%         - all relevant timestamps including flips, textures drawn, audio start
%


%%%%%%% screen params %%%%%%%%
backgrColor = [255 255 255];  % white background
offbackgrColor = [255 255 255 0]; % transparent background for offscreen window
windowTextSize = 24;  % general screen openwindow text size
windowSize = [0 0 1920 1080];
vidLength = 1500;
instruction1 = ["A következő részben vissza fogjuk játszani az előző beszélgetést." char(10),...
              "Az a feladatod, hogy a csúszka segítségével folyamatosan jelezd, " char(10),...
              "hogy az adott pillanatban mennyire volt meglepő, amit a másik személy mondott." char(10),...
              char(10), "A skálán az 'Egyáltalán nem lepődtem meg' és a 'Nagyon meglepődtem' " char(10),...
              "értékek között tudsz mozogni az egérrel."];
instruction2 = ["Kérlek próbáld ki a csúszka használatát! " char(10),...
               char(10), "Ha felkészültél, vidd az egeret a skála bal végéhez, ",...
               "ezután egy bal klikkel indíthatod a feladatot."];              
instr_time = 30;
timeout = 240; % timeout for tutorial part 
txtColor = [0, 0, 0];  % black letters
vidRect = [round(windowSize(3)/8) 0 round(windowSize(3)/8*7) 864];


%%%%%%% video folders %%%%%%%%

if labName == 'Mordor'
  vidDir = ['/home/mordor/CommGame/pair', num2str(pairNo), '/'];
elseif labName == 'Gondor'
  vidDir = ['/home/mordor/CommGame/pair', num2str(pairNo), '/'];
end
moviename = ["pair", num2str(pairNo), '_', labName, "_freeConv.mov"];
moviefilename = [vidDir, moviename];

%%%%%%% audio params %%%%%%%%

audiofile = [vidDir, 'pair', num2str(pairNo), '_', labName, '_freeConv_syncedAudio.wav'];
mode = []; % default mode, only playback
reqLatencyClass = 1;  % not aiming for low latency
freq = 44100;  % sampling rate in Hz
% get correct audio device
devName = 'MAYA22 USB'; 
tmpDevices = PsychPortAudio('GetDevices');
audiodevice = [];  
for i = 1:numel(tmpDevices)
  if strncmp(tmpDevices(i).DeviceName, devName, length(devName))
    audiodevice = tmpDevices(i).DeviceIndex;
  endif
endfor
% Read WAV file 
[y, freq] = psychwavread(audiofile);
wavedata = y';
nrchannels = size(wavedata,1); % Number of rows == number of channels. 


%% Trigger preparations

% init parallel port control
ppdev_mex('Open', 1);
trigL = 2000;  % microseconds
trigSignal = 100;
trigEndSignal = 200;
trigPeriod = 60;


%% Load static image
staticImgPath = ["/home/mordor/CommGame/pair", num2str(pairNo),... 
    "/static_img_pair", num2str(pairNo),"_", labName, ".jpg"];
staticImg = imread(staticImgPath);
if ~isequal(size(staticImg), [1080,  1920, 3])
    error(["Static img at ", staticImgPath, " has unexpected size! (",... 
        num2str(size(staticImg)), ") !"]);
end


%% Psychtoolbox initializations

PsychDefaultSetup(1);
InitializePsychSound;
Screen('Preference', 'Verbosity', 3);
screen=max(Screen('Screens'));
RestrictKeysForKbCheck(KbName('ESCAPE'));  % only report ESCape key press via KbCheck
GetSecs; WaitSecs(0.1); KbCheck(); % dummy calls

try
  
    % Init a window in top-left corner, skip tests
    oldsynclevel = Screen('Preference', 'SkipSyncTests', 1);
    [win, rect] = Screen('OpenWindow', screen, backgrColor, windowSize);
    Screen('TextSize', win, windowTextSize);    
   
%%%%%%%%%%%% Slider params %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   
    question      = "Mennyire meglepő?";
    anchors       = {'Egyáltalán nem lepődtem meg', 'Nagyon meglepődtem'};
    center        = round([rect(3) rect(4)]/2);
    lineLength    = 10; % length of the scale
    width         = 3; % width of scale
    sliderwidth   = 5; 
    scalaLength   = 0.8; % length of scale relative to window size
    scalaPosition = 0.9; % scale position relative to screen (0 is top, 1 is bottom)
    sliderColor   = [255 0 50]; % red(ish)
    scaleColor    = [0 0 0];
    startPosition = 'left'; % position of scale
    displayPos    = false; % display numeric position of slider (0-100)
    
    % chosing the right mouse device 
    [mouseIndices, productnames] = GetMouseIndices;
    mouseName = 'Logitech';
    device = 'mouse';    
    for k = 1:numel(productnames)
      if strncmp(productnames(k), mouseName, length(mouseName))
        mouseid = mouseIndices(k);
      endif
    endfor
    
    disp([char(10), num2str(mouseIndices)]);
    disp(productnames);
    disp([char(10), 'Using mouse with index: ', num2str(mouseid)]);
    
    HideCursor(win);
    
    % Parsing size of the global screen
    globalRect = Screen('Rect', screen);
    
    %% Coordinates of scale lines and text bounds
    if strcmp(startPosition, 'right')
      x = globalRect(3)*scalaLength;
    elseif strcmp(startPosition, 'center')
      x = globalRect(3)/2;
    elseif strcmp(startPosition, 'left')
      x = globalRect(3)*(1-scalaLength);
    else
      error('Only right, center and left are possible start positions');
    end
    SetMouse(round(x), round(rect(4)*scalaPosition), win);
    %midTick    = [center(1) rect(4)*scalaPosition - lineLength - 5 center(1) rect(4)*scalaPosition  + lineLength + 5];
    leftTick   = [rect(3)*(1-scalaLength) rect(4)*scalaPosition - lineLength rect(3)*(1-scalaLength) rect(4)*scalaPosition  + lineLength];
    rightTick  = [rect(3)*scalaLength rect(4)*scalaPosition - lineLength rect(3)*scalaLength rect(4)*scalaPosition  + lineLength];
    horzLine   = [rect(3)*scalaLength rect(4)*scalaPosition rect(3)*(1-scalaLength) rect(4)*scalaPosition];
    if length(anchors) == 2
      textBounds = [Screen('TextBounds', win, sprintf(anchors{1})); Screen('TextBounds', win, sprintf(anchors{2}))];
    else
      textBounds = [Screen('TextBounds', win, sprintf(anchors{1})); Screen('TextBounds', win, sprintf(anchors{3}))];
    end
    
    % Calculate the range of the scale, which will be needed to calculate the
    % position
    scaleRange = round(rect(3)*(1-scalaLength)):round(rect(3)*scalaLength); % Calculates the range of the scale (384:1536 in this case)
    
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%% Loading the movie file in advance %%%%%%%%%%%%%
   
    KbReleaseWait;
    WaitSecs('YieldSecs', 1);
    
%    [moviePtr, duration, fps, moviewidth, movieheight, framecount] = Screen('OpenMovie', win, moviefilename);
%    disp(["Movie " moviefilename, " opened and ready to play! ",...
%           char(10), "Duration: ", num2str(duration), "secs, with", num2str(framecount), " frames."]);
      
    % preallocate variables for timestamps and mouse position output
    sliderPos = nan(150000, 1);
    baseDir = "/home/mordor/CommGame/";
    sliderValueFile = [baseDir, "pair", num2str(pairNo), "/pair", num2str(pairNo), labName, "_sliderPosition.mat"];
    flipTimes = nan(20*60, 1);
    texTimestamps = nan();
    timestampsFile = [baseDir, "pair", num2str(pairNo), "/pair", num2str(pairNo), labName, "_subjtimes.mat"];
     
    % helper variables for the display loop
    oldtex = 0;
    count = 0;
    clickFlag = false;
    
%%%%%%%%% Drawing the first instruction %%%%%%%%%%

    % display instruction for given time 
    DrawFormattedText(win, instruction1, 'center', 'center', txtColor, [], [], [], 1.5);
    Screen("Flip", win);
    WaitSecs(instr_time);    

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% First while loop for "Tutorial" - drawing just the scale and an instruction %%%%%%
   
    offwin = Screen('OpenOffscreenWindow', win, offbackgrColor, windowSize);
    DrawFormattedText(offwin, instruction2, 'center', 'center', txtColor);
    
    % Drawing the question as text
    DrawFormattedText(offwin, question, 'center', rect(4)*(scalaPosition - 0.03));    
    % Drawing the anchors of the scale as text   
    DrawFormattedText(offwin, anchors{1}, leftTick(1, 1) - textBounds(1, 3)/2,  rect(4)*scalaPosition+40); % Left point
    DrawFormattedText(offwin, anchors{2}, rightTick(1, 1) - textBounds(2, 3)/2,  rect(4)*scalaPosition+40); % Right point  
    % Drawing the scale
    Screen('DrawLine', offwin, scaleColor, leftTick(1), leftTick(2), leftTick(3), leftTick(4), width);     % Left tick
    Screen('DrawLine', offwin, scaleColor, rightTick(1), rightTick(2), rightTick(3), rightTick(4), width); % Right tick
    Screen('DrawLine', offwin, scaleColor, horzLine(1), horzLine(2), horzLine(3), horzLine(4), width);     % Horizontal line 
    
    disp([char(10), 'Starting tutorial..', char(10)]);
    startTut = GetSecs;    
    
    while ~KbCheck && GetSecs < startTut+timeout && clickFlag==false  
      
      offtex = Screen('GetImage', offwin); % make an image texture from offscreen window
      Screen('PutImage', win, offtex);           
      Screen('DrawTextures', win, offwin);  % Draw textures from both windows            
      
      % Parse user input for x location
      [x,~,buttons,~,~,~] = GetMouse(win, mouseid);  
      
      % Stop at upper and lower bound
      if x > rect(3)*scalaLength
        x = rect(3)*scalaLength;
      elseif x < rect(3)*(1-scalaLength)
        x = rect(3)*(1-scalaLength);
      end
      
      % The slider
      Screen('DrawLine', win, sliderColor, x, rect(4)*scalaPosition - lineLength, x, rect(4)*scalaPosition  + lineLength, sliderwidth);
      
      % Caculates position
      if x <= (min(scaleRange))
        position = 0;
      else
        position = round((x)-min(scaleRange)); % Calculates the deviation from 0. 
        position = (position/(max(scaleRange)-min(scaleRange)))*100; % Converts the value to percentage               
      end          
      
      % Display position
      if displayPos
        DrawFormattedText(win, num2str(round(position)), 'center', rect(4)*(scalaPosition - 0.07));             
      end              
      
      % check if there was a button press
      if any(buttons)
        clickFlag = true;        
        % wait till button is released (click ended)
        while any(buttons)
          WaitSecs(0.01);  % 10 msecs
          [~, ~, buttons] = GetMouse(win, mouseid);
        end  
      end   
    
      Screen('Flip', win);  % Show new texture   
      
    endwhile
   
    %Screen('Flip', win); 
    disp([char(10) "Tutorial finished, moving on.."]);  
    %WaitSecs(2);     

    % Setting up a waitbar for the main loop
    b = waitbar(0, 'Processing...', 'Name', 'Video Playback ongoing..');  
    movegui(b,[-250 700]); % values can be out of screen bounds, use it to move bar to another screen 
    WaitSecs(2); 

%%%%%%%%%%%% Audio part %%%%%%%%%%%%%%%%    
       
    pahandle = PsychPortAudio('Open', audiodevice, mode, reqLatencyClass, freq, nrchannels);
    
    % Fill the audio playback buffer with the audio data 'wavedata':
    PsychPortAudio('FillBuffer', pahandle, wavedata);
    disp([char(10), 'Audio ready for playback']);   
 
%%%%%%%%%%% Displaying the static image + start audio %%%%%%%%%%%%
 
    %droppedFrames = Screen('PlayMovie', moviePtr, 1);
    %disp([char(10) 'Starting movie + sound...' char(10)]);
    
    % get texture for static image and display it
    staticImgTexture = Screen('MakeTexture', win, staticImg);
    Screen('DrawTexture', win, staticImgTexture, [], vidRect);  
    startAt = Screen('Flip', win);    
    
    % write start trigger
    lptwrite(1, trigSignal, trigL);
    audioRealStart = PsychPortAudio('Start', pahandle, 1, startAt+0.300, 0); % start playing audio with 20ms delay which is
                                                                            % the estimated value of time between audioRealStart and first flip
##    audioRealStart = PsychPortAudio('Start', pahandle, 1, startAt+0, 0);
    % get current status of audio: includes real start of playback(?)
    audioStatus = PsychPortAudio('GetStatus', pahandle); 
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
%%%%%%%%%%%%%%%% Main while loop %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
    
    lastTriggerTime = startAt;
  
    while ~KbCheck && GetSecs < startAt+vidLength                           
        
        % send a TTL trigger every minute
        if GetSecs > lastTriggerTime + trigPeriod
            lastTriggerTime = GetSecs;
            lptwrite(1, trigSignal, trigL);
        end               
        
        % Parse user input for x location
        [x, ~, buttons, ~, ~, ~] = GetMouse(win, mouseid);  
        
        % Stop at upper and lower bound
        if x > rect(3)*scalaLength
          x = rect(3)*scalaLength;
        elseif x < rect(3)*(1-scalaLength)
          x = rect(3)*(1-scalaLength);
        end
        
        % Drawing the question as text
        DrawFormattedText(win, question, 'center', rect(4)*(scalaPosition - 0.03)); 
        
        % Drawing the anchors of the scale as text
        if length(anchors) == 2
          % Only left and right anchors
          DrawFormattedText(win, anchors{1}, leftTick(1, 1) - textBounds(1, 3)/2,  rect(4)*scalaPosition+40); % Left point
          DrawFormattedText(win, anchors{2}, rightTick(1, 1) - textBounds(2, 3)/2,  rect(4)*scalaPosition+40); % Right point          
        end
        
        % Drawing the scale
        %Screen('DrawLine', win, scaleColor, midTick(1), midTick(2), midTick(3), midTick(4), width);         % Mid tick
        Screen('DrawLine', win, scaleColor, leftTick(1), leftTick(2), leftTick(3), leftTick(4), width);     % Left tick
        Screen('DrawLine', win, scaleColor, rightTick(1), rightTick(2), rightTick(3), rightTick(4), width); % Right tick
        Screen('DrawLine', win, scaleColor, horzLine(1), horzLine(2), horzLine(3), horzLine(4), width);     % Horizontal line
        
        % The slider
        Screen('DrawLine', win, sliderColor, x, rect(4)*scalaPosition - lineLength, x, rect(4)*scalaPosition  + lineLength, sliderwidth);
        
        % Caculates position
        if x <= (min(scaleRange))
          position = 0;
        else
          position = (round((x)-min(scaleRange))); % Calculates the deviation from 0. 
          position = (position/(max(scaleRange)-min(scaleRange)))*100; % Converts the value to percentage               
        end   
        
        % Display position
        if displayPos
          DrawFormattedText(win, num2str(round(position)), 'center', rect(4)*(scalaPosition - 0.07));             
        end           
        
        % display static image
        Screen('DrawTexture', win, staticImgTexture, [], vidRect);
        
        fliptime = Screen('Flip', win);  % Show new textures          
        count = count + 1;  % counter for flips    
                
        flipTimes(count, 1) = fliptime; % store timestamps of flips       
        sliderPos(count, 1) = round(position); % store mouse position data   

      
        % fancy bar indicating the position of mouse
        frac = (sliderPos(count,:))/100; 
        waitbar(frac, b, ['Mouse position: ', num2str(sliderPos(count,:))], 'WindowStyle', 'normal');
      
                  
    endwhile
    
    %stopaudio = GetSecs;
    s = PsychPortAudio('GetStatus', pahandle); 
    PsychPortAudio('Stop', pahandle);
    disp([char(10), 'Movie ended, bye!']);
 
%%% Saving important variables

    save(sliderValueFile, "sliderPos", "-v7");  
    save(timestampsFile, "flipTimes", "audioRealStart", "audioStatus", "startAt", "-v7");
 
%%% Cleaning up 
    close(b);
    % Screen('CloseMovie');
    Screen('Close');
    lptwrite(1, trigEndSignal, trigL);
    ppdev_mex('Close', 1);
    PsychPortAudio('Close');
    RestrictKeysForKbCheck([]);
    sca;
      
catch ME
    sca;
    ppdev_mex('Close', 1);    
    rethrow(ME);
    
end %try
    
endfunction