%% Generate the time regressor for eye data exclusions
%
% This loads the Analysed participant data then cycles through the run
% order and pulls out the retinotopy blocks. It then cycles through the
% events within included blocks and records how many frames are to be
% excluded per block. It computes the number of frames that exceed
% the exclusion threshold and outputs a time course as a list. Finally, it
% takes the existing confound file and outputs a new one with these
% exclusions appended

function generate_eye_confound_time_course

% Load the data
load analysis/Behavioral/AnalysedData.mat

retinotopy_dir = 'analysis/secondlevel_Retinotopy/default/';

excl_TRs_all = [];
excl_threshold = 0.25; % What proportion of frames need to be excluded in order to exclude a TR

for block_counter = 1:size(Data.Global.RunOrder, 1)
    
    if strcmp(Data.Global.RunOrder{block_counter, 1}, 'Experiment_Retinotopy')
    
        % Get the block type for this trial
        block_type = Data.Global.RunOrder{block_counter, 2};
        
        % Cycle through the event counters
        excl_TRs_block = [];
        for event_counter = 1:2
            
            for epoch_counter = 1:size(EyeData.Idx_Names.Retinotopy, 1)
                
                % Index name
                match_block_type = EyeData.Idx_Names.Retinotopy(epoch_counter, :);
                
                % If this is the block you are looking for, and the event
                % and the block is included, then proceed
                
                if strcmp(block_type, sprintf('Block_%d_%d', match_block_type(1), match_block_type(2))) && (event_counter == match_block_type(3)) && (isfield(AnalysedData.Experiment_Retinotopy.(block_type), 'Include_Block')) && (AnalysedData.Experiment_Retinotopy.(block_type).Include_Block == 1)
                     
                    % What is the time since the start of the experiment
                    % that this block started
                    event_start_time = Data.Experiment_Retinotopy.(block_type).Timing.InitPulseTime - Data.Global.Timing.Start;
                    event_end_time = event_start_time + AnalysedData.Experiment_Retinotopy.(block_type).Timing.Task_Event(1);
                    
                    % If it is the second even that add to this time
                    if event_counter == 2
                        event_start_time = event_start_time + AnalysedData.Experiment_Retinotopy.(block_type).Timing.Task_Event(1);
                        event_end_time = event_start_time + AnalysedData.Experiment_Retinotopy.(block_type).Timing.Task_Event(2);
                    end
                    
                    % Determine what event type it is and what codes are to
                    % be excluded
                    event_name = AnalysedData.Experiment_Retinotopy.(block_type).Timing.Event_Conditions{event_counter};
                    if strcmp(event_name, 'horizontal')
                        invalid_codes = [0, 6, 7, 8];
                    elseif strcmp(event_name, 'vertical')
                        invalid_codes = [0, 6, 1, 2];
                    else
                        invalid_codes = [0, 6];
                    end
                    
                    % Get the frames corresponding to this 
                    frame_time_stamps = EyeData.Timing.Retinotopy{epoch_counter}(:, 2);
                    
                    % Time course of response
                    responses = EyeData.Timecourse.Retinotopy{epoch_counter};
                    
                    % Cycle through the frames and count the number of
                    % frames per TR as well as the number of excluded
                    % frames
                    frame_count = zeros(10, 1);
                    frame_excl = zeros(10, 1);
                    for frame_counter = 1:length(frame_time_stamps)
                        
                        % Has the event started yet?
                        if (frame_time_stamps(frame_counter) > event_start_time) && (frame_time_stamps(frame_counter) < event_end_time)
                            
                            % What TR does this correspond to
                            TR_counter = ceil((frame_time_stamps(frame_counter) - event_start_time) / 2);
                            TR_counter(TR_counter > 10) = 10;
                            
                            % Is this frame excluded
                            invalid_frame = any(responses(frame_counter) == invalid_codes);
                            
                            % Fill in the values
                            frame_count(TR_counter) = frame_count(TR_counter) + 1;
                            frame_excl(TR_counter) = frame_excl(TR_counter) + invalid_frame; 
                            
                            
                        end
                    end
                    
                    % What TRs should be excluded
                    excl_TRs = (frame_excl ./ frame_count) > excl_threshold;
                    
                    % Either set or append to list
                    if event_counter == 1
                        excl_TRs_block = excl_TRs;
                    else
                        excl_TRs_block = [excl_TRs_block; excl_TRs];
                    end
                    
                end
                
            end
        end
        
        % Finalize the variable by determining the number of burnout TRs,
        % appending that to the list then printing.
        if ~isempty(excl_TRs_block)
            
            % Set the burn out TRs to a max of 3
            RestTRs = AnalysedData.Experiment_Retinotopy.(block_type).RestTRs;
            RestTRs(RestTRs > 3) = 3;
            
            % Compute the extra task TRs (over 20)
            extra_task_TRs = AnalysedData.Experiment_Retinotopy.(block_type).TaskTRs - 20;
            
            % Append included TRs to the list
            excl_TRs_block = [excl_TRs_block; zeros(RestTRs + extra_task_TRs, 1)];
            
            % Append to all list
            excl_TRs_all = [excl_TRs_all; excl_TRs_block];
            
        end
    end
end

% Check that the length of this generated variable is the same as the
% existing confound files
confound_file = [retinotopy_dir, 'Confounds/OverallConfounds.txt'];
output_file = [retinotopy_dir, 'Confounds/OverallConfounds_gaze.txt'];

if length(excl_TRs_all) == size(dlmread(confound_file), 1)
    
    % First create a vector corresponding to these exclusions
    dlmwrite([retinotopy_dir, 'Confounds/gaze_confounds.txt'], excl_TRs_all);
    
    % Check if any TRs ought to be excluded
    if sum(excl_TRs_all) > 0
    
        % Now create a matrix of individual time points excluded
        excl_TRs_mat = zeros(length(excl_TRs_all), sum(excl_TRs_all));
        TR_idxs = find(excl_TRs_all == 1);
        for TR_idx_counter = 1:sum(excl_TRs_all)
            excl_TRs_mat(TR_idxs(TR_idx_counter), TR_idx_counter) = 1;
        end
        
        % Append the new matrix
        orig_mat = dlmread(confound_file);
        out_mat = [orig_mat, excl_TRs_mat];
        
        fprintf('%d/%d eye exclusions, creating output\n', sum(excl_TRs_all), length(excl_TRs_all));
        
        % Extend the preexisting columns
        dlmwrite(output_file, out_mat, ' ');
    
    else
        % If there are no exclusions then duplicate the input file
        fprintf('No eye exclusions, duplicating input\n');
        copyfile(confound_file, output_file);
    end
    
else
    warning('Length mismatch!!\nEye data length: %d\nConfounds length: %d\nQuitting', length(excl_TRs_all), size(dlmread(confound_file), 1));
end

