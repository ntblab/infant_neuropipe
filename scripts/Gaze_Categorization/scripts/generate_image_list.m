%Generate the image list for this participant
%
%Take in the timing file and identify the timepoints at which an experiment
%starts and stops.
%Organize this list in order to present coders with the appropriate stimuli
% This assumes your data is a video where each frame has a corresponding timestamp. 
% Each frame of the video will be extracted and named with the time stamp. This is memory
% and time intensive upfront but is much faster on playback (when it counts)
% This code has legacy functionality such that if your data is stored as frames then this will work
%
% Takes in the participant name (in order to pull out the appropriate
% files) and the experiment definitions.
%
% If you wish to add instructions for some time periods of some trials then
% read 'image_specific_instructions' and edit it accordingly.
%
function generate_image_list(ParticipantDir, lag)

if nargin == 1
    % Set the lag (computed by doing the lag_test)
    lag = -1; 
end


%What are the default experiment definitions
addpath ../../
Gaze_Categorization_Responses

ShuffleAll=0; %Do you want to organize by response category or shuffle all?

% If a movie exists then make it into frames here
total_frames = 0;
if length(dir([ParticipantDir, '/*.avi'])) > 0 && isdir([ParticipantDir, '/eyeImages/']) == 0
    
    fprintf('Found avi folder, making an eyeImages folder\n');
    
    % Save as a jpg
    ext = 'jpg';
    
    mkdir([ParticipantDir, '/eyeImages/']);
    
    %Load the timing file
    TimingFileID=fopen([ParticipantDir, '/TimingFile.txt']);
    Line = fgetl(TimingFileID); %Pull out a line
    
    % Get the file names
    file_names = dir([ParticipantDir, '/*.avi']);
    
    % Get the order of the files right
    time_nums = [];
    for file_counter = 1:length(file_names)
        file_name = file_names(file_counter).name;
        
        % What is the time stamp (in 24h time including seconds)
        time_stamp = str2num(file_name(strfind(file_name, '-') + 1:strfind(file_name, '.') - 1));
        
        time_nums(end+1) = time_stamp;
    end
    
    % Find the order of the movies
    [~, file_order] = sort(time_nums);
    
    % Cycle through the files, loading in the movies and saving each frame
    frame_num = 0; % Initialize at zero so things are made on the first loop
    frame_folder = 0;
    for file_counter = file_order 
        
        % What file name are you going to load in
        file_name = [file_names(file_counter).folder, '/', file_names(file_counter).name];
        
        % Load in the video object
        vid_obj = VideoReader(file_name);
        
        fprintf('Pulling frames from %s\n', file_name);
        
        % How many frames are there?
        total_frames = total_frames + (vid_obj.Duration * vid_obj.FrameRate);
        
        while hasFrame(vid_obj)
            
            % Pull out a frame of the video
            frame = readFrame(vid_obj);
            
            % If you have made enough frames then make a new frame folder
            % (the first frame will also make one)
            if mod(frame_num, 12000) == 0
                frame_folder = frame_folder + 1;
                mkdir(sprintf('%s/eyeImages/Frames_%d', ParticipantDir, frame_folder));
            end
            
            % Increment the counter (the first one will start at 1)
            frame_num = frame_num + 1;
            
            % Get the time stamp from the timing file
            while isempty(strfind(Line, 'SMP'));
                Line = fgetl(TimingFileID);
            end
            
            % Once you have the line, split it up to get the time stamp
            split_Line = strsplit(Line, '\t');
            timestamp = split_Line{1};
            
            % What is the output name?
            output_name = sprintf('%s/eyeImages/Frames_%d/eye%05d_0_0_%d_%d_%s.%s', ParticipantDir, frame_folder, frame_num, size(frame, 1), size(frame, 2), timestamp, ext);
            
            % Save the image
            imwrite(frame, output_name);
            
            % Go to the next line
            Line = fgetl(TimingFileID);
            
            % Update progress
            if mod(frame_num, 5000) == 0 
                fprintf('%d / %0.0f\n', frame_num, total_frames);
            end
        end
        
        
    end
    
    % Check that there are no more SMPs stored in the file after this line
    missed_frame = 0;
    while Line ~= -1
        % Get the time stamp from the timing file
        if ~isempty(strfind(Line, 'SMP'))
            missed_frame = missed_frame + 1;
        end
        
        Line = fgetl(TimingFileID);
    end
    
    % Issue warning if need be
    if missed_frame > 0 || total_frames ~= frame_num
        warning('You are missing %d frames from your video that are listed in your timing file. This requires URGENT attention.', missed_frame);
        return
    end
    
    % Close so it can be opened again in a sec
    fclose(TimingFileID);
end


% List all the images that could be presented
TempFolders=dir([ParticipantDir, '/eyeImages/*']);
TempFolders=TempFolders(arrayfun(@(x) ~strcmp(x.name(1), '.'), TempFolders));

if ~isempty(TempFolders)
    fprintf('Found eyeImages folder, using that\n');
    ImageNames={};
    for TempFolder=1:length(TempFolders)
        Temp=dir([ParticipantDir, '/eyeImages/', TempFolders(TempFolder).name]);
        Temp=Temp(arrayfun(@(x) ~strcmp(x.name(1), '.'), Temp));
        for Counter=1:length(Temp)
            ImageNames{end+1}=['eyeImages/', TempFolders(TempFolder).name, '/', Temp(Counter).name];
        end
    end

else
    fprintf('No images or videos found. Exiting. Check that you have an ''eyeImages'' folder in the participant directory: %s\n\n', ParticipantDir);
    return;
end
eyetracker_frames=[];

%Load the timing file
TimingFileID=fopen([ParticipantDir, '/TimingFile.txt']);

%Search through the timing file to find a variety of times in both matlab
%time and eye tracker time. Use those times to create a linear model
%allowing you to convert matlab time into eye tracker time.

Line = fgetl(TimingFileID); %Pull out a line
EyeTrackerTime=[];
MatlabTime=[];
while ischar(Line)
    % Only listen for times made by the menu so that you know GetSecs is
    % being used
    if ~isempty(strfind(Line, '# Message: About_to_begin')) || ~isempty(strfind(Line, '# Message: Finished')) || ~isempty(strfind(Line, '# Message: DecayLapse_Experiment'))  || ~isempty(strfind(Line, '# Message: Initiate_Eye_tracker'))
    %if ~isempty(strfind(Line, '# Message: DecayLapse_Experiment'))
        %Store the times
        EyeTrackerTime(end+1)=str2double(Line(1:strfind(Line, sprintf('\t'))-1));
        MatlabTime(end+1)=str2double(Line(strfind(Line, 'Time:_')+6:end)); 
    elseif ~isempty(strfind(Line, 'SMP'))
        eyetracker_frames(end+1) = str2double(Line(1:min(strfind(Line, '	')) - 1));
    end        
    Line = fgetl(TimingFileID); %Pull out a line
end
fclose(TimingFileID);

% Calculate the frame rate
if mean(diff(eyetracker_frames)) > 1e3
    diff_frames = diff(eyetracker_frames) / 1e6;
else
    diff_frames = diff(eyetracker_frames) / 1e3;
end

diff_frames = diff_frames(diff_frames < 0.1);
FPS = 1 / mean(diff_frames);
fprintf('Frame rate is: %0.2fHz\n', FPS);

% Fit a linear model to this data.
if median(EyeTrackerTime) > 1e13
    denom = 1e8;
else
    denom = 1;
end

% Create a while loop to check if there are any outliers
is_outliers=1; % Initialize with 1
removed_timepoint = 0;
while is_outliers
    
    % If there are fewer than 3 points, quit
    if length(MatlabTime) < 3
        warning('Insufficient time stamps to make a handshake. Quitting');
    end
    
    % Divide the matlab and eye tracker times proportionally to put in the
    % appropriate scale (deals with precision errors that can happen on some
    % OS)
    model = fitlm(MatlabTime / denom, EyeTrackerTime / denom);
    
    EyeTrackerTime_slope= model.Coefficients.Estimate(2); % The division was applied to both so this is unaffected
    EyeTrackerTime_intercept = model.Coefficients.Estimate(1) * denom; % Reapply the denominator
    
    % Check if there are outliers
    pred_diff = ((MatlabTime*EyeTrackerTime_slope) + EyeTrackerTime_intercept - EyeTrackerTime) / 1e6;
    
    % Check if any predictions are more than Xms off and then exclude the
    % max if so (don't exclude all exceeding that in case the bad ones are
    % dragging it down)
    variance_threshold = (nanstd(pred_diff) * 3);
    if any(abs(pred_diff) > variance_threshold)
       removed_timepoint = removed_timepoint + sum(abs(pred_diff) >= variance_threshold);
       MatlabTime = MatlabTime(abs(pred_diff) < variance_threshold);
       EyeTrackerTime = EyeTrackerTime(abs(pred_diff) < variance_threshold);
    else
        is_outliers = 0;
    end
end

if removed_timepoint > 0
    warning('%d (out of %d) time points were removed in order to make the timing clean', removed_timepoint, removed_timepoint + length(MatlabTime));
end

%Find an example image to use
image_name=ls(sprintf('%s/eyeImages/*/*%d*', ParticipantDir, eyetracker_frames(1)));

% If the lag is -1 then specify what it should be based on the image
% dimensions
if lag == -1
    
    % Compute the lag for the eye tracker
    lag = compute_eye_tracker_lag(image_name, FPS);
    
end

% What is the lag 
fprintf('Lag is %0.2f\n', lag);

EyeTrackerTime_intercept = EyeTrackerTime_intercept + lag;

%Reload the timing file
TimingFileID=fopen([ParticipantDir, '/TimingFile.txt']);

% Get the mat data, moving it if necessary
ppt_name = ParticipantDir(strfind(ParticipantDir, 'Frames/') + 7:end);
mat_file = ['../Mat_Data/', ppt_name, '.mat'];
% If the file doesn't exist, guess it is in the frame dir and move it
if exist(mat_file) == 0
    
    % If the file exists in the frame dir give a warning
    if exist(sprintf('../Frames/%s/%s.mat', ppt_name, ppt_name)) > 0
        warning('Participant data still in the Frames directory, moving. Check that this was done right');
        movefile(sprintf('../Frames/%s/%s.mat', ppt_name, ppt_name), mat_file);
    else
        warning('Mat data not found in the Mat_Data folder or the Frames folder. Put it in the Mat_Data folder. Aborting');
        return
    end
end

% Load the mat data
load(mat_file, 'Data');

BlockEndMessage='# Message: Finished_';
Indexes={}; %Store all the trial indexes
ResponseCategoryList=[];
Line = fgetl(TimingFileID); %Pull out a line
while ischar(Line)
    
    %Is this a line with a message signalling the start of an experiment?
    ExperimentName='';
    if ~isempty(strfind(Line, '# Message: About_to_begin_'))
        
        %Which experiment is this and indicate the messages signifing when
        %to start and stop fixation recording
        
        ExperimentIdx=0;
        for Counter=1:size(ExperimentDefinitions,1)
            if ~isempty(strfind(Line,ExperimentDefinitions{Counter, 1}))
                ExperimentIdx=Counter;
            end
        end
        if ExperimentIdx>0
            
            ExperimentName=ExperimentDefinitions{ExperimentIdx, 1};
            TrialStartMessage=ExperimentDefinitions{ExperimentIdx, 2};
            TrialEndMessage=ExperimentDefinitions{ExperimentIdx, 3};
            
            ResponseCategory=ExperimentDefinitions{ExperimentIdx, 4};
            
            %What block number is this
            BlockNumber=Line(strfind(Line, 'Block_')+6:strfind(Line, 'Block_')+7);
            
            %Pull out just the number
            BlockNumber=str2double(BlockNumber(isstrprop(BlockNumber, 'digit')));
            
            %How many repetitions have there been?
            Idx=strfind(Line, ['Block_', num2str(BlockNumber), '_'])+length(['Block_', num2str(BlockNumber), '_']);
            RepetitionNumber=Line(Idx:Idx+1);
            RepetitionNumber=str2double(RepetitionNumber(isstrprop(RepetitionNumber, 'digit')));
            
            BlockName=sprintf('Block_%d_%d', BlockNumber, RepetitionNumber);
            fprintf('\nAnalyzing %s Block_%s\nDuration:   ', ExperimentName, BlockName)
            
            %While this block hasn't finished iterate over the following
            TrialCounter=1;
            while isempty(strfind(Line, BlockEndMessage))
                
                %If the trial has started then start pulling out trials
                if ~isempty(strfind(Line, TrialStartMessage)) && isempty(strfind(Line, BlockEndMessage))
                    
                    %Store what Trial type this when you start
                    TrialType.(ExperimentName){BlockNumber, RepetitionNumber, TrialCounter}=Line;
                    TrialType_temp=Line; % Store a backup of the trial start message for later
                    
                    %Advance to the next line since you shouldn't start on
                    %the message
                    Line = fgetl(TimingFileID); %Pull out a new line from this file
                    
                    %Until you get the message then start pulling out the
                    %timestamps
                    Temp={};
                    Instructions={};
                    CollectedInstructions={};
                    Instruction_Idx={};
                    Instruction_continuing={};
                    while isempty(strfind(Line, TrialEndMessage)) && isempty(strfind(Line, BlockEndMessage))
                        
                        %When is the first tab (the timing is before that
                        TabIdx=strfind(Line, sprintf('\t'));
                        
                        %Store this number
                        if ~isempty(strfind(Line, 'SMP'))
                            Temp{end+1}=Line(1:TabIdx-1);
                        end
                        
                        %Add image instructions that are experiment
                        %and image specific where relevant
                        [Instructions, Instruction_Idx, Instruction_continuing] = image_specific_instructions(ExperimentName, Line, TabIdx, Instructions, Instruction_Idx, Instruction_continuing, Data, BlockName,TrialType_temp);
                        
                        Line = fgetl(TimingFileID); %Pull out a new line from this file
                    end
                    
                    %Store the timing data
                    Timing.(ExperimentName){BlockNumber, RepetitionNumber, TrialCounter}=Temp;
                    
                    %Discern what images you are able to show participants. 
                    CollectedIdx=[]; %What index of collected frames will you use
                    TempImages={};
                    RecordedIdx=1; %what index
                    
                    %Get the first frame
                    while isempty(CollectedIdx) && RecordedIdx<=length(Temp)
                        TempIdxs=(strfind(ImageNames, Temp{RecordedIdx})); %What are the indexes containing the counter
                        CollectedIdx=find(cellfun(@(TempIdxs) ~isempty(TempIdxs), TempIdxs)==1);
                        RecordedIdx=RecordedIdx+1;
                    end
                    
                    %Did you retrieve any Idxs?
                    if ~isempty(CollectedIdx)
                        
                        % If there is more than one of this index, only
                        % take the first one
                        if length(CollectedIdx)>1
                            CollectedIdx=CollectedIdx(1);
                        end
                        
                        %Input the first image
                        TempImages{1}=ImageNames{CollectedIdx};
                        CollectedInstructions{1}='';
                        CollectedIdx=CollectedIdx+1;
                        
                        %Iterate through the Temp list until you have found
                        %all the Idxs that were actually recorded
                        while RecordedIdx <= length(Temp)
                            
                            %Is there a match
                            isMatch=length(ImageNames)>=CollectedIdx && ~isempty(strfind(ImageNames{CollectedIdx}, Temp{RecordedIdx}));
                            
                            % If it isn't the next frame, is the frame
                            % somewhere in the list but you just can't find
                            % it? If so, then update it here
                            if isMatch == 0
                                new_idx = find(cellfun(@isempty, strfind(ImageNames, Temp{RecordedIdx})) == 0);
                                
                                % If you found one then continue
                                if ~isempty(new_idx)
                                    CollectedIdx = new_idx;
                                    isMatch=1;
                                end
                            end
                            
                            %If there is a match then add this image name
                            %to the list and go on to the next, if there
                            %isn't then go on to the next eye tracking name
                            if isMatch
                                TempImages{end+1}=ImageNames{CollectedIdx};
                                
                                % Cycle through the sets of instruction
                                % indices that were created
                                CollectedInstruction='';
                                for Instruction_counter = 1:length(Instructions)
                                    
                                    % Store the instructions if this index has
                                    % it
                                      if ~isempty(find(str2double(Temp{RecordedIdx})==Instruction_Idx{Instruction_counter}))
                                        CollectedInstruction=Instructions{Instruction_counter};
                                    end
                                end
                                
                                % Store the choosen instruction
                                CollectedInstructions{end+1} = CollectedInstruction;
                                
                                %Increment
                                CollectedIdx=CollectedIdx+1;
                                RecordedIdx=RecordedIdx+1;
                            else
                                RecordedIdx=RecordedIdx+1;
                            end
                            
                        end
                        
                        %Store the images, only take those that were
                        %subsampled
                        ImageList.(ExperimentName){BlockNumber, RepetitionNumber, TrialCounter}=TempImages;
                        
                        % Determine the time elapsed between the start and
                        % the end of this block
                        start_time = TempImages{1}(max(strfind(TempImages{1}, '/')) + 1:end);
                        start_time = str2num(start_time(max(strfind(start_time, '_')) + 1:strfind(start_time, '.') - 1));
                        
                        end_time = TempImages{end}(max(strfind(TempImages{1}, '/')) + 1:end);
                        end_time = str2num(end_time(max(strfind(end_time, '_')) + 1:strfind(end_time, '.') - 1));
                        
                        fprintf('%d: %0.2f   ', TrialCounter, (end_time - start_time) / EyeTrackerTime_slope);
                        
                        %Store the indexes for this trial
                        Indexes{end+1}={ExperimentName, BlockNumber, RepetitionNumber, TrialCounter};
                        ResponseCategoryList(end+1)=ResponseCategory;
                        
                        % Store the instructions
                        ImageInstructions.(ExperimentName){BlockNumber, RepetitionNumber, TrialCounter}=CollectedInstructions;
                    end
                    
                    TrialCounter=TrialCounter+1;
                end
                
                %If this is the start of the next trial (because the trials
                %start and end with the same message) then don't read the
                %next line
                if isempty(strfind(Line, TrialStartMessage)) && isempty(strfind(Line, BlockEndMessage))
                    Line = fgetl(TimingFileID); %Pull out a new line from this file
                end
            end
            
        end
        
    end
    
    Line = fgetl(TimingFileID); %Pull out a new line from this file
end
fclose(TimingFileID);

fprintf('\n\nFinished pulling data.\n');

% Print all of the runs that were run

fields = fieldnames(Data);
fprintf('Experiments that were run:\n');
for field = fields'
    fprintf('%s\n', field{1})
    fieldnames(Data.(field{1}))
end

fprintf('Pausing until you press a button to continue\n\n');
KbWait;

% Print an example of a first frame
fprintf('The following time stamps refer to when a block started. Use them to check that you can see an image onset in the pupil:\n\n');
for idx_counter =  1:length(Indexes)  % 1:length(Indexes) % floor(linspace(1, length(Indexes), 10))
    try
        % Try to find the start time of the block
        block_data = Data.(sprintf('Experiment_%s', (Indexes{idx_counter}{1}))).(sprintf('Block_%d_%d', Indexes{idx_counter}{2}, Indexes{idx_counter}{3}));
        block_timing = block_data.Timing;
        if isfield(block_data, 'flash_Time')
            timing_info = block_data.flash_Time(1);
        elseif isfield(block_timing, 'TestStart')
            timing_info = block_timing.TestStart;
        elseif isfield(block_timing, 'InitPulseTime')
            timing_info = block_timing.InitPulseTime;
        elseif isfield(block_timing, 'Movie_1')
            timing_info = block_timing.Movie_1.movieStart.Local;
        end
        expt = Indexes{idx_counter}{1};
        
        % What is the eye tracker time?
        timing_info = EyeTrackerTime_intercept + (timing_info * EyeTrackerTime_slope);
        
        fprintf('%s Block_%d_%d first frame is near %0.2f\n', expt, Indexes{idx_counter}{2}, Indexes{idx_counter}{3}, timing_info / 1e5);
    catch
    end
end
pause(0.5);
KbWait;

%Shuffle the indexes so that they aren't in order
if ShuffleAll==1
    
    Indexes=Shuffle(Indexes);
    
else
    
    % Reorder the indexes. If you have already made an image list then use
    % that same order. That way any coders who used the previous order can
    % still be used, although, they might have some issues if the image
    % list changed a lot
    TempIndexes={};
    if exist([ParticipantDir, '/ImageList.mat']) == 2
        warning('ImageList file already exists. Trying to reorder in order to match previous file');
        
        % Load in the old
        old_imagelist = load([ParticipantDir, '/ImageList.mat']);
        
        for Counter=unique(ResponseCategoryList)
            
            % Try and implement the old ordering for this response category
            
            % Load in the old index orders
            old_ResponseCategoryList = old_imagelist.ResponseCategoryList;
            old_Indexes = old_imagelist.Indexes(old_ResponseCategoryList==Counter);
            
            % Load in the new indexes
            new_Indexes = Indexes(ResponseCategoryList==Counter);
            
            % Check that the new and old sets are a match. First check that
            % there is a match for every old pair, and then vice versa
            
            for ref_vs_target = 1:2
                
                % Make one set of indexes the reference and the other the
                % target
                if ref_vs_target == 1
                    ref_name = 'old';
                    ref_Indexes = old_Indexes;
                    target_Indexes = new_Indexes;
                else
                    ref_name = 'new';
                    ref_Indexes = new_Indexes;
                    target_Indexes = old_Indexes;
                end
                
                % Cycle through all the combinations of ref and target
                for ref_counter = 1:length(ref_Indexes)
                    isMatch = 0; % Set to zero
                    for target_counter = 1:length(target_Indexes)
                        
                        % Are these the same
                        isMatch = isequal(ref_Indexes{ref_counter}, target_Indexes{target_counter});
                        
                        % If there is a match then break
                        if isMatch == 1
                            break
                        end
                        
                    end
                    
                    % If there is no match for this ref then break
                    if isMatch == 0
                        warning('There is no match for %s index %s %d %d %d. Aborting', ref_name, ref_Indexes{ref_counter}{1}, ref_Indexes{ref_counter}{2}, ref_Indexes{ref_counter}{3}, ref_Indexes{ref_counter}{4});
                        dbstop if error;
                        dbstop
                    end
                end
            end
            
            % If you haven't quit now then you can save the index ordering
            TempIndexes(end+1 : end+sum(ResponseCategoryList==Counter))=old_Indexes;
        end
           
    else
        % Go through the response categories and randomize within
        % categories
        for Counter=unique(ResponseCategoryList)
            TempIndexes(end+1 : end+sum(ResponseCategoryList==Counter))=Shuffle(Indexes(ResponseCategoryList==Counter));
        end
        
    end
    
    % Save the indexs
    Indexes=TempIndexes;
    
    %Pull out the response category for this
    for TrialCounter=1:length(Indexes)
        for Counter=1:size(ExperimentDefinitions,1)
            if strcmp(ExperimentDefinitions(Counter,1), Indexes{TrialCounter}{1})
                ResponseCategoryList(TrialCounter)=ExperimentDefinitions{Counter,4};
            end
        end
    end
end

%If the file exists then back it up
if exist([ParticipantDir, '/ImageList.mat'])
   copyfile([ParticipantDir, '/ImageList.mat'], [ParticipantDir, '/ImageList_backup_',  datestr(now, 'mm_dd_yy'), '.mat'])
end

%Save this 
save([ParticipantDir, '/ImageList.mat'], 'ImageList', 'Indexes', 'EyeTrackerTime_slope', 'EyeTrackerTime_intercept', 'TrialType', 'Timing', 'ResponseCategoryList', 'ImageInstructions');
fprintf('\n'); % Make space

figure
scatter(1:length(MatlabTime), ((MatlabTime*EyeTrackerTime_slope) + EyeTrackerTime_intercept - EyeTrackerTime - lag) / 1e6)
fprintf('Check that the error in eye tracking estimates are random around zero and low (<0.1) over the experiment\n');


