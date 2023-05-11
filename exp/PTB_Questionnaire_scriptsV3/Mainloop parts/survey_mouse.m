function [selects] = survey_mouse(pairNo, labName, quest_type, gameNo)
% The full course of an experiment

%clearvars;
%rng('shuffle');

% Add current folder and all sub-folders
addpath('/home/mordor/CommGame/PTB_Questionnaire_scriptsV3/..');

% -------------------------------------------------------
%                       Input checks
% -------------------------------------------------------

if nargin < 3
  error('Input args "pairNo", "labName" and "quest_type" are required!');
end

if nargin < 4 || isempty(gameNo)
    gameNo = 0;
end

if ~ismember(pairNo, 1:999)
    error('Input arg "pairNo" should be one of 1:999!');
end 

if ~ismember(labName, {'Mordor', 'Gondor'})
    error('Input arg "labName" should be one of {"Mordor", "Gondor"}!');
end

if ~ismember(quest_type, {'BGfirst', 'BGsecond', 'BGrest', 'playback',...
                          'freeConv', 'BFI_10', 'IRI', 'FELNE8'});
    error('Input arg "quest_type" is wrong!');
end

if ismember(quest_type, {'BGfirst', 'BGsecond', 'BGrest'}) && gameNo == 0;
    error('Cannot continue with this "quest_type" without input arg "gameNo!"');
endif

%--------------------------------------------------------------------------
%                       Global variables
%--------------------------------------------------------------------------
global window windowRect fontsize xCenter yCenter white;


%--------------------------------------------------------------------------
%                       Screen initialization
%--------------------------------------------------------------------------

% First create the screen for simulation displaying
% Using function prepareScreen.m
% This returned vbl may not be precise; flip again to get a more precise one
% This screen size is for test
[window, windowRect, vbl, ifi] = prepareScreen([0 0 1920 1080]);
HideCursor;


%--------------------------------------------------------------------------
%                       Global settings
%--------------------------------------------------------------------------

% Screen center
[xCenter, yCenter] = RectCenter(windowRect);


% Define some DEFAULT values
isdialog = false; % Change this value to determine whether to use dialog

showQuestNum = 8; % Number of questions to display in one screen; you may need to try few times to get best display
ansNum = 7; % Number of answers for each question
survey_type = 'likert'; % Type of the survey, can be "question", "likert"

survey_name = 'BG';

if strcmp(quest_type, 'BGfirst')
  filename = 'debrief_BG_first.csv' 
  questNum = 15; 
elseif strcmp(quest_type, 'BGrest')
  filename = 'debrief_BG_rest.csv'
  questNum = 13;
elseif strcmp(quest_type, 'BGsecond')
  filename = 'debrief_BG_second.csv'
  questNum = 16;
elseif strcmp(quest_type, 'freeConv')
  filename = 'debrief_freeConv.csv'
  survey_name = 'freeConv';
  questNum = 14;  
elseif strcmp(quest_type, 'playback')
  filename = 'debrief_playback.csv'
  survey_name = 'playback';
  questNum = 8;  
elseif strcmp(quest_type, 'BFI_10')
  filename = 'BFI_10.csv'
  survey_name = 'BFI_10'; 
  questNum = 10; 
  ansNum = 5; 
elseif strcmp(quest_type, 'IRI')
  filename = 'IRI.csv'
  survey_name = 'IRI'; 
  questNum = 28;
  ansNum = 5;  
elseif strcmp(quest_type, 'FELNE8')
  filename = 'FELNE8.csv'
  survey_name = 'FELNE8';
  questNum = 8; 
  ansNum = 5; 
end


% construct the .mat file for later saving
datadir = ["/home/mordor/CommGame/pair", num2str(pairNo), "/"];
if ~exist(datadir)
    error('Data folder %s does not exist!', datadir);    
endif

if gameNo > 0
    surveyDataFile = [datadir, "pair", num2str(pairNo), labName, "_", survey_name, num2str(gameNo), "_", quest_type, "_survey.mat"];
else
    surveyDataFile = [datadir, "pair", num2str(pairNo), labName, "_", survey_name, "_survey.mat"];
end

if exist(surveyDataFile)
    user_input = yes_or_no('Survey .mat file already exists! Do you want to overwrite it?');
    if user_input == 0
        error('Quitting...');
    endif
end

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

%------------------------------------------------------------------------------------
%                     Prepare survey texture 
%------------------------------------------------------------------------------------

% Survey texture for later drawing; the file is loaded inside
% prepareSurvey.m; for the detail of the csv file's structure, see loadSurvey.m

[paperTexture, paperRect, questH, ansH, questYs, ansYs] = prepareSurvey(isdialog, filename, survey_type, questNum, ansNum, showQuestNum);

%-------------------------------------------------------------------------------------

% Set FONT for instructions
Screen('Textsize', window, 21);
Screen('TextFont', window, 'Liberation Sans');

% COLOR settings
% Set color for identifying currently focused question and answer
% and selected answer
qcolor = [0 0 255 20];
acolor = [255 0 0 250];
scolor = [0 255 0 50]; % alpha values are not 0-1, but 0-255!!

##% Base rect for questions and answers
##baseQRect = [0 0 595 questH];
##if strcmp(survey_type, 'likert')
##    aCenters = linspace(595/(ansNum*2), 595*((ansNum-0.5)/ansNum), ansNum) + (xCenter-595/2);
##end
##
##paperlimit = [xCenter-595/2 xCenter+595/2];

% Base rect for questions and answers
baseQRect = [0 0 1190 questH];
if strcmp(survey_type, 'likert')
    aCenters = linspace(1190/(ansNum*2), 1190*((ansNum-0.5)/ansNum), ansNum) + (xCenter-1190/2);
end

paperlimit = [xCenter-1190/2 xCenter+1190/2];

% Keep a record of selections during loop
% These will be used to draw marks
selects = zeros([questNum, ansNum]);
currQ = 1;
currA = 0;
% To keep the marks in right place while scrolling screen
offsetRange = [showQuestNum-questNum 0];
offset = 0;

% Record selected rects here
seleRects = nan(4, questNum); % This is for drawing
tempRects = nan(4, questNum); % This is for recording

ShowCursor;

%-------------------------------------------------------------------------------
% First draw instructions
%-------------------------------------------------------------------------------

main_instruc_debrief = ["A következőkben az előző feladattal kapcsolatos tapasztalataidról kérdezünk." char(10), ...
           char(10), "Kérlek, hogy őszintén válaszolj, a válaszaidon ne gondolkozz sokat!",...
           char(10), "Mindig csak egy választ tudsz megjelölni.", ...          
           char(10), "A következő kérdésekre úgy görgethetsz, ha leviszed az egeret a lap aljára. ",... 
           char(10), "A program automatikusan kilép, ha minden kérdésre válaszoltál.",...
           char(10), char(10), "Kattins bárhova a képernyőn és kezdheted is a kitöltést."];
           
main_instruc_survey = ["A következőkben személyiségjellemzőkkel és különböző szituációkban átélt gondolatokkal,",...
           char(10), "érzésekkel kapcsolatos kérdőívek kitöltésére kérünk.", char(10), ...
           char(10), "Kérlek, hogy őszintén válaszolj, a válaszaidon ne gondolkozz sokat!",...
           char(10), "A kérdésekre adott válaszaidat nem értékeljük ki egyénileg, csakis összesítve használjuk majd fel.", char(10),...
           char(10), "Mindig csak egy választ tudsz megjelölni.", ...          
           char(10), "A következő kérdésekre úgy görgethetsz, ha leviszed az egeret a lap aljára. ", char(10),... 
           char(10), "A program automatikusan kilép, ha minden kérdésre válaszoltál.",...
           char(10), char(10), "Kattins bárhova a képernyőn és kezdheted is a kitöltést."];

Screen('FillRect', window, white, paperRect);
if strfind(filename, 'debrief');
    [~, ny] = DrawFormattedText(window, main_instruc_debrief, 'center', 'center', 0);
else
    [~, ny] = DrawFormattedText(window, main_instruc_survey, 'center', 'center', 0);
end
%DrawFormattedText(window, currDeviceIn, 'center', ny+questH, 0);
Screen('Flip', window);

% Wait for 10 secs here for participants to read the instruction before
% check for any input
WaitSecs(10);

% If any key clicked, go to the loop
%checkClicked(window);
while true   
    [~,~, buttons] = GetMouse(window, mouseid);
    if any(buttons)
        while any(buttons)
            [~,~, buttons] = GetMouse(window, mouseid);
        end
        break
    end
end

%================================================================================================
%                              MAIN LOOP 
%================================================================================================

% Show the survey
Screen('FillRect', window, white, paperRect);
Screen('DrawTextures', window, paperTexture, [], paperRect, 0, 0);
Screen('Flip', window);


% Start loop to monitor the mouse position and check for click
while true
    % Get current coordinates of mouse
    [x, y, buttons] = GetMouse(window, mouseid);
    
    % Don't let the mouse exceed our paper
    if x > paperlimit(2)
        SetMouse(paperlimit(2), y, window);
    elseif x < paperlimit(1)
        SetMouse(paperlimit(1), y, window);
    end
    
    % Scroll the paper
    % Since GetMouseWheel is not supported in linux,
    % I'll use something like hot corners to scroll the paper
    if y > windowRect(4)-2 && offset > offsetRange(1)
        offset = offset - 1;
        SetMouse(x, y-50, window);
    elseif y < windowRect(2) + 2 && offset < offsetRange(2)
        offset = offset + 1;
        SetMouse(x, y+50, window);
    end
    
    % Move the survey texture with the offset
    newpaper = paperRect;
    newpaper(2:2:end) = newpaper(2:2:end) + offset * questH;
    Screen('DrawTextures', window, paperTexture, [], newpaper, 0, 0);
    
    % Find the nearest question from mouse
    [~, newcurrQ] = min(abs(questYs+offset*questH - y));
    if newcurrQ ~= currQ
        currA = 0;
    end
    currQ = newcurrQ;

    currY = questYs(currQ) + offset * questH;
    qrect = CenterRectOnPointd(baseQRect, xCenter, currY);
    Screen('FillRect', window, qcolor, qrect); % draw a rect over the question
    
    % Find the nearest answer from mouse
    switch survey_type
        case 'question'
            currAYs = ansYs(currQ, :) + offset*questH;
            if y >= currAYs(1) - ansH(currQ, 1)/2 && y <= currAYs(end) + ansH(currQ, end)
                [~, currA] = min(abs(currAYs - y));
                currY = ansYs(currQ, currA);
                %arect = CenterRectOnPointd([0 0 763 ansH(currQ, currA)], xCenter, currY);
                %arect = CenterRectOnPointd([0 0 595 ansH(currQ, currA)], xCenter, currY);
                arect = CenterRectOnPointd([0 0 1190 ansH(currQ, currA)], xCenter, currY);
            else
                currA = 0;
            end
        case 'likert'
            currAYs = ansYs(currQ) + offset*questH;
            if y >= currAYs - ansH/2 && y <= currAYs + ansH/2
                [~, currA] = min(abs(aCenters - x));
                currY = ansYs(currQ);
                %arect = CenterRectOnPointd([0 0 round(763 / ansNum) fontsize], aCenters(currA), currY);
                %arect = CenterRectOnPointd([0 0 round(595 / ansNum) fontsize], aCenters(currA), currY);
                arect = CenterRectOnPointd([0 0 round(1190 / ansNum) fontsize], aCenters(currA), currY);
            else
                currA = 0;
            end
    end
    
    if currA % If any answer gets hovered
        if any(buttons) % And if any button gets clicked
            tempRects(:, currQ) = arect;
            selects(currQ, :) = 0;
            selects(currQ, currA) = 1;
        end
        arect(2:2:end) = arect(2:2:end) + offset * questH;
        Screen('FrameRect', window, acolor, arect); % draw a rect over the answer
    end
    % Draw rects to identify selected answers
    k = find(selects);
    if ~isempty(k) % check if any answer been selected
        seleRects = tempRects;
        seleRects(2:2:end, :) = seleRects(2:2:end, :) + offset * questH;
        Screen('FillRect', window, scolor, seleRects);
    end

    Screen('Flip', window);

    % If all questions have been answered, quit the survey after 3 secs
    if size(k, 1) == questNum
        WaitSecs(3);
        break
    end

    % Do not go back until all buttons are released
    while find(buttons)
        [x, y, buttons] = GetMouse(window, mouseid);
    end
end

%======================================================
%               Clean up
%======================================================
                
% Get the results
[row, col] = find(selects);
selects = [row, col];
selects = sortrows(selects, 1);

% save results to .mat file
save(surveyDataFile, 'selects');
selects % show in command line

WaitSecs(1);
Screen('Flip', window);

% End of survey
DrawFormattedText(window, ["Kérdőív vége. ", char(10), char(10), "Köszönjük a kitöltést."], 'center', 'center', 0);
Screen('Flip', window);
WaitSecs(3);

Screen('Close');
sca;

endfunction