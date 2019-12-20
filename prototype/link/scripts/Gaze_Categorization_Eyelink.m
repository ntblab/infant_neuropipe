%% Generate the equivalent of GazeCategorization in eyelink
%
% Create the same structure as is created by Gaze Categorization but using
% an EDF file from EyeLink. This structure is a mat file with the name
% $ParticipantName_Coder_EL_All.mat which means it is identified as an
% eyelink file that will be interpreted appropriately. The structure of
% this file is to store 'Output', 'ExperimentDefinitions',
% 'ResponseAllowed', 'TrialCounter', 'ImageList', 'Indexes',
% 'EyeTrackerTime_slope', 'EyeTrackerTime_intercept'. 
%
% This code is klugey. This is trying to put a square peg in a round hole
% so mileage may vary.
%
% There are 2 EDF files to be aware of. One is the message report
% ('message_$SUBJ.xls') which has the info for each message eyelink
% receives and the other is the fixation report ('fixation_$SUBJ.xls') that
% stores the fixation data.
%
% Indexes is the list of experiment blocks/epochs that would be analyzed by
% coders. Each entry in the list is a cell with four elements:
% {ExperimentName, BlockNumber, RepetitionNumber, EventNumber}
% 
% Output is a structure with various fields. In timing there are fields for
% each experiment and in each field is an array of cells (organized by
% BlockNumber, RepetitionNumber, Event Number) which each contain an array
% of cells containing the time stamp and the coded response (e.g. left or
% right). The response information is also in the Output.Experiment fields.
% The index information is stored in the Indexes subfield of the output
%
% Based on the allowed responses (which is experiment contingent) this
% algorithm will categorize each epoch of data
%
% Take in the information for a given participant and output the aggregate
% looking behaviors across coders.
%
% Initial C Ellis 5/17/18

function EyeData=Gaze_Categorization_Eyelink


% Set up

Extension = 'data/Behavioral/';
fullpath=pwd;
folder_name=fullpath(max(strfind(fullpath, '/'))+1:end); % What participant folder are we in
cd('../../'); [~, participant_list]=Participant_Index({'Check_QA', 0}); cd(fullpath); % Get the participant info

ParticipantName=participant_list{find(strcmp(participant_list(:,1), folder_name)), 2};

load([Extension, ParticipantName, '.mat'], 'GenerateTrials', 'Window', 'Data');

% % For testing
% Extension = '~/Desktop/';
% ParticipantName='TM_04271118';
% load(['/Users/cellis/Documents/MATLAB/experiment_menu/Data/', ParticipantName, '.mat'], 'GenerateTrials', 'Window', 'Data');

% What is the threshold for moving from center 
center_eccen=Window.ppd*3; % How many visual degrees (radius) counts as center?

fps = 60; % When simulating frames, what is the fps assumed?

% Pull out all of the response option information (e.g. for a given
% experiment, what responses do you want to code?
addpath ../../scripts
Gaze_Categorization_Responses

% What is the file name
eye_data_file = [Extension, '/fixation_', ParticipantName, '.xls'];
message_file = [Extension, '/message_', ParticipantName, '.xls'];

%What coders do you have for this participant
output_name=[Extension, ParticipantName, '_Coder_EL_all.mat'];

% Read the eye tracking data
fid=fopen(eye_data_file);
line = fgetl(fid);
eye_data={};
while line ~= -1

    % Fix the data if there are spaces between the words in the message
    split_line = strsplit(line);
    if length(split_line) > 14

        temp=[];
        for word_counter = 14:length(split_line)
            temp=[temp, split_line{word_counter}, '_'];
        end

        % Lop the end of the data off
        split_line{14} = temp(1:end-1);
        split_line=split_line(1:14);
    end

    eye_data(end+1, :) = split_line; % Loop through the lines and segment

    line = fgetl(fid);
end
fclose(fid);

% Read in the message data
fid=fopen(message_file);
line = fgetl(fid);
message_data={};
while line ~= -1

    % Pull out line
    split_line = strsplit(line);
    
    % The line 'Trial: X' is treated as two words, fix
    if any(strcmp(split_line, 'Trial:'))
        
        % Where is the trial value
        word_counter = find(strcmp(split_line, 'Trial:'));
        
        % Remake the line
        split_line={split_line{1:word_counter-1}, [split_line{word_counter}, '_', split_line{word_counter+1}], split_line{word_counter+2:end}};
        
    end
    
    % Fix the data if there are spaces between the words in the message
    if length(split_line) > 9

        temp=[];
        for word_counter = 9:length(split_line)
            temp=[temp, split_line{word_counter}, '_'];
        end

        % Lop the end of the data off
        split_line{9} = temp(1:end-1);
        split_line=split_line(1:9);
    end

    message_data(end+1, :) = split_line; % Loop through the lines and segment

    line = fgetl(fid);
end
fclose(fid);


%% Analyse eye tracking behavior

% Pull out the columns for each label
labels = eye_data(1,:);
start_time_col=find(strcmp(labels, 'TRIAL_START_TIME'));
X_col=find(strcmp(labels, 'CURRENT_FIX_X'));
Y_col=find(strcmp(labels, 'CURRENT_FIX_Y'));
duration_col=find(strcmp(labels, 'CURRENT_FIX_DURATION'));
fix_onset_col=find(strcmp(labels, 'CURRENT_FIX_START'));
fix_offset_col=find(strcmp(labels, 'CURRENT_FIX_END'));
fix_idx_col=find(strcmp(labels, 'CURRENT_FIX_INDEX'));
fix_trial_col=find(strcmp(labels, 'TRIAL_INDEX'));

msg_col=find(strcmp(message_data(1,:), 'CURRENT_MSG_TEXT'));
msg_trial_start_col=find(strcmp(message_data(1,:), 'TRIAL_START_TIME'));
msg_trial_idx_col=find(strcmp(message_data(1,:), 'TRIAL_INDEX'));
msg_fix_idx_col=find(strcmp(message_data(1,:), 'CURRENT_MSG_FIX_INDEX'));
msg_time_col=find(strcmp(message_data(1,:), 'CURRENT_MSG_TIME'));

% Make the image rects
centerX = Window.centerX;
centerY = Window.centerY;

% Pull out all the matlab time stamps and regress them against the eye
% tracker time stamps
matlab_time = [];
eyetracker_time = [];
for fix_counter = 2:size(message_data,1)

    % Determine if there is a time stamp in the message
    time_idx = strfind(message_data{fix_counter, msg_col}, 'Time:_');
    if ~isempty(time_idx)

        % What is the matlab timestamp provided?
        matlab_time(end+1) = str2num(message_data{fix_counter, msg_col}(time_idx+6:end));

        % What is the delay from this message and the start of this trial 
        message_delay = str2num(message_data{fix_counter, msg_time_col});

        % When did the trial start? Report 
        eyetracker_time(end+1) = str2num(message_data{fix_counter, msg_trial_start_col}) + message_delay;
    end

end

% Pull out the slope and intercept of this funct tp go from matlab time to
% eye tracker time (not what you want to do in this script really
coefs = polyfit(matlab_time', eyetracker_time', 1);

% Store the data
Output.EyeTrackerTime_slope=coefs(1);
Output.EyeTrackerTime_intercept=coefs(2);
EyeTrackerTime_slope=coefs(1);
EyeTrackerTime_intercept=coefs(2);

% Cycle through all of the TRs
fix_counter=2;  % Skip the labels
AnalysedData.EyeData.All={};

% Pull out some of the information in the data (add nans instead of the
% labels)
fix_trial_idx=[NaN; cellfun(@str2num, eye_data(2:end,fix_trial_col))];
msg_trial_idx=[NaN; cellfun(@str2num, message_data(2:end, msg_trial_idx_col))];

% Cycle through the fixations
epoch_counter=0;
previous_epoch_counter=-1;
previous_run_row=-1;
frame_total=0;
Indexes={};
block_onset=0; % When did this event start
while fix_counter <= size(eye_data,1)

    % Update whenever the eye tracker is turned on or off
    epoch_counter=str2num(eye_data{fix_counter,fix_trial_col});
    
    % If the number is different then update
    if previous_epoch_counter ~= epoch_counter
       previous_epoch_counter = epoch_counter;
    end
    
    % Record in milliseconds the timing information
    trial_onset = str2num(eye_data{fix_counter, start_time_col}); % Trial onset is ambiguous, is it the onset of a block or an event? You have to deal with this contingency
    fix_onset = str2num(eye_data{fix_counter, fix_onset_col});
    fix_offset = str2num(eye_data{fix_counter, fix_offset_col});
    
    % Get the onset and offset times relative to the start of the block.
    % This helps you deal with the difference between trials and blocks
    fix_block_onset = fix_onset + trial_onset - block_onset;
    fix_block_offset = fix_offset + trial_onset - block_onset;
    
    % Convert the fixation onset_time into experiment time
    fix_onset_exp = ((fix_onset + trial_onset) - EyeTrackerTime_intercept) / EyeTrackerTime_slope;
    fix_offset_exp = ((fix_offset + trial_onset) - EyeTrackerTime_intercept) / EyeTrackerTime_slope;
    
    % Take the fixation onset and offset and convert it into
    % frames that are then filled with these responses. This is since the
    % start of the block (not the start of the trial)
    frame_start_idx = ceil((fix_block_onset / 1000) * fps);  % Convert to frames
    frame_end_idx = floor((fix_block_offset / 1000) * fps);  % Convert to frames
    
    % What row of the run order does the fixation onset time correspond to?
    run_row = find(cell2mat(Data.Global.RunOrder(:,4)) < fix_onset_exp, 1, 'last');
    
    %% If you just finished a run then store information for that run
    if isempty(run_row) || isempty(previous_run_row) || run_row~=previous_run_row

        if exist('Experiment_name') > 0 && ~isempty(run_row) && run_row > 0 && EventNumber > 0
            
            % The last offset of the event is the trial duration
            block_duration = (str2num(eye_data{fix_counter-1, start_time_col}) + str2num(eye_data{fix_counter-1, fix_offset_col})) - block_onset;
            
            % How many frames per run?
            frames_per_run = round((block_duration/1000) * fps); % Times are in ms
            
            % When did the frames begin
            eye_frame_times = linspace(0, block_duration, frames_per_run+1) + trial_onset;
            eye_frame_times = eye_frame_times(1:end-1); % Trim off the last TR
            
            % Convert this into matlab time
            mat_frame_times=(eye_frame_times - EyeTrackerTime_intercept) / EyeTrackerTime_slope;
             
            for EventNumber = 1:length(responses_run)
                
                % Find the frames corresponding to each event
                if EventNumber==length(responses_run) % If it is the last event then take to the end
                    event_eye_frame_idxs = (event_start_frame(EventNumber):frames_per_run) - event_start_frame(1) + 1;
                else
                    event_eye_frame_idxs = (event_start_frame(EventNumber):event_start_frame(EventNumber+1)-1) - event_start_frame(1) + 1;
                end
                
                % Store each frame with a frame counter and a time stamp.
                % Calculate the time stamp by comparing the frames since
                % the start of the event

                for frame_counter=1:length(event_eye_frame_idxs)
                    % Create a line that reads frame number and time counter
                    frame_time = (((event_eye_frame_idxs(frame_counter) + event_start_frame(1) - 1)/ fps) * 1000) + block_onset;  % How many frames/seconds after the start of this run is this?
                    ImageList.(Experiment_name){BlockNumber, RepetitionNumber, EventNumber}{frame_counter}=sprintf('eye%05d_0_0_320_240_%d.', frame_total, round(frame_time)); % Create the frame name using the SMI nomenclature (in microseconds)
                    frame_total=frame_total+1;
                end
                
                %% Convert the fixation into a frame wise response
                % Take the accumulated responses and store them.
                
                % Preset the volume with undetected (in this case, blinks)
                Output.Experiment.(Experiment_name){BlockNumber, RepetitionNumber, EventNumber}=repmat({'LeftShift'}, length(event_eye_frame_idxs), 1);
                for response_counter = 1:length(responses_run{EventNumber})
                    
                    % Pull out infromation
                    response=responses_run{EventNumber}{response_counter}{1};
                    start_idx=responses_run{EventNumber}{response_counter}{2} - event_start_frame(EventNumber) + 1; start_idx(start_idx<1)=1;  % How many frames from the start of the event?
                    end_idx=responses_run{EventNumber}{response_counter}{3} - event_start_frame(EventNumber) + 1;
                    
                    % Trim off fixations that exceed the event end
                    if end_idx > length(event_eye_frame_idxs)
                        end_idx = length(event_eye_frame_idxs);
                    end
                    
                    frame_number=end_idx-start_idx;
                    
                    % Store the responses
                    Responses=repmat({response}, frame_number+1, 1);
                    Output.Experiment.(Experiment_name){BlockNumber, RepetitionNumber, EventNumber}(start_idx:end_idx) = Responses;
                    
                end

                % Now fill in the other information
                for frame_counter=1:length(event_eye_frame_idxs)
                    
                    % Store the key presses and time since the start of the
                    % experiment (zero in Eyelink)
                    TimesinceStart=(((event_eye_frame_idxs(frame_counter) + event_start_frame(1) - 1)/ fps) * 1000) + block_onset;
                    response=Output.Experiment.(Experiment_name){BlockNumber, RepetitionNumber, EventNumber}{frame_counter};
                    Output.Timing.(Experiment_name){BlockNumber, RepetitionNumber, EventNumber}{frame_counter}= {TimesinceStart, response};
                    
                    % Also store all of the index information
                    Output.Indexes.(Experiment_name){BlockNumber, RepetitionNumber, EventNumber}{frame_counter}={Experiment_name, BlockNumber, RepetitionNumber, EventNumber, frame_counter};
                    
                    % Arbitrary
                    Output.Vignette.(Experiment_name){BlockNumber, RepetitionNumber, EventNumber}{frame_counter}=Window.Rect;
                    Output.Trial_duration.(Experiment_name){BlockNumber, RepetitionNumber, EventNumber}{frame_counter}=0;
                    
                end
                
                % Store the indexes that were accessed
                Indexes{end+1}={Experiment_name, BlockNumber, RepetitionNumber, EventNumber};
            end
        end
        
        % Reset counters
        EventNumber = 0;
        msg_list={};
        responses_run={};
        event_start_frame=[];
        block_onset=trial_onset;
    end
    
    %% If this row had an experiment then add this eye tracking information
    if ~isempty(run_row) && run_row > 0 
        
        % Use this information to pull out the relevant block information
        Experiment_name = Data.Global.RunOrder{run_row, 1}(12:end);  % Remove Experiment
        BlockName = Data.Global.RunOrder{run_row, 2};
        
        % Pull out the two numbers from the block name
        idxs=strfind(BlockName, '_');
        BlockNumber = str2num(BlockName(idxs(1)+1:idxs(2)-1));
        RepetitionNumber = str2num(BlockName(idxs(2)+1:end));
        
        % Identify which experiment this matches to
        ExperimentIdx=0;
        for Counter=1:size(ExperimentDefinitions,1)
            if ~isempty(strfind(Experiment_name, ExperimentDefinitions{Counter, 1}))
                ExperimentIdx=Counter;
            end
        end
        
        % If you still haven't found a match, try binding this block to the
        % experiment name
        if ExperimentIdx==0
            for Counter=1:size(ExperimentDefinitions,1)
                if ~isempty(strfind([Experiment_name, '_Block_', num2str(BlockNumber)], ExperimentDefinitions{Counter, 1}))
                    ExperimentIdx=Counter;
                end
            end
        end
            
        % Is there an experiment that matches
        if ExperimentIdx > 0
            
            % Which response category are you in?
            Response_Category = ExperimentDefinitions{ExperimentIdx, 4};
            
            % If you find any messages for this trial number then use them
            % to figure out what event number this is, otherwise just
            % assume one
            previous_EventNumber = EventNumber; % Preset now
            if ~isempty(find(fix_trial_idx(fix_counter)==msg_trial_idx, 1))
                
                % What is the most recent message row that was sent before this
                % fixation
                msg_rows=find(fix_trial_idx(fix_counter)==msg_trial_idx); % Which msgs occured during this epoch?
                msg_row = msg_rows(find(cellfun(@str2num, message_data(msg_rows, msg_time_col)) < fix_onset, 1, 'last'));  % Which row of the messages corresponds to the last one after this fixation onset
                
                % If there is a fixation before the first message (possible since
                % the eye tracker is turned on first and then a message is sent)
                % then set to 1
                if isempty(msg_row)
                    msg_row=msg_rows(1);
                end
                
                % Store this message
                last_msg = message_data{msg_row, msg_col};
               
                % Is this the first fixation referencing the message
                if isempty(msg_list) || all(strcmp(msg_list, last_msg)==0)
                    
                    % Add to the list
                    msg_list{end+1}=last_msg; % Add to the list
                    
                    % Does this last message signal an event start and is this the
                    % first fixation referencing it? If so, increment the event
                    % counter
                    if ~isempty(strfind(last_msg, ExperimentDefinitions{ExperimentIdx, 2}))
                       
                        % increment
                        EventNumber = EventNumber + 1;
                        
                        % When did this event start in terms of frames?
                        msg_time=str2num(message_data{msg_row, msg_time_col});
                        
                        % When did the event start relative to block onset?
                        event_start_frame(EventNumber)=round((((msg_time + str2num(message_data{msg_row, msg_trial_start_col})) - block_onset) / 1000) * fps);
                    end
                end
            else
                % If you can't find information but need to store it
                % anyway, then just treat it all as the first event
                EventNumber = 1;
                
                % Start frame of this event
                event_start_frame=1;
                
            end
            
            % Only proceed for the ones that have something to submit
            if EventNumber > 0
                
                
                %% Pull out the coords on this fixation
                coords=cellfun(@str2num, eye_data(fix_counter, [X_col, Y_col]));
                X_displacement = coords(1) - centerX;
                Y_displacement = coords(2) - centerY;
                
                % Put the coordinates in a category as per the response
                % options/experiment this will change
                
                % Left, Right, Center, Undetected, Off
                response=[];
                if Response_Category == 1
                    
                    if abs(X_displacement) < center_eccen % Center
                        response='s';
                    elseif sign(X_displacement) == -1 %Left
                        response='a';
                    elseif sign(X_displacement) == 1 %Right
                        response='d';
                    end
                    
                    % Center, Off Center, Undetected, Off
                elseif Response_Category == 2
                    
                    if abs(X_displacement) < center_eccen && abs(Y_displacement) < center_eccen
                        response='s';
                    else
                        response='x';
                    end
                    
                    % Present, Undetected, Off
                elseif Response_Category == 3
                    
                    % Set to present unless otherwise stated
                    response='e';
                    
                    % Left, Right, Undetected, Off
                elseif Response_Category == 4
                    
                    if sign(X_displacement) == -1 %Left
                        response='a';
                    elseif sign(X_displacement) == 1 %Right
                        response='d';
                    end
                end
                
                % If the eyes are off screen then overwrite previous values
                if abs(X_displacement) > Window.screenX/2 || abs(Y_displacement) > Window.screenY/2
                    response='space';
                end
                
                % If it hasn't been made yet then preset an empty array for
                % this event
                if length(responses_run) < EventNumber
                    responses_run{EventNumber}={};
                end
                
                responses_run{EventNumber}{end+1} = {response, frame_start_idx, frame_end_idx};
                
            end
            
        else
            % If you haven't incremented the epoch then don't report this
            if previous_epoch_counter ~= epoch_counter
                warning('Experiment %s and Block %d match not found in Experiment Definitions.\nUpdate ''Gaze_Categorization_Responses'' if this is inappropriate.');
            end
            
        end
    end
    
    % Increment
    fix_counter=fix_counter+1;
    previous_epoch_counter = epoch_counter; % Store
    previous_run_row = run_row;
    
end
TrialCounter=length(Indexes); % For compatibility

% Save all the information
save(output_name)

