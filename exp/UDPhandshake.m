function sharedStartTime = UDPhandshake(remoteIP, remotePort, localPort, startDelay, maxDiff, maxTimeOut)
%% Function to negotiate a common start time across systems on local network
%
% USAGE: sharedStartTime = UDPhandshake(remoteIP, 
%                                       remotePort=9998, 
%                                       localPort=9998, 
%                                       startDelay=10, 
%                                       maxDiff=0.1, 
%                                       maxTimeOut=60)
% 
% The function solves the problem of starting processes approximately
% synchronously across two machines linked on a local network.
%
% Assumptions:
% - System clocks are more-or-less synched (ideally with only 1-2 ms difference max)
% - Network time is reasonable for local network (few ms max)
%
% The function must be run on both machines. 
%
% At first, both instances send "greetings" messages to the remote IP and keep  
% doing so until they detect the same message coming from remote IP. 
% Packets are sent every 10 ms (controlled by hardcoded param "waitTime").
% Detection of "greetings" message should happen more-or-less synchronously 
% at both machines (with jitter of "waitTime" + network transmission + clock difference).
%
% Next, machines exchange current time by sending each other the timestamp 
% generated after detecting "greetings" message. If the difference between the
% local and remote timestamps is too great (>maxDiff), the function errors out
% as system clocks are probably seriously out-of-sync.
% If the difference is within tolerance, a common start time is derived at both end
% by averaging the two timestamps and adding a fixed delay ("startDelay"). 
%
% Shared start time is now the same timestamp on both machines, "startDelay" 
% secs in the future.
%

%% Import
pkg load sockets;


%% Input checks

if nargin > 6
    error('Too many input args!');
elseif nargin < 6 || isempty(maxTimeOut)
    maxTimeOut = 60;  % maximum wait time for handshake to happen, in secs
end
if nargin < 5 || isempty(maxDiff)
    %maxDiff = 0.1;  % maximum difference of timestamps in second stage, in secs
    maxDiff = 10;  % maximum difference of timestamps in second stage, in secs
end
if nargin < 4 || isempty(startDelay)
    startDelay = 5;  % constant added to the average of second-stage timestamps to derive a timestamp in the future, in secs
end
if nargin < 3 || isempty(localPort)
    localPort = 9998;  % port used locally for UDP packets (both incoming and outgoing)
end
if nargin < 2 || isempty(remotePort)
    remotePort = 9998;  % port used for UDP packets on remote machine (where to send UDP packets)
end
if nargin < 1
    error('Input arg "remoteIP" is needed!');
end
    

%% Constants, params, setup

waitTime = 0.01;  % time between sending packets when repeatedly doing so, in both stages, in secs
initMessage = 'kuldj egy jelet';  % initial "greetings" message
remoteAddr = struct('addr', remoteIP, 'port', remotePort);
timeStampLikeLimit = 100;  % maximum time difference in secs for reporting incoming packet as timestamp-like
timeOffReportsMax = 3;  % maximum number of times to report if incoming packet is timestamp-like but not close enough (in terms of maxDiff)
  
% Dummy calls for Psychtoolbox functions
GetSecs; WaitSecs(0.1);

% Open socket, connect it to remote address
udpSocket = socket(AF_INET, SOCK_DGRAM);
bind(udpSocket, localPort);
connect(udpSocket, remoteAddr);
  
  
%% First stage

% While loop with timeout
successFlag = 0;
stageStart = GetSecs;
while ~successFlag && (GetSecs-stageStart) < maxTimeOut
  % try reading from the socket
  [incomingMessage, count] = recv(udpSocket, 512, MSG_DONTWAIT);  % non-blocking
  % if there was incoming packet and it matches initMessage, 
  % send last messages and move on
  if count ~= -1 && strcmp(char(incomingMessage), initMessage)
      % send initMessage one last time
      send(udpSocket, initMessage);
      % set flag for exiting the while loop
      successFlag = 1; 
      disp([char(10), 'Received message: ', char(incomingMessage)]);
      disp(['Received expected message in first stage, moving on.']);
  % if there was no incoming packet or it did not match initMessage,
  % send initMessage  
  else
      send(udpSocket, initMessage);
  endif
  % wait a bit before next iteration
  WaitSecs(waitTime);
endwhile

% Check for timeout
if ~successFlag
  disconnect(udpSocket);
  error('Handshake procedure timed out during first stage!');
endif
  
  
%% Second stage

% While loop with timeout
successFlag = 0;
stageStart = GetSecs;
timeMessage = num2str(stageStart, '%.5f');  % packet requires string or uint8
timeOffCounter = 0;
while ~successFlag && (GetSecs-stageStart)<maxTimeOut
  % try reading from the socket
  [incomingMessage, count] = recv(udpSocket, 512, MSG_DONTWAIT);  % non-blocking
  % if there was incoming packet and it is a timestamp close to timeMessage,
  % send last messages and move on
  if count ~= -1 && abs(str2double(char(incomingMessage))-stageStart) < maxDiff
      % send timeMessage one last time 
      send(udpSocket, timeMessage);
      % set flag for exiting the while loop
      successFlag = 1;
      disp([char(10), 'Received message: ', char(incomingMessage)]);
      disp([char(10), 'Received timestamp-like message in second stage, moving on.']);
  % if there was incoming packet and it can be understood as a timestamp 
  % but not close "enough" to timeMessage, report the discrepancy 
  % and send timeMessage again
  elseif count ~= -1 && abs(str2double(char(incomingMessage))-stageStart) >= maxDiff && ...
          abs(str2double(char(incomingMessage))-stageStart) < timeStampLikeLimit  && ...
          timeOffCounter < timeOffReportsMax 
      timeOffCounter = timeOffCounter + 1;
      disp([char(10), 'Received message: ', char(incomingMessage)]);
      disp([char(10), 'Message is timestamp-like but off, suggests a ',...
          'clock difference of ', num2str(str2double(char(incomingMessage))-stageStart), ...
          ' secs. Resending time packet and waiting.']);
      send(udpSocket, timeMessage);
  % if there was no incoming packet or it did not match timeMessage,
  % send timeMessage
  else
      send(udpSocket, timeMessage);
  endif
  % wait a bit before next iteration
  WaitSecs(waitTime);
endwhile

% Check for timeout
if ~successFlag
  disconnect(udpSocket);
  error('Handshake procedure timed out during second stage!');
endif


%% Get shared start time

sharedStartTime = (str2double(char(incomingMessage)) + stageStart)/2 + startDelay;
disp([char(10), 'Calculated shared start time, handshake successful!']);   
disp(['Start is at ', num2str(sharedStartTime, '%.5f'), ', current time is ', num2str(GetSecs, '%.5f')]);


%% Cleanup

disconnect(udpSocket); 
      
      
endfunction