% Create pseudo runs of functional runs
%
% Create new nifti files, timing files, confound files and fsf files for runs with
% multiple experiments per run. These new runs will be named with a letter appended
% to the run name, with 'a' being the first pseudo-run and then numbers proceeding
% alphabetically.
%
% pseudorun_criteria determines under what circumstances a pseudorun will
% be created.
%       0: Do not do a pseudorun analysis
%       1: Divide runs based on experiment changes
%       2: Divide runs based on excluded blocks (FUNCTIONALITY UNDER CONSTRUCTION)
%       3: Divide runs based on either experiment changes or excluded blocks (FUNCTIONALITY UNDER CONSTRUCTION)
%
% pseudorun_timestamps is an important function being used here that
% determines when pseudorun starts and ends (in seconds) relative to the
% first TR after the first burn in. In other words, zero is the time the
% experiment starts
%
% C Ellis 2/23/19

function AnalysedData = pseudorun_divide(AnalysedData, Functional_Counter, pseudorun_criteria, Run_BurnIn_fid)

% Set the path
addpath scripts/
globals_struct=read_globals; % Load the content of the globals folder
[~,subj] = fileparts(pwd);

% Load in the defaults for later
BurninTRs=3; %How many TRs are you excluding before the first block of a pseudorun?
BurnoutTRs=3; %How many TRs are you taking after the block ends?
TR = AnalysedData.TR(Functional_Counter);
first_block_burn_in = AnalysedData.Run_BurnInTRNumber;

prep_set_defaults

% Set ip directories
input_nifti_dir = './data/nifti/';
output_nifti_dir = './analysis/firstlevel/pseudorun/';
output_confound_dir = './analysis/firstlevel/Confounds/';

% Pull out the experiment label of each TR in this run
Experiment_Timecourse = AnalysedData.Timecourse{Functional_Counter}(1,:);
Blocks = AnalysedData.All_BlocksPerRun{Functional_Counter};
Timing_File_Struct = AnalysedData.Timing_File_Struct(Functional_Counter);

% Fix the time course if there are unassigned TRs
AssignedTRs = ~cellfun(@isempty, AnalysedData.Timecourse{Functional_Counter}(1,:));
Experiment_Timecourse = Experiment_Timecourse(AssignedTRs);

% Pull out the onsets for blocks that are excluded
if ~isempty(AnalysedData.Included_BlocksPerRun{Functional_Counter})
    Excluded_onsets = setdiff(cell2mat(AnalysedData.All_BlocksPerRun{Functional_Counter}(:,2)), cell2mat(AnalysedData.Included_BlocksPerRun{Functional_Counter}(:,2)));
else
    Excluded_onsets = cell2mat(AnalysedData.All_BlocksPerRun{Functional_Counter}(:,2));
end

% Determine the experiments that were run
Experiments = unique(Experiment_Timecourse);

% Determine the indices for starting a pseudorun, if at all
pseudorun_timestamps = [];
pseudorun_counter = 1;
if pseudorun_criteria > 0
    
    % Make folder
    if exist(output_nifti_dir) == 0
        mkdir(output_nifti_dir);
    end
    
    % If there is more than one experiment in a run
    if pseudorun_criteria == 1 && length(Experiments) > 1
        
        fprintf('\n\n&&!!!&&&!!!&&&!!!&&&!!!&&&!!!&&&!!!&&\n&&&                               &&&\n&&& Performing pseudorun analysis &&&\n&&&                               &&&\n&&!!!&&&!!!&&&!!!&&&!!!&&&!!!&&&!!!&&\n\n')
        
        % First we will want to update the run-burn in for the first
        % pseudorun so it can be used in the new fsf files
        warning('Burn in for the first pseudorun is %d. This is being updated in the run_burn_in.txt file', first_block_burn_in)
        fprintf(Run_BurnIn_fid, sprintf('functional%02d%s %d\n', Functional_Counter, char('a' + size(pseudorun_timestamps, 1)), first_block_burn_in));
        
        % Determine the last block of the Experiment before the change
        next_pseudorun_onset = -1 * first_block_burn_in * TR ; % Start the run at the
        for block_counter = 1:size(Blocks,1)
            curr_expt = Blocks{block_counter, 1};
            curr_expt = curr_expt(1:min(strfind(curr_expt, '-')) - 1);
            
            % Get the experiment that is in the next block or make it blank
            if block_counter < size(Blocks,1)
                next_expt = Blocks{block_counter + 1, 1};
                next_expt = next_expt(1:min(strfind(next_expt, '-')) - 1);
            else
                next_expt= '';
            end
            
            % Increment counter
            pseudorun_block(block_counter) = pseudorun_counter;
            
            % Detect experiment changes
            if ~strcmp(curr_expt, next_expt)
                
                % Increment counter
                pseudorun_counter = pseudorun_counter + 1;  
                
                % When did the run begin in session time
                if Functional_Counter > 1
                    run_onset = sum(AnalysedData.FunctionalLength(1:Functional_Counter - 1));
                else
                    run_onset = 0;
                end
                
                % When did the last block before the change begin
                last_block_onset = Blocks{block_counter, 2} - run_onset;
                
                % What is the last block ID
                block_name = Blocks{block_counter, 3};
                
                % What was the last block duration
                last_block_duration = AnalysedData.(sprintf('Experiment_%s', curr_expt)).(block_name).TaskTime;
                
                % Store the information for the pseudo run timestamps
                pseudorun_offset = last_block_onset + last_block_duration + (BurnoutTRs * TR);
                pseudorun_timestamps(end + 1, :) = [next_pseudorun_onset, pseudorun_offset];
                
                % Determine when the next pseudo run will onset if there is
                % one (otherwise, make the pseudo run use all of the
                % remaining TRs)
                if block_counter < size(Blocks,1)
                    
                    next_pseudorun_onset = Blocks{block_counter + 1, 2} - (BurninTRs * TR) - run_onset;
                    
                    % Check that the next onset is not before this past
                    % offset (i.e. there weren't enough burnout TRs)
                    if pseudorun_offset > next_pseudorun_onset
                        
                        % Remove burn in TRs until you get to the
                        % appropriate number
                        removed_burn_in_TRs = 0;
                        while pseudorun_offset > next_pseudorun_onset
                            removed_burn_in_TRs = removed_burn_in_TRs + 1;
                            next_pseudorun_onset = Blocks{block_counter + 1, 2} - ((BurninTRs - removed_burn_in_TRs) * TR) -run_onset;
                        end
                        
                        
                        % Update the burn in number in the relevant file
                        warning('Burn in for the upcoming pseudorun is %d because there aren''t enough TRs between experiments. This is being updated in the run_burn_in.txt file', BurninTRs - removed_burn_in_TRs)
                        fprintf(Run_BurnIn_fid, sprintf('functional%02d%s %d\n', Functional_Counter, char('a' + size(pseudorun_timestamps, 1)), BurninTRs - removed_burn_in_TRs));
         
                    end
                    
                else
                    pseudorun_timestamps(end, 2) = AnalysedData.FunctionalLength(Functional_Counter);
                end
                
                fprintf('%s %s is end of pseudorun\n', curr_expt, block_name);
                
            end
            
            % Update for the next block
            next_expt = curr_expt;
        end

    %check if pseudoruns were made for this block before, but are no longer
    %relevant and should be deleted; this would happen if the functionals
    %were accidentally shuffled and more than one experiment was thought to
    %be in this run
    elseif pseudorun_criteria == 1 && length(Experiments) == 1
        
        %first check if they are there
        [list_fsfs,output]=unix(sprintf('ls analysis/firstlevel/functional%02d?.fsf',Functional_Counter));
        [list_runs,output]=unix(sprintf('ls analysis/firstlevel/pseudorun/*functional%02d?.nii.gz',Functional_Counter));
        
        if list_runs == 0 && list_fsfs == 0
            unix(sprintf('rm analysis/firstlevel/functional%02d?.fsf',Functional_Counter));
            unix(sprintf('rm analysis/firstlevel/pseudorun/*functional%02d?.nii.gz',Functional_Counter));
            
            %tell them what you did
            warning('Analysis Timing previously made pseudoruns for functional run %02d, which is no longer true according to the mat file timing. Deleting pseudorun fsf files and niftis.', Functional_Counter)
        elseif list_runs == 0 && list_fsfs >0
            
            %maybe only runs exist
            unix(sprintf('rm analysis/firstlevel/pseudorun/*functional%02d?.nii.gz',Functional_Counter));
            
            %tell them what you did
            warning('Analysis Timing previously made pseudoruns for functional run %02d, which is no longer true according to the mat file timing. fsf files do not exist but deleting the irrelevant niftis.', Functional_Counter)
        elseif list_runs > 0 && list_fsfs ==0
            
            %or maybe only fsfs exist
            unix(sprintf('rm analysis/firstlevel/pseudorun/*functional%02d?.fsf',Functional_Counter));
            
            %tell them what you did
            warning('Analysis Timing previously made pseudoruns for functional run %02d, which is no longer true according to the mat file timing. Niftis do not exist but deleting the irrelevant fsf files.', Functional_Counter)

        end
    
    % Is there an excluded block
    elseif pseudorun_criteria == 2 && ~isempty(Excluded_onsets)
        
    % Is there either an excluded block or multiple experiments in this run
    elseif pseudorun_criteria == 3 && logical(~isempty(Excluded_onsets) || unique(Experiments) > 1)
        
    end
end

%% Make the pseudoruns with the timestamps 

% Get the number of pseudoruns
num_pseudoruns = size(pseudorun_timestamps,1);

input_nifti = sprintf('%s/%s_functional%02d.nii.gz', input_nifti_dir, subj, Functional_Counter);
total_events = zeros(1, num_pseudoruns);
for pseudorun_counter = 1:num_pseudoruns
    
    % What is the character of this pseudorun
    pseudorun_letter = char('a' + pseudorun_counter - 1);
    
    functional_run = sprintf('functional%02d%s', Functional_Counter, pseudorun_letter);
   
    % Get the burn in for this functional
    fid = fopen('./analysis/firstlevel/run_burn_in.txt', 'r');
    line = fgetl(fid);
    pseudorun_burnin(pseudorun_counter) = BurninTRs; 
    real_burn_in = BurninTRs;
    while line ~= -1
        
        % Is this line a match?
        split_line = strsplit(line);
        if strcmp(split_line{1}, functional_run)
            
            % Get the specified burn in
            pseudorun_burnin(pseudorun_counter) = str2num(split_line{2});
            
        elseif strcmp(split_line{1}, sprintf('functional%02d', Functional_Counter))
            
            % Get the specified burn in
            real_burn_in = str2num(split_line{2});
            
            if pseudorun_counter == 1
                % Also store that this pseudorun has a different burn in
                pseudorun_burnin(pseudorun_counter) = str2num(split_line{2});
            end
        end
        line = fgetl(fid);
        
    end
    fclose(fid);
    
    % What is the output nifti
    output_nifti = sprintf('%s/%s_%s.nii.gz', output_nifti_dir, subj, functional_run);
    
    % Get the TRs that bracket this run (including the burn in)
    start_TR = (pseudorun_timestamps(pseudorun_counter, 1) / TR) + real_burn_in;
    end_TR = (pseudorun_timestamps(pseudorun_counter, 2) / TR) + real_burn_in;
    
    fprintf('Taking TRs %d to %d for %s\n\n', start_TR, end_TR, functional_run);
    
    % Split the nifti file in to the pseudoruns
    command=sprintf('fslroi %s %s %d %d', input_nifti, output_nifti, start_TR, end_TR - start_TR)
    unix(command);
    
    % Get the current figure
    current_fig = gcf;
    
    % Run the centroid selection script
    prep_select_centroid_TR(output_nifti, sprintf('%02d%s', Functional_Counter, pseudorun_letter), output_confound_dir, pseudorun_burnin(pseudorun_counter), useRMSThreshold, fslmotion_threshold, mahal_threshold, useCentroidTR, Loop_Centroid_TR, pca_components, '');
    
    % Concatenate the timing files as appropriate
    prep_concatenate_confounds(sprintf('%02d%s', Functional_Counter, pseudorun_letter), output_confound_dir, fslmotion_threshold, useRMSThreshold, mahal_threshold, useExtendedMotionParameters, useExtended_Motion_Confounds,'');

    % Return the figure that was used here
    figure(current_fig);
    
    % Determine if there are any blocks for this run that are included
    Include_Pseudorun(pseudorun_counter) = 0; % Default to zero
    
    for timing_block_counter = 1:length(fieldnames(Timing_File_Struct))
        
        Timing_File_block = Timing_File_Struct.(sprintf('Block_%d', timing_block_counter));
        
        % If there is a block that should be included then specify here
        if ~isempty(Timing_File_block) && Timing_File_block.Include_Run == 1 && Timing_File_block.Include_Block == 1 && any(sum(Timing_File_block.Include_Events, 2)~=0)
            
            % What pseudorun does this block belong to (note that block
            % counter is not necessarily synced up with the actual block
            % counter, it is just blocks that have timing files)
            pseudorun_idx = -1; % Reset
            for block_counter = 1:size(Blocks, 1)
                
                if strcmp(Blocks{block_counter, 1}, Timing_File_block.Name) && strcmp(Blocks{block_counter, 3}, Timing_File_block.BlockName)
                    pseudorun_idx = pseudorun_block(block_counter);
                end
            end
            
            % If all these conditions are met then include this run
            if pseudorun_idx == pseudorun_counter
                Include_Pseudorun(pseudorun_counter) = 1;
            end
        end
    end
end

% If there are any pseudoruns then remake the fsf file and remove any
% inappropriate blocks
if num_pseudoruns > 0 
    
    % Make the fsf files for this new run (use the highres original since
    % this is probably want you should use)
    current_dir = pwd;
    command = sprintf('./scripts/render-fsf-templates.sh %s/analysis/secondlevel/highres_original.nii.gz None pseudorun', current_dir)
    unix(command);
    
    fprintf('\n%d TRs total across the %d pseudoruns (compared to %d possible TRs)\n\n', sum(pseudorun_timestamps(:, 2) - pseudorun_timestamps(:, 1)) / TR, num_pseudoruns, AnalysedData.FunctionalLength(Functional_Counter) / TR);
    
    % Backup files if there are pseudoruns
    AnalysedData.FunctionalLength_bkp(Functional_Counter) = AnalysedData.FunctionalLength(Functional_Counter);
    
    % Update the timing to deal with the fact that some parts of the run
    % may have been excluded (extra burn out)
    AnalysedData.block_onset_time = AnalysedData.block_onset_time - AnalysedData.FunctionalLength(Functional_Counter);
    AnalysedData.FunctionalLength(Functional_Counter) = 0;
    
    % Exclude any fsf and timing files for pseudoruns without any blocks
    for pseudorun_counter = 1:num_pseudoruns
        
        % Get the names
        pseudorun_letter = char('a' + pseudorun_counter - 1);
        functional_run = sprintf('functional%02d%s', Functional_Counter, pseudorun_letter);
    
        % If all of the events are excluded then exclude this run and the
        % timing files for it
        if Include_Pseudorun(pseudorun_counter) == 0
            
            % Move the fsf file if it is excluded
            if exist(sprintf('analysis/firstlevel/%s.fsf', functional_run)) > 0
                movefile(sprintf('analysis/firstlevel/%s.fsf', functional_run), sprintf('analysis/firstlevel/%s_excluded_run.fsf', functional_run));
            end
            
            warning('Pseudorun %s will not be included!\nfsf file for this run has been changed to avoid running this.\nNo timing files were created at firstlevel. The TRs from this run were deleted from the count, hence it will not contribute to the total time (affecting other run timing files).\n', functional_run);
        else
            
            % fsf file labelled for removal but should be included
            if exist(sprintf('analysis/firstlevel/%s_excluded_run.fsf', functional_run)) > 0
                movefile(sprintf('analysis/firstlevel/%s_excluded_run.fsf', functional_run), sprintf('analysis/firstlevel/%s.fsf', functional_run));
                warning('Found analysis/firstlevel/%s_excluded_run.fsf for removal, including it instead\n', functional_run);
            end
            
            % How long was this event
            pseudorun_duration = pseudorun_timestamps(pseudorun_counter, 2) - pseudorun_timestamps(pseudorun_counter, 1);
            
            % If this run is included then accumulate the time
            AnalysedData.block_onset_time = AnalysedData.block_onset_time + pseudorun_duration - (pseudorun_burnin(pseudorun_counter) * TR);
            AnalysedData.FunctionalLength(Functional_Counter) = AnalysedData.FunctionalLength(Functional_Counter) + pseudorun_duration - (pseudorun_burnin(pseudorun_counter) * TR);
            
        end
    end
   
    %% Edit the information for the timing files
    % This takes the timing information stored for each block and updates
    % it based on the new timing
    Original_AnalysedData = AnalysedData; % Store a raw copy
    for block_counter = 1:size(Blocks,1)
        
        % Pull out the experiment and block name
        expt = Blocks{block_counter, 1};
        expt = expt(1:min(strfind(expt, '-')) - 1);
        block_name = Blocks{block_counter, 3};
        
        % What pseudorun does this block belong to
        pseudorun_counter = pseudorun_block(block_counter);
        
        % Pull out the timing information for this block
        if isfield(Original_AnalysedData.(sprintf('Experiment_%s', expt)).(block_name), 'Timing')
            Timing_File_Struct = Original_AnalysedData.(sprintf('Experiment_%s', expt)).(block_name).Timing;
        else
            Timing_File_Struct = [];
        end
        
        % Do you want to make timing files for this pseudorun
        if Include_Pseudorun(pseudorun_counter) == 1
            
            % Check that a timing file will be made for this block
            if ~isempty(Timing_File_Struct) && isfield(Timing_File_Struct, 'Struct_Block_field')
                
                % Pull out the linking index
                Struct_Block_field = Timing_File_Struct.Struct_Block_field;
                
                % Determine the firstlevel timing (the time since the run
                % began)
                Timing_File_Struct.Firstlevel_block_onset = Timing_File_Struct.Firstlevel_block_onset - pseudorun_timestamps(pseudorun_counter, 1) - (pseudorun_burnin(pseudorun_counter) * TR);
                
                % Determine the secondlevel timing. This is tricky because
                % it needs to account for the amount of pseudorun time
                % elapsed since this run began while ignoring cut
                % pseudoruns and burn in time that will be cut out
                
                % When did this functional run begin in secondlevel time
                if Functional_Counter>1
                    %If there is more than one functional run then the elapsed time is the
                    %functional length from the past blocks
                    Secondlevel_run_onset=sum(AnalysedData.FunctionalLength(1:end-1));
                else
                    Secondlevel_run_onset=0;
                end
                
                % How much time has elapsed from the pseudoruns up to this
                % point
                pseudorun_elapsed = 0;
                for elapsed_counter = 1:pseudorun_counter - 1
                    
                    % Is this pseudorun included? If not, don't count it to
                    % the total
                    if Include_Pseudorun(elapsed_counter) == 1
                        
                        % How long did the last pseudorun last
                        pseudorun_duration = pseudorun_timestamps(elapsed_counter, 2) - pseudorun_timestamps(elapsed_counter, 1);
                        
                        % Add this run to the total (know that this window
                        % includes both burn in and burn out
                        pseudorun_elapsed = pseudorun_elapsed + pseudorun_duration;
                    end
                end
                
                % Exclude the burn in if this is not the first pseudor run
                if pseudorun_counter > 1
                    pseudorun_elapsed = pseudorun_elapsed - (pseudorun_burnin(pseudorun_counter) * TR);
                end
                
                % When did this block begin
                Timing_File_Struct.Secondlevel_block_onset = Secondlevel_run_onset + pseudorun_elapsed  + Timing_File_Struct.Firstlevel_block_onset;
                
                % Change the output functional name
                Timing_File_Struct.Functional_name = sprintf('functional%02d%s', Functional_Counter, char('a' + pseudorun_counter - 1));
                
                % Update the timing file structure that will be used for
                % creating the files
                AnalysedData.Timing_File_Struct(Functional_Counter).(Struct_Block_field) = Timing_File_Struct;
                
            end
        else
            % If this pseudorun is to be excluded then empty the timing
            % file struct to ignore it
            if ~isempty(Timing_File_Struct) && isfield(Timing_File_Struct, 'Struct_Block_field')
                
                % Pull out the linking index
                Struct_Block_field = Timing_File_Struct.Struct_Block_field;
                
                % Make the timing file empty
                Timing_File_Struct = [];
                AnalysedData.Timing_File_Struct(Functional_Counter).(Struct_Block_field) = Timing_File_Struct;
            end
        end
        
    end
    
    fprintf('\nFinished\n');
end
