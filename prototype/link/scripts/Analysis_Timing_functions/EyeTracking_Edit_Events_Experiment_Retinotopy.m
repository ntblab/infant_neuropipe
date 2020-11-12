%% Edit event information for SF and Median Retinotopy 
%
% Due to the way this code was written, there is no event boundary for the
% change in phase of the retinotopy stimulus when it switches. This means
% the whole block is treated as a single event but for your use case this
% is inappropriate. Hence this script edits the event information so that
% more than one event is created.

function EyeData = EyeTracking_Edit_Events_Experiment_Retinotopy(EyeData, Data, GenerateTrials)

% First check that this is SF and Median retinotopy, otherwise skip
Block_Names = fieldnames(Data.Experiment_Retinotopy);
for Block_Name = Block_Names'
    
    split_block_name = strsplit(Block_Name{1}, '_');
    Block_counter = str2num(split_block_name{2});
    Block_repetition = str2num(split_block_name{3});
    Condition = GenerateTrials.Experiment_Retinotopy.Parameters.BlockNames{Block_counter};
    if ~isempty(strfind(Condition, 'first')) || ~isempty(strfind(Condition, 'high'))
        
        % Get the time stamps
        BlockStart = Data.Experiment_Retinotopy.(Block_Name{1}).Timing.InitPulseTime;
        BlockEnd = Data.Experiment_Retinotopy.(Block_Name{1}).Timing.BlockEndTime;
        
        % Find the matching idx for this (in terms of the vectorized
        % version of eye tracking)
        matched_idx = find(all((EyeData.Idx_Names.Retinotopy - [Block_counter, Block_repetition, 1]) == 0, 2));
        
        % Check that there is data for this block and that it contains a
        % switch
        if isfield(Data.Experiment_Retinotopy.(Block_Name{1}).Timing, 'Block_switch') && ~isempty(matched_idx)
            Block_switch = Data.Experiment_Retinotopy.(Block_Name{1}).Timing.Block_switch;
        else
            % If you didn't get to this block switch then skip since the
            % whole event could be usable (probably isn't)
            continue
        end
        
        % Convert the Block_switch time to eye tracker time
        Block_switch_eyetracker = EyeData.EyeTrackerTime.intercept + (EyeData.EyeTrackerTime.slope * Block_switch);
        
        % What is the frame at which the switch has occurred?
        Block_switch_idx = min(find(EyeData.Timing.Retinotopy{matched_idx}(:, 1) > Block_switch_eyetracker));
        
        %% Use this index to split the different data types into two
        
        % Append an index
        EyeData.Indexes{end+1} = {'Retinotopy', Block_counter, Block_repetition, 2};
        
        % Image list
        new_image_list = EyeData.ImageList.Retinotopy{Block_counter, Block_repetition}(Block_switch_idx:end);
        EyeData.ImageList.Retinotopy{Block_counter, Block_repetition} = EyeData.ImageList.Retinotopy{Block_counter, Block_repetition}(1:Block_switch_idx - 1);
        EyeData.ImageList.Retinotopy{Block_counter, Block_repetition, 2} = new_image_list; 
        
        % Onset frame
        EyeData.onset_frame.Retinotopy(Block_counter, Block_repetition, 2) = 0;
        
        % Idx names
        EyeData.Idx_Names.Retinotopy(end+1, :) = [Block_counter, Block_repetition, 2];
        
        % Aggregate data
        new_aggregate = EyeData.Aggregate.Retinotopy{matched_idx}(:, Block_switch_idx:end);
        EyeData.Aggregate.Retinotopy{end + 1} = new_aggregate;
        EyeData.Aggregate.Retinotopy{matched_idx} = EyeData.Aggregate.Retinotopy{matched_idx}(:, 1:Block_switch_idx -1);
        
        % Timing information
        new_timing = EyeData.Timing.Retinotopy{matched_idx}(Block_switch_idx:end, :);
        EyeData.Timing.Retinotopy{end + 1} = new_timing;
        EyeData.Timing.Retinotopy{matched_idx} = EyeData.Timing.Retinotopy{matched_idx}(1:Block_switch_idx -1, :);
        
    end
end
