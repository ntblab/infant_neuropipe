% Replay the eye tracking data as it was played to the coders
%
% This takes several inputs:
% EyeData:
%
% Either the EyeData struct (outputted from Analysis_Timing) or
% the mat file path to the same struct. This contains the necessary
% information to interpret the coders
%
% ParticipantName:
%
% What is the participant name?
%
% Image_Directory:
%
% What is the directory containing all of the relevant images?
%
% Key presses that can be pressed during replay:
%
% Jump between events: s=skip, DELETE=back, q=back to experiments
% Change speed: Arrow keys- Left=Rewind, Right=Fastforward, Up=Speed up, Down=Slow down, Space=pause
% Hide worm: 'h'
% Change coder: 'c'
% 
% Record this trial, output to the ../Coder_movies/ folder: 'r'
%
function Gaze_Categorization_Replay(EyeData, ParticipantName, Image_Directory)

%Default to load this data
if nargin==0
    EyeData='~/Desktop/EyeData.mat';
end

if nargin < 2
    ParticipantName='160081';
end

if nargin < 3
    Image_Directory='../Frames/';
end

%If this is a string then load this data
if isstr(EyeData)
    load(EyeData)
end

%Load the data
Temp=load(sprintf('../Mat_Data/%s.mat', ParticipantName), 'Data', 'GenerateTrials', 'Window');
Data=Temp.Data;
GenerateTrials=Temp.GenerateTrials;
Participant_Window=Temp.Window;

% Do you want to make and save a movie of what you see?
save_movie=0;
movie_folder = '../Coder_movies/'; % Where do you want to save movies?
recording_type = 0; % Do you want to save as a movie (1) or as individual frames (0)? The latter is slow but much higher quality.

%% Experiment definition:

ScalingFactor=3; %How large is the image scaled to be
FrameWait=0.1; %How long should you wait for frames, as a default

% Add path to Gaze_Categorization_Responses
addpath ../../
Gaze_Categorization_Responses
ResponseNum=length(key_code_mapping);

%Extract information
ImageList=EyeData.ImageList;
Experiments=fieldnames(EyeData.Aggregate);

%Remove the block suffix from some of them
for ExperimentCounter = 1:length(Experiments)
    if strfind(Experiments{ExperimentCounter}, '_Block_')
        Experiments_clean{ExperimentCounter}=Experiments{ExperimentCounter}(1:strfind(Experiments{ExperimentCounter}, '_Block_')-1);
    else
        Experiments_clean{ExperimentCounter}=Experiments{ExperimentCounter};
    end
end

Temp=sprintf('Which experiment do you want to look at:\n\n');

for Experiment_Counter=1:length(Experiments)
    
    Temp = [Temp, sprintf('%d: %s\n', Experiment_Counter, Experiments{Experiment_Counter})];
    
end

Menu_Text = [Temp, sprintf('\nType in the choice. Delete to remove character, enter to submit.\n ''q'' to quit')];

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


% Set up the menu
CoderCounter=0;
while 1
    
    %Display instructions
    DrawFormattedText(window.onScreen, Menu_Text, [], [], uint8([255,255,255]));
    Screen('Flip',window.onScreen);
    
    %Get a valid response and infer what experiment is selected
    Experiment_Counter=[];
    Temp='';
    while isempty(Experiment_Counter)
        
        %Store the key code
        [~, keycode]=KbWait();
        Response=KbName(keycode);
        
        Temp(end+1)=Response(1); %Append number to the response list
        
        if length(Experiments)>9
            if length(Temp)==2
                Experiment_Counter=str2num(Temp);
                
            elseif strcmp(Temp(end), 'R') %If return the finish
                Experiment_Counter=str2num(Temp(1));
                
            elseif strcmp(Temp(end), 'D') %If delete then remove character
                Temp=Temp(1:end-1);
                
            elseif strcmp(Temp(end), 'q') %If quit
                
                sca
                return
                
            end
            
            %Reset the character
            if isempty(Experiment_Counter) || length(Temp)>2
                Temp='';
            end
            
        else
            
            if strcmp(Temp, 'q') %If quit
                sca
                return
            end
            
            Experiment_Counter=str2num(Temp);
            
            %Reset, regardless
            Temp='';
            
        end
    end
    
    
    %What are the idx names for this experiment
    Idx_Names=EyeData.Idx_Names.(Experiments{Experiment_Counter});
    
    %Iterate through the Idxs
    Idx_Counter=1;
    Quit=0;
    ShowWorm=1;
    while Idx_Counter<=size(Idx_Names, 1) && Quit==0
        
        iData=Data.(sprintf('Experiment_%s', Experiments_clean{Experiment_Counter})).(sprintf('Block_%d_%d', Idx_Names(Idx_Counter,1), Idx_Names(Idx_Counter,2)));
        
        %What frames are to be presented for this event
        Frames=ImageList.(Experiments{Experiment_Counter}){Idx_Names(Idx_Counter,1), Idx_Names(Idx_Counter,2),Idx_Names(Idx_Counter,3)};
        
        %What is the block name
        BlockName=GenerateTrials.(sprintf('Experiment_%s', Experiments_clean{Experiment_Counter})).Parameters.BlockNames{Idx_Names(Idx_Counter,1)};
        
        %Find the event names
        if strcmp(Experiments{Experiment_Counter}, 'EyeTrackerCalib')
            
            %What is the origin of the eye tracker stim?
            Origin=iData.Stimuli.Origin(Idx_Names(Idx_Counter,3),:);
            
            if Origin(1)<Participant_Window.centerX
                Pos_Lateral='Left';
            elseif Origin(1)>Participant_Window.centerX
                Pos_Lateral='Right';
            else
                Pos_Lateral='Middle';
            end
            
            if Origin(2)<Participant_Window.centerY
                Pos_Longitudinal='Up';
            elseif Origin(2)>Participant_Window.centerY
                Pos_Longitudinal='Down';
            else
                Pos_Longitudinal='Middle';
            end
            
            EventName=sprintf('X: %0.0f (%s), Y: %0.0f (%s)', Origin(1), Pos_Lateral,  Origin(2), Pos_Longitudinal);
            
        elseif strcmp(Experiments{Experiment_Counter}, 'MemTest')
            %Pull out the new stim location (either with reference to
            %generate trials or data)
            
            Position={'Left', 'Right'};
            if isfield(iData, 'NewStim')
                
                %If NewStim is a field then use Data
                New_Position=iData.NewStim(Idx_Names(Idx_Counter,3));
            else
                
                %If not then use GenerateTrials
                New_Position=GenerateTrials.(sprintf('Experiment_%s', Experiments_clean{Experiment_Counter})).Stimuli.New_Position(Idx_Names(Idx_Counter,3),1);
            end
            
            %What is the name
            EventName=sprintf('New is on the %s', Position{New_Position});
            
        else
            EventName='Unspecified Event';
        end
        
        %Pull out the relevant eye coding data (0 means the aggregate)
        
        if CoderCounter==0
            Timecourse=EyeData.Timecourse.(Experiments{Experiment_Counter}){Idx_Counter};
            OtherCoders_Timecourse=Timecourse; % Duplicate it to ignore
            num_coders=1;
        else
            Timecourse=EyeData.Aggregate.(Experiments{Experiment_Counter}){Idx_Counter}(CoderCounter,:);
            
            % Get the other coders
            num_coders=size(EyeData.Aggregate.(Experiments{Experiment_Counter}){Idx_Counter},1);
            OtherCoders_Timecourse=EyeData.Aggregate.(Experiments{Experiment_Counter}){Idx_Counter}(setdiff(1:num_coders, CoderCounter),:);
            
            % If the timecourse is empty then warn the user and show
            % another coder
            if isempty(Timecourse) || isempty(Timecourse(~isnan(Timecourse)))
                DrawFormattedText(window.onScreen, sprintf('No data found for coder %s, skipping', EyeData.Coder_name{CoderCounter}), 'center', 'center', uint8([255 0 0]));
                Screen('Flip', window.onScreen);
                pause(1);
                
                CoderCounter=CoderCounter+1;
                Timecourse=EyeData.Aggregate.(Experiments{Experiment_Counter}){Idx_Counter}(CoderCounter,:);
            end
            
        end
        
        %Only take the non nan items
        Timecourse_Squeeze=Timecourse(~isnan(Timecourse));
        OtherCoders_Timecourse_Squeeze=OtherCoders_Timecourse(:, ~isnan(Timecourse));
        
        %Where are the line starts and ends?
        LinePoints=[];
        Other_LinePoints_temp=[];
        Other_LinePoints=[];
        for FrameCounter=1:length(Timecourse_Squeeze)-1
            
            idx = size(LinePoints, 2);
            LinePoints(:, idx+1:idx+2)=[FrameCounter, FrameCounter+1; Timecourse_Squeeze(FrameCounter),  Timecourse_Squeeze(FrameCounter+1)]; %Start xy and end xy
            
            for temp_CoderCounter = 1:num_coders-1
                Other_LinePoints_temp(:, idx+1:idx+2, temp_CoderCounter)=[FrameCounter, FrameCounter+1; OtherCoders_Timecourse_Squeeze(temp_CoderCounter, FrameCounter),  OtherCoders_Timecourse_Squeeze(temp_CoderCounter, FrameCounter+1)]; %Start xy and end xy
            end
        end
        
        %Have a starting point
        LinePoints=[1, 1, LinePoints(1,:); Timecourse_Squeeze(1), Timecourse_Squeeze(1), LinePoints(2,:)];
        for temp_CoderCounter = 1:num_coders-1
            Other_LinePoints(:, :, temp_CoderCounter)=[1, 1, Other_LinePoints_temp(1,:,temp_CoderCounter); OtherCoders_Timecourse_Squeeze(temp_CoderCounter, 1), OtherCoders_Timecourse_Squeeze(temp_CoderCounter, 1), Other_LinePoints_temp(2,:,temp_CoderCounter)];
        end
        
        %Display the eye tracking worm
        WormWindow=100;
        BackgroundWidth=300;
        BackgroundHeight=200;
        Worm_Origin=[window.centerX, window.screenY-BackgroundHeight/2 - 20];
        
        %What is the background dimensions
        WormRect=[Worm_Origin(1)-BackgroundWidth/2 - 40, Worm_Origin(2)-BackgroundHeight/2 - 20, Worm_Origin(1)+BackgroundWidth/2 + 20, Worm_Origin(2)+BackgroundHeight/2 + 20];
        
        % Compute the frames per second of the clip

        example_timestamps = [];
        for FrameCounter = 1:length(Frames)
            % Get the frame name
            iFrame = Frames{FrameCounter};
            
            % Get the timing
            timestamps = str2num(iFrame((max(strfind(iFrame, '_')) + 1):(max(strfind(iFrame, '.')) -1)));
            
            % Convert timestamp to seconds and append
            example_timestamps(end+1) = timestamps / 1e6;
            
        end
        
        % Get the median difference and use that as the frame rate
        camera_fps = round(1 / median(diff(example_timestamps)));
    
        %Iterate through the videos
        FrameCounter=1;
        recording_movie = 0; %Assume no on every trial
        while FrameCounter <=length(Frames)
            
            %Skip if it is a frame this coder didn't see
            if length(Timecourse) >= FrameCounter && ~isnan(Timecourse(FrameCounter))
                
                % Record the movie 
                if save_movie && recording_movie == 0
                    
                    % What coder are you using
                    if CoderCounter > 0
                        Coder_Name = EyeData.Coder_name{CoderCounter};
                    else
                        Coder_Name = 'aggregate';
                    end
                    
                    % Get the movie_name
                    if recording_type == 1
                        movie_name=sprintf('%s/%s_%s_%d_%d_%d_%s.avi', movie_folder, ParticipantName, Experiments{Experiment_Counter}, Idx_Names(Idx_Counter,1), Idx_Names(Idx_Counter,2), Idx_Names(Idx_Counter,3), Coder_Name);
                        
                        movieptr=Screen('CreateMovie', window.onScreen, movie_name, [], [], camera_fps);
                        
                    else
                        frame_dir = sprintf('%s/%s_%s_%d_%d_%d_%s/', movie_folder, ParticipantName, Experiments{Experiment_Counter}, Idx_Names(Idx_Counter,1), Idx_Names(Idx_Counter,2), Idx_Names(Idx_Counter,3), Coder_Name);
                        mkdir(frame_dir);
                    end
                    
                    % You are recording the movie now
                    recording_movie = 1;
                end

                
                %Read the image
                iImage=imread([Image_Directory, ParticipantName, '/', Frames{FrameCounter}]);
                
                % Convert the image to monochrome if it is not already
                if size(iImage,3) > 1 && sum(sum(iImage(:, :, 1) - iImage(:, :, 2))) == 0
                    iImage = rgb2gray(iImage);
                end
                
                %Flip the image (BE AWARE OF THE CONSEQUENCES)
                iImage=fliplr(iImage);
                
                %Enlarge the image
                %iImage=imresize(iImage, ScalingFactor);
                
                iImageTex=Screen('MakeTexture', window.onScreen, iImage);
                Screen('DrawTexture', window.onScreen, iImageTex);
                if CoderCounter>0
                    DrawFormattedText(window.onScreen, sprintf('%s: %s, repetition %d, %s.\nCoder %s', Experiments{Experiment_Counter}, BlockName, Idx_Names(Idx_Counter,2), EventName, EyeData.Coder_name{CoderCounter}), [],[], uint8([255 0 0]));
                else
                    DrawFormattedText(window.onScreen, sprintf('%s: %s, repetition %d, %s.\nTimecourse of all participants', Experiments{Experiment_Counter}, BlockName, Idx_Names(Idx_Counter,2), EventName), [],[], uint8([255 0 0]));
                end
                %Display only the last X frames
                Non_nan=~isnan(Timecourse); %What are the real numbers for this timecourse?
                
                WormIdxs=(sum(Non_nan(1:FrameCounter))-WormWindow)*2+1:sum(Non_nan(1:FrameCounter))*2;
                WormIdxs=WormIdxs(WormIdxs>0);
                
                %Rescale and place the lines where they ought to be
                Lines=LinePoints(:,WormIdxs);
                OtherLines=[];
                if ~isempty(Other_LinePoints)
                    for temp_CoderCounter = 1:num_coders-1
                        OtherLines(:, :, temp_CoderCounter)=Other_LinePoints(:, WormIdxs, temp_CoderCounter);
                    end
                else
                    OtherLines=Lines;
                end
                
                %Change the scale and re align
                Lines(1,:)=((Lines(1,:) - Lines(1,1))*BackgroundWidth/WormWindow) +Worm_Origin(1)-BackgroundWidth/2;
                Lines(2,:)=(Lines(2,:)*BackgroundHeight/ResponseNum) + Worm_Origin(2) - (BackgroundHeight/2); %Because of the 6 responses
                
                for temp_CoderCounter = 1:num_coders-1
                    OtherLines(1,:,temp_CoderCounter)=((OtherLines(1,:,temp_CoderCounter) - OtherLines(1,1,temp_CoderCounter))*BackgroundWidth/WormWindow) +Worm_Origin(1)-BackgroundWidth/2;
                    OtherLines(2,:,temp_CoderCounter)=(OtherLines(2,:,temp_CoderCounter)*BackgroundHeight/ResponseNum) + Worm_Origin(2) - (BackgroundHeight/2); %Because of the 6 responses
                end
                
                %Draw the elements
                if ShowWorm==1
                    Screen('FillRect', window.onScreen, uint8([255,255,255]), WormRect);
                    for temp_CoderCounter = 1:num_coders-1
                        Screen('DrawLines', window.onScreen, OtherLines(:,:,temp_CoderCounter), 5, uint8([125,125,125]));
                    end
                    Screen('DrawLines', window.onScreen, Lines, 5, uint8([255,0,0]));
                    
                    Screen('TextSize', window.onScreen, 8);
                    
                    for response_counter = 1:length(ResponseNames)
                        Screen('DrawText', window.onScreen, ResponseNames{response_counter},   (Worm_Origin(1)-BackgroundWidth/2 - 35), (Worm_Origin(2) - (BackgroundHeight/2) +(BackgroundHeight/ResponseNum * (response_counter - 1))), uint8([0 0 0]));
                    end
                    
                    Screen('TextSize', window.onScreen, 24);
                end
                
                %Flip
                FlipTime=GetSecs+FrameWait;
                Screen('Flip',window.onScreen, FlipTime);
                
                % Record the movie if so specified
                if recording_movie == 1
                    
                    if recording_type == 1
                        Screen('AddFrameToMovie', window.onScreen);
                    else
                        % Store the frames
                        output_frame = sprintf('%s/%d.png', frame_dir, FrameCounter);
                        imwrite(Screen('GetImage', window.onScreen), output_frame);
                        
                    end
                end
            end
            
            %Check for response
            Response='';
            [keyisDown, ~,  keyCode] = KbCheck;
            if keyisDown==1 && sum(keyCode)==1
                Response=KbName(keyCode);
            end
            
            %Interprete the key presses
            if strcmp(Response, 'q')
                Quit=1;
                break
                
            elseif strcmp(Response, 's')
                %Skip
                break
                
            elseif strcmp(Response, 'DELETE') || strcmp(Response, 'b')
                %Go back
                Idx_Counter=Idx_Counter-2;
                
                Idx_Counter(Idx_Counter<0)=0;
                break
                
            elseif strcmp(Response, 'space')
                %Pause
                pause(0.2);
                KbWait();
                
            elseif strcmp(Response, 'LeftArrow')
                %Go back a frame
                FrameCounter=FrameCounter-2;
                
                %Make the minimum one (after you have added the one
                %automatically
                FrameCounter(FrameCounter<0)=0;
                
            elseif strcmp(Response, 'RightArrow')
                %Go forward a frame
                FrameCounter=FrameCounter+1;
                
            elseif strcmp(Response, 'UpArrow')
                %Speed up the frames
                FrameWait=FrameWait-0.05;
                
                %Floor
                FrameWait(FrameWait<0)=0;
            elseif strcmp(Response, 'DownArrow')
                
                %Slow down the frames
                FrameWait=FrameWait+0.05;
                
                %Ceiling
                FrameWait(FrameWait>1)=1;
                
            elseif strcmp(Response, 'h')
                %Flip
                ShowWorm=1-ShowWorm;
                pause(0.1);
                
            elseif strcmp(Response, 'c')
                
                %Change coder and restart this event
                
                CoderCounter=CoderCounter+1;
                
                %If you exceed the number present then reset to zero
                num_coders=size(EyeData.Aggregate.(Experiments{Experiment_Counter}){Idx_Counter},1);
                CoderCounter(num_coders<CoderCounter)=0;
                
                Idx_Counter=Idx_Counter-1;
                
                Idx_Counter(Idx_Counter<0)=0;
                break
                
            elseif strcmp(Response, 'r')
                %Toggle recording
                
                % Flip whether recording is happening
                save_movie = 1 - save_movie;
                
                % If you are recording the movie now then stop
                if recording_movie == 1
                    if recording_type == 1
                        Screen('FinalizeMovie', movieptr);
                    end
                    recording_movie = 0;
                else
                    
                    % Restart this trial if you are turning recording on
                    Idx_Counter=Idx_Counter-2;
                    
                    Idx_Counter(Idx_Counter<0)=0;
                    break
                end
                
            end
            
            
            FrameCounter=FrameCounter+1;
        end
        
         % Store the movie
         if recording_movie == 1
             
             % Finalize the movie
             if recording_type == 1
                 Screen('FinalizeMovie', movieptr);
             end
         end
        
        %Increment
        Idx_Counter=Idx_Counter+1;
        
        %Wait for a bit
        Screen('Flip',window.onScreen);
        WaitSecs(.5);
        
        % Release the frames
        Screen('Close')
    end
    
    
    pause(0.2);
end

if save_movie == 1
    
    % Finalize the movie
    if recording_type == 1
        Screen('FinalizeMovie', movieptr);
    end
end

%Finish up
ListenChar(1);
sca;

