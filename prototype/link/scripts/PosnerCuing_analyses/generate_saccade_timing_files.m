% Generate timing files tracking when the infant saccaded, independent of
% any trial events. Only considers saccades between left, right or center, not off screen

function generate_saccade_timing_files

included_responses = [1, 2, 3]; % Include left, right and center responses
saccade_duration = 0.1; % Assume a saccade is 100ms
weight = 1;  % Set all weights to be equal

load('analysis/Behavioral/AnalysedData.mat')

input_timing_file = 'analysis/secondlevel_PosnerCuing/default/Timing/PosnerCuing-Exogenous_Only.txt';
timing_mat = textread(input_timing_file);

output_timing_file = 'analysis/secondlevel_PosnerCuing/default/Timing/PosnerCuing-Condition_Exogenous_Saccades.txt'; 

% Delete the file in case it already exists
unix(sprintf('rm -f %s', output_timing_file));

Idx_Names = EyeData.Idx_Names.PosnerCuing;
Timecourses = EyeData.Timecourse.PosnerCuing;
included_block_counter = 0;
for block_counter = 1:length(fieldnames(AnalysedData.Experiment_PosnerCuing))
    
    % Get the timing for this block
    if isfield(AnalysedData.Experiment_PosnerCuing.(sprintf('Block_1_%d', block_counter)), 'Timing')
        
        % Pull out the timing information
        Timing = AnalysedData.Experiment_PosnerCuing.(sprintf('Block_1_%d', block_counter)).Timing;
        
        % When did the block start in matlab time
        TestStart=Data.Experiment_PosnerCuing.(sprintf('Block_1_%d', block_counter)).Timing.TestStart;
        
        % Is this block included?
        saccade_onset = [];
        if Timing.Include_Block == 1
            
            % Increment counter
            included_block_counter = included_block_counter + 1;
            
            % Pull out the time course for this block
            event_idxs = find(Idx_Names(:, 2) == block_counter);
            
            % Cycle through the Idx_Names
            for event_idx = event_idxs'
                
                % Pull out the timecourse
                Timecourse = Timecourses{event_idx};
                
                % Find the indexes that involve a switch between left,
                % right, center
                saccade_idxs = find(diff(Timecourse) ~= 0);
                for saccade_idx = saccade_idxs
                    
                    % Is this a usable transition
                    if max(saccade_idxs)+1 <= length(Timecourse) && any(included_responses==Timecourse(saccade_idx)) && any(included_responses==Timecourse(saccade_idx+1))
                        
                        saccade_onset(end+1) = EyeData.Timing.PosnerCuing{event_idx}(saccade_idx+1, 2) - (TestStart - Data.Global.Timing.Start);
                        
                    end 
                end
            end
            
            % Use the time stamps collected in order to make timing files
            saccade_onset = sort(saccade_onset);
            
            % What time do the blinks occur relative to the secondlevel run
            event_times = timing_mat(included_block_counter, 1) + saccade_onset;
            
            % Store these times in a file
            fid = fopen(output_timing_file, 'a');
            for event_time = event_times
                fprintf(fid, '%0.2f\t%0.2f\t%0.2f\n', event_time, saccade_duration, weight);
            end
            fclose(fid);
        end
    end
end
