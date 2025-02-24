%% Gaze categorization
%
% Read in the eye tracking info to identify what frames are task relevant
% and then display these to the user and have them categorize them. This
% shuffles trials and conditions. However, it groups trials that have the
% same response type.
%
% One necessary input is the coder name (initals). Critically this must have a number at the
% end, if not then this will break. This number corresponds to the
% interpolation condition. By default the coder will see every TR
% and this number in their name determines whether the coder sees odd
% numbers or even numbers. If you set this number to zero then the coder
% will see all frames
%
% The second necessary input is the participant name, allowing you to search in this
% folder
%
% An optional input: is the directory containing all of
% the participant folders which contain the eye tracking frames. 
%
% Coders will first be shown the eye tracking calibration, if available,
% and then categorize each frame according to a specific set of options.
%
% To add a new experiment you must edit $PROJ_DIR/scripts/Gaze_Categorization_Responses.m
%
% First created by C Ellis on 4/25/16
% Extensively edited by C Ellis on 7/4/16
% Added the window drawing C Ellis 06/01/17
% Added to infant_neuropipe 07/06/18

function Output=Gaze_Categorization(varargin)

if nargin==0
    Coder='Pilot_1';
    ParticipantName='160041'; 
else 
    Coder=varargin{1};
    ParticipantName=varargin{2};
end

% If the arguments are supplied then use them, otherwise default
if nargin>2
    Directory=varargin{3};
else
    Directory='../Frames/'; %Where is the folder containing images and where you want to save the gaze information
end

% ######## PARAMETERS YOU MIGHT WANT TO CHANGE ########

% BW camera settings
% Interpolation=2; %How many frames will you sample per participant. 5 and a rate of zero gives you approximately realtime
% Rate=10; %How many frames will you force to wait for in between frames (0 means (FrameRate*Interpolation)+ProcessingTime/60 speed)
% ScalingFactor=3; %How large is the image scaled to be
% TrialsperCalibrationDisplay=20; %How frequently will coders be given the opportunity to see the eye tracking calibration?
% VignetteSize=0.5; %What proportion of the image is shown (in the Y axis). 1 means all. 0.5 is appropriate for Princeton and MRRC, 0.1 is appropriate for BIC
% im_smoothing = 7; %Define Filtering here if you want to use it (use a odd integer). If you don't want filtering then set to zero.
% draw_window=1; % Do you want to draw a frame around the eye on some frames

Interpolation=1; %How many frames will you sample per participant. 5 and a rate of zero gives you approximately realtime
Rate=10; %How many frames will you force to wait for in between frames (0 means (FrameRate*Interpolation)+ProcessingTime/60 speed)
Speedup_rate = 0.75; % How much should the rate reduce on each held key press
Fast_frame_skip=Rate * (Speedup_rate .^ [20, 40]); % If not empty, this will skip a frame whenever the current rate is below the given number. The numbers in parentheses indicate the number of key presses held before it starts doing that many skips
ScalingFactor=2; %How large is the image scaled to be
TrialsperCalibrationDisplay=20; %How frequently will coders be given the opportunity to see the eye tracking calibration?
VignetteSize=0.3; %What proportion of the image is shown (in the Y axis). 1 means all. 0.5 is appropriate for Princeton and MRRC, 0.1 is appropriate for BIC
im_smoothing = 0; %Define Filtering here if you want to use it (use a odd integer). If you don't want filtering then set to zero.
draw_window=0; % Do you want to draw a frame around the eye on some frames

% What participants, if any, are rotated such that the frames came in at a
% different angle than expected. Specify here the participant name and the
% needed rotation to fix
Rotated_participants={'160011_1', 90;...
    '160011_2', 90;...  
    };
    
% #####################################################


Interpolation_Condition=str2double(Coder(end)); %What step of the interpolation will they be?

if Interpolation_Condition > 0
    if isnan(Interpolation_Condition) || Interpolation_Condition>Interpolation
        warning('An appropriate interpolation value was not provided. Aborting');
        return
    end
    
    % Start coding from frame 1
    starting_frame = Interpolation_Condition;
    
elseif Interpolation_Condition == 0
    fprintf('Using all frames');
    
    % Take every frame
    Interpolation = 1;
    
    % Start coding from frame 1
    starting_frame = 1;
    
else
    warning('An appropriate interpolation value was not provided. Aborting');
    return
end


%% Load in the participant

SaveName=['../Coder_Files/', ParticipantName, '_Coder_', Coder, '.mat'];

%Rotate images if the images were rotated
try
    Rotation=Rotated_participants{find(strcmp(Rotated_participants, ParticipantName)==1),2};
catch
    Rotation=0;
end

%% Load data if necessary
if exist(SaveName,'file')~=0
    
    %Print the question
    fprintf('Warning! Data file exists! Load it in (l), overwrite (o), or abort (a)?\n?:');
    
    %Wait for a valid response
    Response=2;%Reset
    Str='';
    while sum(Response)>=2 || isempty(strfind('loa',Str))
        [~, Response]=KbWait; %Wait for a response
        Str=KbName(Response); %What was the string entered?
    end
    
    fprintf('  %s\n\n', Str); %Output string
    
    if strcmp(Str,'l')
        fprintf('\nLoading...\n');
        load(SaveName);
        Loaded=1; %Have reloaded
        
    elseif strcmp(Str,'a')
        fprintf('\nAborting...\n');
        ListenChar(1);
        return
        
    elseif strcmp(Str,'o')
        fprintf('\nOverwriting...\n');
        Loaded=0; %Haven't reloaded
        
    end
    
else
    Loaded=0; %Haven't reloaded
end

%% Experiment definition:
% Load in variables that determine the response assignment and which
% options are available to participants.

% Add path to Gaze_Categorization_Responses
addpath ../../
Gaze_Categorization_Responses

% Set additional keys
AdjustUpKey='UpArrow';
AdjustDownKey='DownArrow';
RateKey='p'; % Toggle the presentation rate (accelerates over about 1s to top speed that images can possibly be shown)
IgnoreKey='n'; % if the trial is not going to be usable anyways or you want to code the whole trial as offscreen


%% Look through the files and find out how many people have coded it. If
%one or more people have coded this participant then point this out

SameParticipantCondition=length(dir(['../Coder_Files/', ParticipantName, '*', num2str(Interpolation_Condition), '*']));

%Remove one from the total if the participant file already exists
if exist(SaveName,'file')~=0
    SameParticipantCondition=SameParticipantCondition-1;
end

if SameParticipantCondition>0
    %Print the question
    fprintf('Warning! You have already collected %d coders for this participant and interpolation condition. Should you continue (c) or abort (a)?\n?:', SameParticipantCondition);
    
    %Print the ppts
    dir(['../Coder_Files/', ParticipantName, '*'])
    
    %Wait for a valid response
    Response=2;%Reset
    Str='';
    pause(.5); %Wait for a bit
    while sum(Response)>=2 || isempty(strfind('ca',Str))
        [~, Response]= KbWait; %Wait for a response
        Str=KbName(Response); %What was the string entered?
    end
    
    fprintf('  %s\n\n', Str); %Output string
    
    if strcmp(Str,'c')
        fprintf('\nContinuing...\n');
        
    elseif strcmp(Str,'a')
        fprintf('\nAborting...\n');
        ListenChar(1);
        return
        
    end
end

% Does the image list exist, if not then create it
ParticipantDir=[Directory, ParticipantName];
if exist([Directory, ParticipantName, '/ImageList.mat'])==0
    
    fprintf('Generating the Image list\n')
    generate_image_list(ParticipantDir);
    
end

%Load the image list and the associated necessary outputs
load([ParticipantDir, '/ImageList.mat']);

%% Set up the images to be presented to participants

if Loaded==0
    
    % Print an error if there is one
    if exist(['../Mat_Data/', ParticipantName, '.mat'])==0
        fprintf('Cannot find the experiment file for this participant. Add %s.mat from the experiment computer to ''../Mat_Data/''. Aborting\n', ParticipantName);
        return;
    end
       
    Temp=load(['../Mat_Data/', ParticipantName, '.mat'], 'Window', 'Data');
    Participant_Window=Temp.Window;
    Data=Temp.Data;
    
    % What is the eye tracker time when the experiment starts?
    StartTime_EyeTracker=(Data.Global.Timing.Start*EyeTrackerTime_slope) + EyeTrackerTime_intercept;
    
    % Load in an image
    image_dirs = dir([Directory, ParticipantName, '/eyeImages/']);
    ImageNames=strsplit(ls(sprintf('%s/%s/eyeImages/%s/*', Directory, ParticipantName, image_dirs(end).name)));
    img = imread(ImageNames{1});
    Dimensions=[size(img,1), size(img,2)]; % Dimensions of the images.
    
    %Initialize the vignette of the image to be shown
    if mod(Rotation/90,2)==1
        Dimensions=fliplr(Dimensions); %If the rotation is 90 degs or 270 degs then you need to rotate this
    end 
    DistanceFromBorder=(Dimensions(1)*ScalingFactor-round(Dimensions(1)*ScalingFactor*VignetteSize))/2;
    
    % Make a vignette of the image that is all of the X dim (after the
    % scaling) and some amount of the Y dim (also after scaling)
    ImageVignette=[0, DistanceFromBorder, Dimensions(2)*ScalingFactor, Dimensions(1)*ScalingFactor-DistanceFromBorder];
    
    %Initialize some variables
    Output.Timing={};
    Output.Window_Frame=struct;
    Output.EyeTrackerTime_slope=EyeTrackerTime_slope;
    Output.EyeTrackerTime_intercept=EyeTrackerTime_intercept;
    TrialCounter=1;
else
    % If the data was loaded in then give the option to start from a specific
    % trial
    
    %Print the question
    fprintf('Do you want to start from the last trial you got up to (trial: %d) or do you want to pick a different trial? Yes (y) if so, No (n) if not\n',TrialCounter);
    
    %Wait for a valid response
    Response=2;%Reset
    Str='';
    pause(.5); %Wait for a bit
    while sum(Response)>=2 || isempty(strfind('yn',Str))
        [~, Response]=KbWait; %Wait for a response
        Str=KbName(Response); %What was the string entered?
    end
    
    if strcmp(Str,'n')
        
        fprintf('Which trial would you like to start on:\n\n');
        
        % Cycle through the indexes
        counter = 1;
        for Index = Indexes
            fprintf('%d: %s Block_%d_%d Trial %d\n', counter, Index{1}{1}, Index{1}{2}, Index{1}{3}, Index{1}{4});    
            counter = counter + 1;
        end
        
        fprintf('Type the trial number and press enter\n');
        
        Str='';
        pause(.5); %Wait for a bit
        new_TrialCounter=inf;
        while 1
            
            keyIsDown = 0;
            while keyIsDown == 0
                [keyIsDown, ~, Response]=KbCheck; %Wait for a response
            end
            
            new_Str=KbName(Response); %What was the string entered?
            
            % If they press the return key then quit, otherwise append to a
            % string
            if strcmp(new_Str, 'Return')
                
                % Convert to a number
                new_TrialCounter = str2num(Str);
                
                % Check whether the trial number is acceptable
                if new_TrialCounter > 0 && new_TrialCounter <= length(Indexes)
                    
                    fprintf('Starting from trial %d\n', new_TrialCounter);
                    TrialCounter = new_TrialCounter;
                    break
                else
                    fprintf('Trial %d is not appropriate\n', new_TrialCounter);
                    Str='';
                end
            else
                Str=[Str, new_Str(1)];
            end
            
            % Wait until the key is not pressed
            while keyIsDown == 1
                keyIsDown=KbCheck;
            end
            
        end
    end

    
end


%% Display the stimuli

%Do screen set up stuff
Screen('Preference', 'SkipSyncTests', 1); %Timing doesn't matter
backColor = 100; %This is an arbitrary brightness but seems pleasant
textColor = 250;

% boilerplate
ListenChar(2);
GetSecs;

% platform-independent responses
KbName('UnifyKeyNames');

%% Set-up Display information

% open psychtoolbox screen
window=Open_Window;
Screen('TextSize',window.onScreen, 24);

%Iterate through the trials (Start from where you left off last if
%reloading
Current_Rate=Rate;
accelerate_enabled = 0;
accelerate_on = 0;
while TrialCounter <= length(Indexes)
    
    %Run a tutorial block with the eye tracking calibration data if it exists
    if isfield(Timing, 'EyeTrackerCalib') && ~isempty(Timing.EyeTrackerCalib{2,1,1,1}) && any(cellfun(@isempty, Timing.EyeTrackerCalib{2,1,1,1})==0) && mod(TrialCounter, TrialsperCalibrationDisplay)==1
        
        DrawFormattedText(window.onScreen, sprintf('This participant has an Eye tracking calibration.\n\nYou will now watch a demonstration in which the participant is probably looking towards the specified location.\n\nPress the %s and %s to adjacent up and down what part of the image you see.\n\nIf you want to skip then press ''s'' (or press ''s'' at any time to quit), otherwise press any other key to continue', AdjustUpKey, AdjustDownKey), 'center', 'center', uint8([255,255,255]), 70);
        Screen('Flip',window.onScreen);
        
        WaitSecs(1);
        [~, Response]=KbWait; %Wait for a response
        Str=KbName(Response); %What was the string entered?
        
        %iterate through the trials
        WarmUpTrialCounter=1;
        while WarmUpTrialCounter <= size(Timing.EyeTrackerCalib,3) && ~strcmp(Str, 's')
            
            %What is the message for this trial?
            Line=TrialType.EyeTrackerCalib{2,1,WarmUpTrialCounter};
            
            for Axis=['X','Y']
                
                % What is the coordinate Value
                StartingIdx=strfind(Line, sprintf('%s=', Axis))+2; %Get the indexes for the X value
                EndingIdx=min(strfind(Line(StartingIdx:end), '_')) + StartingIdx - 2;
                Value=str2num(Line(StartingIdx:EndingIdx)); %What is the coordinate
                
                %What are the positions of the X and Y
                Relative_Position = Value - Participant_Window.(sprintf('center%s', Axis));
                
                % Make the name for this axis
                if Value==Participant_Window.(sprintf('center%s', Axis))
                    Axis_Name.(Axis)='Center';
                else
                    if sign(Relative_Position)==-1
                        if strcmp(Axis, 'X'); Axis_Name.(Axis)='Left';
                        else Axis_Name.(Axis)='Up';
                        end
                    else
                        if strcmp(Axis, 'X'); Axis_Name.(Axis)=' Right';
                        else Axis_Name.(Axis)='Down';
                        end
                    end
                end
            end
            
            
            %Pull out the timing for this trial
            iTiming=Timing.EyeTrackerCalib{2, 1, WarmUpTrialCounter};
            
            %Play the trial on loop
            FrameCounter=1;
            CompletedOnce=0;
            while ~strcmp(Str, 's')
                
                %Try find the image name
                try
                    %What is the image name
                    ImageName=ls([Directory, ParticipantName, '/eyeImages/*/*', iTiming{FrameCounter}, '*']);
                    
                    %The last character is a return so remove that
                    ImageName=ImageName(1:end-1);
                    
                    ImageFound=1; %Image was found
                catch
                    %If there is no image found then skip, don't try display
                    %it
                    
                    ImageFound=0;
                    
                    %DrawFormattedText(window.onScreen, 'No Image Found', 'right', 'center', uint8([255,255,255]));
                end
                
                %Skip if no image was found
                if ImageFound==1
                    
                    %Read the image
                    iImage=imread(ImageName);
                    
                    % Convert the image to monochrome if it is not already
                    if size(iImage,3) > 1 && sum(sum(iImage(:, :, 1) - iImage(:, :, 2))) == 0
                        iImage = rgb2gray(iImage);
                    end
                    
                    %Flip the image (BE AWARE OF THE CONSEQUENCES)
                    iImage=fliplr(iImage);
                    
                    %Rotate the image if appropriate
                    iImage=rot90(iImage, Rotation/90);
                    
                    %Enlarge the image
                    iImage=imresize(iImage, ScalingFactor);
                    
                    if im_smoothing > 0
                        temp = zeros(size(iImage, 1), size(iImage, 2), size(iImage, 3));
                        for dim = 1:size(iImage, 3)
                            temp(:,:,dim) = medfilt2(iImage(:, :, dim), [im_smoothing im_smoothing]);
                        end
                        iImage = temp;
                    end
                    
                    %Display the image
                    iImageTex=Screen('MakeTexture', window.onScreen, iImage);
                    Screen('DrawTexture', window.onScreen, iImageTex, ImageVignette);
                    DrawFormattedText(window.onScreen, sprintf('This participant was looking toward the %s %s. ''s'' to stop demo.', Axis_Name.X, Axis_Name.Y), 'center', [], uint8([255,255,255]));
                    if CompletedOnce==1; DrawFormattedText(window.onScreen, sprintf('\n\nSpace to continue.'), 'center', [], uint8([255,255,255])); end
                    DrawFormattedText(window.onScreen, sprintf('%d: %d', WarmUpTrialCounter, FrameCounter),[],[],uint8([255,255,255]));
                    
                    if FrameCounter==1
                        imRect=size(iImage);
                        imRect=[window.centerX-(imRect(2)/2), window.centerY-(imRect(1)*VignetteSize/2), window.centerX+(imRect(2)/2), window.centerY+(imRect(1)*VignetteSize/2)];
                        
                        Screen('FrameRect', window.onScreen,uint8([255,0,0]), imRect, 5);
                        
                    end
                    
                    %Flip the screen
                    Screen('Flip',window.onScreen);
                    
                    %What is the key pressed?
                    [keyisDown, ~, keyCode]=KbCheck;
                    
                    % Respecify what the string is
                    Str=KbName(keyCode);
                    
                    %If there is a response then continue
                    if strcmp(Str, 'space') && CompletedOnce==1
                        break
                    elseif strcmp(Str, AdjustUpKey)
                        
                        %Don't go below zero
                        if ImageVignette(2)-10>0
                            ImageVignette([2, 4])=ImageVignette([2, 4])-10;
                        end
                        
                    elseif strcmp(Str, AdjustDownKey)
                        
                        %Dont exceed the image size
                        if ImageVignette(4)+10<=size(iImage,1)
                            ImageVignette([2, 4])=ImageVignette([2, 4])+10;
                        end
                    end
                end
                
                %Either increment the frame or start again
                if FrameCounter<=length(iTiming)
                    FrameCounter=FrameCounter+1; %Interpolation; %Don't use interpolation, go slower
                else
                    CompletedOnce=1;
                    FrameCounter=1;
                end
                
                
                
            end
            
            DrawFormattedText(window.onScreen, 'Next Trial', 'center', 'center', uint8([255,255,255]));
            Screen('Flip',window.onScreen);
            WaitSecs(.5);
            
            %Increment counter
            WarmUpTrialCounter=WarmUpTrialCounter+1;
            
            %Is this the last trial?
            if WarmUpTrialCounter == size(Timing.EyeTrackerCalib,3)+1
                
                %Display that they have finished
                DrawFormattedText(window.onScreen, 'You have finished the calibration and are ready for the actual data. \n\nPress ''r'' to re do it. Otherwise press anything else to continue.', 'center', 'center', uint8([255,255,255]));
                Screen('Flip',window.onScreen);
                
                %Listen for responses until you get
                
                [~,keyCode]=KbWait;
                if strcmp(KbName(keyCode), 'r')
                    WarmUpTrialCounter=1;
                end
            end
        end
    end
    
    
    % Run through the trial
    
    %Pull out the timing for this trial
    iTiming=Timing.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}};
    
    %Identify the frames, if found
    try
        Frames=ImageList.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}};
        
        %What frame are they
        FrameList=(starting_frame:Interpolation:length(Frames));
        
    catch
        FrameList=[];
    end
    
    
    %Pull out which category for this trial
    ResponseCategory=ResponseCategoryList(TrialCounter);
    
    %Show the text if it is appropriate
    if TrialCounter==1 || ResponseCategory~=ResponseCategoryList(TrialCounter-1)
        DrawFormattedText(window.onScreen, sprintf('Code which side of the image the participant is looking at.\n\n%s.\n\n Press the %s and %s to adjacent up and down what part of the image you see.\n\nPress any key to view', ResponseStr{ResponseCategory}, AdjustUpKey, AdjustDownKey), 'center', 'center', uint8([255,255,255]), 70);
        Screen('Flip',window.onScreen);
        
        pause(1);
        
        KbWait(); %Wait for a response
        
    end
    
    %Read through the frames
    FrameCounter=1;
    Response='';
    
    % Do you want to pick a frame for drawing (if you are picking one)
    if draw_window == 1
        Window_Drawing_Frame=ceil(rand()*length(FrameList)); % Which frame will participants draw the window on?
    else
        Window_Drawing_Frame = -1;
    end
    Trial_Start_time=GetSecs;
    while FrameCounter<=length(FrameList)
        
        %What frame were they actually shown on this trial
        iFrame=FrameList(FrameCounter);
        
        %Pull out the image name for this trial
        ImageName=ImageList.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}{iFrame};
        
        %Read the image
        iImage=imread([Directory, ParticipantName, '/', ImageName]);
        
        % Convert the image to monochrome if it is not already
        if size(iImage,3) > 1 && sum(sum(iImage(:, :, 1) - iImage(:, :, 2))) == 0
            iImage = rgb2gray(iImage);
        end
        
        %Flip the image (BE AWARE OF THE CONSEQUENCES)
        iImage=fliplr(iImage);

        %Rotate the image if appropriate
        iImage=rot90(iImage, Rotation/90);
        
        %Enlarge the image
        iImage=imresize(iImage, ScalingFactor);
        
        %smooth the image
        if im_smoothing > 0
            temp = zeros(size(iImage, 1), size(iImage, 2), size(iImage, 3));
            for dim = 1:size(iImage, 3)
                temp(:,:,dim) = medfilt2(iImage(:, :, dim), [im_smoothing im_smoothing]);
            end
            iImage = temp;
        end
        
        % Is this the frame they will be drawing the window for
        is_Drawing_Frame=FrameCounter==Window_Drawing_Frame;
        
        %% Collect coding responses
        
        %Display the image
        iImageTex=Screen('MakeTexture', window.onScreen, iImage);
        Screen('DrawTexture', window.onScreen, iImageTex, ImageVignette);
        DrawFormattedText(window.onScreen, ResponseStr{ResponseCategory}, 'center', [], uint8([255,255,255]));
        DrawFormattedText(window.onScreen, sprintf('%d: %d', TrialCounter, iFrame),[],[],uint8([255,255,255]));
        
        %If there are image instructions then print them
        try
            TempInstructions=ImageInstructions.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}{iFrame};
            DrawFormattedText(window.onScreen, TempInstructions,'left',window.screenY-50,uint8([255,255,255]));
        catch
        end
        
        %If you have previously coded this frame then display what you
        %previously coded
        if FrameCounter>1 && length(Output.Experiment.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}})>=iFrame
            PreviousResponse=Output.Experiment.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}{iFrame};
            DrawFormattedText(window.onScreen, sprintf('You previously coded: %s', PreviousResponse),'right',window.screenY-50,uint8([255,255,255]));
        end
            
        %Flip the screen
        Screen('Flip',window.onScreen, GetSecs+(Current_Rate*window.frameTime));
        
        %If this is the first frame then don't continue until there is a
        %key release
        if FrameCounter==1
            keyisDown=1;
            while keyisDown && ~strcmp(Response, AdjustUpKey) && ~strcmp(Response, AdjustDownKey)
                keyisDown=KbCheck;
            end
        end
        
        %Wait for a single response
        keyisDown = 0;
        Response={};
        while keyisDown == 0 || iscell(Response)
            [keyisDown, ~, keyCode, ~] = KbCheck;
            
            % If they let go of the key then stop accelerating (only does
            % anything if the accelerate setting is on)
            if keyisDown == 0
                accelerate_on = 0;
            end
            
            Response=KbName(keyCode);
        end
        
        %Store the input if appropriate
        original_FrameCounter = FrameCounter;
        if any(strcmp(ResponseAllowed{ResponseCategory}, Response))
            
            %Store the output. The indexes are a cell containing: ExperimentName, BlockNumber, RepetitionNumber, TrialCounter
            Output.Experiment.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}{iFrame}=Response;
            
            %Store the response as the time since the experiment started
            TimesinceStart=(str2double(iTiming{iFrame})-StartTime_EyeTracker)/Output.EyeTrackerTime_slope;
            Output.Timing.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}{iFrame}= {TimesinceStart, Response};
            
            %What are the indexes for the trial to start
            Output.Indexes.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}{iFrame}={Indexes{TrialCounter}, iFrame};
            
            %Store the vignette window
            Output.Vignette.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}(iFrame,:)=ImageVignette;
            
            %Increment
            FrameCounter=FrameCounter+1;
            %Trial
             
        % decide to ignore the rest of the trial     
        elseif strcmp(Response, IgnoreKey)
            
            % cycle through the remaining frames
            for tempFrameCounter=FrameCounter:length(FrameList)
                iFrame =FrameList(tempFrameCounter);
                %Store the output. The indexes are a cell containing: ExperimentName, BlockNumber, RepetitionNumber, TrialCounter
                Output.Experiment.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}{iFrame}='space';
                
                %Store the response as the time since the experiment started
                TimesinceStart=(str2double(iTiming{iFrame})-StartTime_EyeTracker)/Output.EyeTrackerTime_slope;
                Output.Timing.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}{iFrame}= {TimesinceStart, 'space'};
                
                %What are the indexes for the trial to start
                Output.Indexes.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}{iFrame}={Indexes{TrialCounter}, iFrame};
                
                %Store the vignette window
                Output.Vignette.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}(iFrame,:)=ImageVignette;
                
                %Store that this was skipped 
                Output.SkippedFrames.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}(iFrame,:)=1;
                
            end
            
            % now say that you made it to the end
            FrameCounter=tempFrameCounter;
        
        elseif strcmp(Response, BackKey) && FrameCounter>1
            
            %Are you going backwards
            FrameCounter=FrameCounter-1;
            
        elseif strcmp(Response, BackKey) && FrameCounter==1 && TrialCounter>1
            
            %If they press the b key to back to the end of the last trial
            %then go back a trial
            
            TrialCounter=TrialCounter-1;
            
            %Pull out which category for this trial
            ResponseCategory=ResponseCategoryList(TrialCounter);
            
            %Pull out the information from the last trial
            iTiming=Timing.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}};
            Frames=ImageList.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}};
            FrameList=(starting_frame:Interpolation:length(Frames));
            
            %Start on the last trial (pick the last frame)
            FrameCounter=length(FrameList);
            
        elseif strcmp(Response, 'q')
            
            %Issue a message
            DrawFormattedText(window.onScreen, 'Are you sure you want to quit? Press ''y'' to confirm', 'center', 'center',uint8([255,255,255]));
            
            %Flip the screen
            Screen('Flip',window.onScreen);
            
            pause(.5);
            
            %Wait for a single response
            Response={};
            while iscell(Response)
                [~, keyCode, ~] = KbWait;
                Response=KbName(keyCode);
            end
            
            % Quit the experiment
            if strcmp(Response, 'y')
                %Store the coding up to here
                save(SaveName);
                ListenChar(1);
                sca;
                return
            end
            
        elseif strcmp(Response, AdjustUpKey)
            
            %Don't go below zero
            if ImageVignette(2)-10>0
                ImageVignette([2, 4])=ImageVignette([2, 4])-10;
            end
                
        elseif strcmp(Response, AdjustDownKey)
            
            %Dont exceed the image size
            if ImageVignette(4)+10<=size(iImage,1)
                ImageVignette([2, 4])=ImageVignette([2, 4])+10;
            end
        elseif strcmp(Response, RateKey)
            
            % Toggle to turn on or off rate acceleration (any time you let
            % go of the key the rate returns to zero
            accelerate_enabled = 1 - accelerate_enabled;
            
            % Update the current rate and whether acceleration is happening
            % right now
            if accelerate_enabled == 0
                Current_Rate = Rate;
            else
                accelerate_on = 1;
            end
            
            % So that it doesn't flip
            pause(0.2);
            
         else
            % If they aren't pressing one of the relevant keys the stop
            % accelerating
            accelerate_on = 0;   
        end
        
        % If the responses are set to accelerate then update the rate here
        if accelerate_enabled == 1 && accelerate_on == 1
            
            % Reduce the rate
            Current_Rate = Current_Rate * Speedup_rate;
            
            %DrawFormattedText(window.onScreen, 'Accelerating', 'right', [], uint8([255,255,255]));
                    
            % If enabled then this will skip this number of frames when
            % going fast
            for frame_skip = 1:sum(Fast_frame_skip > Current_Rate)
                if FrameCounter<=length(FrameList)
                    
                    % Change counter
                    if strcmp(Response, BackKey) && FrameCounter>1
                        
                        %Are you going backwards
                        FrameCounter=FrameCounter-1;
                    elseif any(strcmp(ResponseAllowed{ResponseCategory}, Response))
                        % Get the frame counter
                        iFrame=FrameList(FrameCounter);
                        
                        %Store the output. The indexes are a cell containing: ExperimentName, BlockNumber, RepetitionNumber, TrialCounter
                        Output.Experiment.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}{iFrame}=Response;
                        
                        %Store the response as the time since the experiment started
                        TimesinceStart=(str2double(iTiming{iFrame})-StartTime_EyeTracker)/Output.EyeTrackerTime_slope;
                        Output.Timing.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}{iFrame}= {TimesinceStart, Response};
                        
                        %What are the indexes for the trial to start
                        Output.Indexes.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}{iFrame}={Indexes{TrialCounter}, iFrame};
                        
                        %Store the vignette window
                        Output.Vignette.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}(iFrame,:)=ImageVignette;
                        
                        %Increment
                        FrameCounter=FrameCounter+1;
                    end
                    
                end
                
            end
            
            else
            % Reset the rate to baseline
            Current_Rate = Rate;
            
            % After having reset the rate, return this to on so that if
            % they press again while acceleration is enabled it will be
            % counted
            accelerate_on = 1;
        end
        
        %% Are they drawing the window on this frame?
        if is_Drawing_Frame
            
            % Has this already been drawn?
            try
               Already_Drawn=~isempty(Output.Window_Frame.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}});
            catch
                Already_Drawn=0;
            end
            
            if Already_Drawn==0
                %Store the frame you are drawing the window on
                Output.Window_Frame.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}=iFrame;
                
                DrawFormattedText(window.onScreen, 'Draw the window around the eyes', 'center', 'center', uint8([255,255,255]), 70);
                Screen('Flip',window.onScreen);
                WaitSecs(.5);
                
                %Display the image
                iImageTex=Screen('MakeTexture', window.onScreen, iImage);
                Screen('DrawTexture', window.onScreen, iImageTex, ImageVignette);
                DrawFormattedText(window.onScreen, 'Draw windows around the eyes. Click and drag. Press ''r'' to reset, press ''enter'' to continue', 'center', [], uint8([255,255,255]));
                %Flip the screen
                Screen('Flip',window.onScreen);
                
                enter_key=0;
                ShowCursor(5); %Make it a cross that is being shown
                eye_rects={};
                eye_rect_coordinates={};
                print_rects={};
                while enter_key==0
                    
                    %SetMouse(Pos_X, Pos_Y,window.onScreen); %Set mouse to Position
                    
                    % Get the mouse positions
                    [x,y,buttons] = GetMouse(window.onScreen);
                    
                    % When they click
                    if buttons(1)
                        
                        firstclick=[x,y];
                        
                        while buttons(1)
                            
                            % Get the mouse position
                            [x,y,buttons] = GetMouse(window.onScreen);
                            currentposition=[x,y];
                            
                            % Make sure they aren't identical
                            if all(firstclick==currentposition);
                                currentposition=currentposition+1;
                            end
                            
                            %Find the rectangle of the box to be drawn
                            minX=min([firstclick(1),currentposition(1)]);
                            maxX=max([firstclick(1),currentposition(1)]);
                            minY=min([firstclick(2),currentposition(2)]);
                            maxY=max([firstclick(2),currentposition(2)]);
                            eye_rect=[minX, minY, maxX, maxY];
                            
                            %Display the image
                            iImageTex=Screen('MakeTexture', window.onScreen, iImage);
                            Screen('DrawTexture', window.onScreen, iImageTex, ImageVignette);
                            DrawFormattedText(window.onScreen, 'Draw windows around the eyes. Click and drag. Press ''r'' to reset, press ''enter'' to continue', 'center', [], uint8([255,255,255]));
                            Screen('FrameRect', window.onScreen, [], eye_rect);
                            
                            %Draw past rects
                            for counter=1:length(eye_rects)
                                Screen('FrameRect', window.onScreen, [], eye_rects{counter});
                            end
                            %Flip the screen
                            Screen('Flip',window.onScreen);
                            
                        end
                        
                        eye_rects{end+1}=eye_rect;
                        
                        %Convert the eye rect into the coordinate space of
                        %the image. This rect is in image space (top left
                        %corner of the display). To fix this, recenter the
                        %origin to the top left corner of the image (using
                        %the image vignette as the reference.
                        
                        Image_Width=ImageVignette(3)-ImageVignette(1);
                        Image_Height=ImageVignette(4)-ImageVignette(2);
                        
                        x_origin=window.centerX-(Image_Width/2);
                        y_origin=window.centerY-(Image_Height/2)-ImageVignette(2);
                        
                        % Reframe this
                        temp=[];
                        temp([1,3])=eye_rect([1,3])-x_origin;
                        temp([2,4])=eye_rect([2,4])-y_origin;
                        
                        % Bound all coordinates
                        
                        temp(temp<1)=1;
                        if temp(1)>size(iImage,2)
                            temp(1)=size(iImage,2);
                        end
                        if temp(2)>size(iImage,1)
                            temp(2)=size(iImage,1);
                        end
                        if temp(3)>size(iImage,2)
                            temp(3)=size(iImage,2);
                        end
                        if temp(4)>size(iImage,1)
                            temp(4)=size(iImage,1);
                        end
                        
                        % Store this for displaying later
                        print_rects{end+1}=temp;
                        
                        % Reshape these coordinates (based on their
                        % distortion)
                        
                        temp([3,1])= Image_Width - temp([1,3]);
                        
                        %Rotate the coordinates if appropriate
                        if Rotation~=0
                            
                            v=[temp([1,3]); temp([2,4])];
                            
                            % What is the centre of rotation
                            x_center = Image_Width/2;
                            y_center = Image_Height/2;
                            % Store for later 
                            center = repmat([x_center; y_center], 1, 2);
                            theta = 2 * pi / Rotation;       
                            R = [cos(theta) -sin(theta); sin(theta) cos(theta)];
                            % do the rotation...
                            s = v - center;     % shift points in the plane so that the center of rotation is at the origin
                            so = R*s;           % apply the rotation about the origin
                            vo = so + center;   % shift again so the origin goes back to the desired center of rotation
                            
                            % Store points again
                            temp = [vo(1,1), vo(2,1), vo(1,2), vo(2,2)];
                        end
                        
                        %Downsize the image
                        temp=temp/ScalingFactor;
                        
                        % Round and save
                        temp=round(temp);
                        eye_rect_coordinates{end+1}=temp;
                        
                    end
                    
                    
                    %Wait for a single response
                    Response={};
                    while iscell(Response)
                        [~, ~, keyCode, ~] = KbCheck;
                        Response=KbName(keyCode);
                    end
                    
                    if strcmp(Response, 'r')
                        eye_rects={};
                        eye_rect_coordinates={};
                        print_rects={};
                        iImageTex=Screen('MakeTexture', window.onScreen, iImage);
                        Screen('DrawTexture', window.onScreen, iImageTex, ImageVignette);
                        DrawFormattedText(window.onScreen, 'Draw windows around the eyes. Click and drag. Press ''r'' to reset, press ''enter'' to continue', 'center', [], uint8([255,255,255]));
                        %Flip the screen
                        Screen('Flip',window.onScreen);
                    elseif strcmp(Response, 'Return')
                        
                        %Store the frame you are drawing the window on
                        Output.Window_Frame.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}=eye_rect_coordinates;
                        
                        %Save an image with these properties
                        
                        for counter = 1:length(eye_rect_coordinates)
                        
                            temp=print_rects{counter};
                            temp=round(temp);
                            
                            % Make the box
                            temp_image = zeros(size(iImage,1), size(iImage,2));
                            temp_image(temp(2):temp(4),[temp(1),temp(3)]) = 256;
                            temp_image([temp(2),temp(4)],temp(1):temp(3)) = 256;
                            
                            %Put the image overtop
                            iImage = uint16(iImage);
                            for dim = 1:size(iImage,3)
                                iImage(:, :, dim)=uint16(temp_image) + iImage(:, :, dim);
                            end
                        end
                        
                        %Save image
                        Output_name=sprintf('../Eye_Apertures/%s_%s_%d_%d_%d_%d_%s_%s.png', ParticipantName, Indexes{TrialCounter}{1}, Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}, iFrame, iTiming{original_FrameCounter}, Coder);
                        imwrite(iImage, Output_name);
                        
                        enter_key=1;
                    end
                    
                end
                % Hide cursor
                HideCursor;
            end
        end
        
        % Release the frames
        Screen('Close')
    end
    
    DrawFormattedText(window.onScreen, sprintf('%d/%d', TrialCounter,  length(Indexes)), 'center', 'center', uint8([255,255,255]), 70);
    Screen('Flip',window.onScreen);
    WaitSecs(.5);
    
    % Record how long it took the coder to complete each trial
    Output.Trial_duration.(Indexes{TrialCounter}{1}){Indexes{TrialCounter}{2}, Indexes{TrialCounter}{3}, Indexes{TrialCounter}{4}}=GetSecs - Trial_Start_time;
    
    %Increment
    TrialCounter=TrialCounter+1;
    
    %Store the coding up to here
    save(SaveName);
end

%Finish up
ListenChar(1);
sca;

% Store the participant
Analyse_Coder_Results(ParticipantName);





