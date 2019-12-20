% Create the FIR inputs
%
% Creates file
%
%Searches through the neuropipe folder to identify names of files and
%folders and determines whether appropriate names exist.
%
%Specifically to use this there must be the following feat folders:
%   analysis/firstlevel/Exploration/functionalXX_univariate.feat
%
% This will then take the appropriate files and produce a timing file and
% nifti to be used with FIR
%
% C Ellis 05/19/17

function preprocess_FIR

%What is the participant name
path=cd;
Participant=path(max(strfind(path, '/'))+1:end);

%What are the file names
AnalysisFolder='analysis/firstlevel/Exploration';
univariate_folders=dir(sprintf('%s/functional*_univariate.feat', AnalysisFolder)); % What are feat folders

% Set parameters
BurnoutTRs=3; %How many TRs are you taking after the block ends?
round_timing = 1; % Do you want to round timing information down if it is within 2s
max_block_duration=50; % What is the maximum duration of a block in TRs that you want to do FIR on

%Iterate through the files
for FileCounter=1:length(univariate_folders)
    
    %What are the names of the folders that are useful
    univariate_folder=univariate_folders(FileCounter).name;
    FunctionalName=univariate_folder(strfind(univariate_folder, 'functional'):strfind(univariate_folder, '_univariate')-1);
    timingFile=sprintf('%s/%s.txt', AnalysisFolder, FunctionalName); %The original timing file for the experiment
    FIR_timingFile=sprintf('%s/%s_fir.txt', AnalysisFolder, FunctionalName); %The original timing file for the experiment
    OverallConfounds_name=sprintf('analysis/firstlevel/Confounds/OverallConfounds_%s.txt', FunctionalName);
    
    % Create a new nifti file for this run in which all of the
    % redundant rest (e.g. long burn outs) are removed. This means all
    % blocks are the same duration.
    
    filtered_func=sprintf('%s/%s/filtered_func_data.nii.gz', AnalysisFolder, univariate_folder);
    truncatedFile=sprintf('%s/truncated_%s_%s.nii.gz', AnalysisFolder,  Participant, FunctionalName);
    OverallConfounds_output=sprintf('%s/truncated_OverallConfounds_%s.txt', AnalysisFolder, FunctionalName);
    
    % Pull out the TR
    [~, TR] =unix(sprintf('fslval %s pixdim4', filtered_func));
    
    % Convert to number
    if isstr(TR)
        TR=str2num(TR);
    end
    
    % Sometimes stored in ms
    if TR >=1000
        TR=TR/1000;
    end
    
    % Pull out the timing file
    timing=dlmread(timingFile);
    
    % Load the confound parameters
    OverallConfounds=textread(OverallConfounds_name);
    
    % Exclude the blocks that were zeroed out so that if it was
    % excluded due to a quit, it doesn't ruin the other blocks (since
    % quit blocks are much shorter
    timing_excl = timing(timing(:, 3) ~= 0, :);
    
    % Sort the timing file
    [~, idxs]=sort(timing_excl(:,1));
    timing_excl = timing_excl(idxs, :);
    event_durations = unique(timing_excl(:, 2));
    
    % Deal with timing, if specified
    if round_timing == 1
        
        % Specify the TR duration
        if length(event_durations) == 2 && abs(diff(event_durations)) == TR
            
            % Make the timing file the shorter of the times
            timing_excl(:, 2) = min(timing_excl(:, 2));
            
            fprintf('Changing the timing of the event to be %d\n', min(timing_excl(:, 2)));
        end
    end
    
    % Check to see if there is enough functional data for the burnout
    % to finish, otherwise this will crash if the scanner was stopped
    % before the burnout. Also, do not generate this if there are
    % multiple durations in the volume
    required_TRs = (max(timing_excl(:,1) + timing_excl(:,2)) / TR) + BurnoutTRs;
    if required_TRs <= size(OverallConfounds,1) && length(unique(timing_excl(:, 2))) == 1
        
        
        % Cycle through the blocks, making the nifti and the timing file
        truncated_onset=0; % preset
        tempfile='temp_preprocess_fir.nii.gz';
        fir_timing=[];
        included_TRs=[];
        truncated_block_counter = 1;
        for block_counter = 1 : size(timing_excl,1)
            
            % What is the block start time and duration
            block_onset=floor(timing_excl(block_counter,1)/TR);
            block_duration=ceil((timing_excl(block_counter,2)/TR) + BurnoutTRs);
            weight=timing_excl(block_counter, 3);
            
            % If the weight is 1 then store the data
            if weight == 1 && block_duration < max_block_duration
                
                % Pull out the blocks
                Command=sprintf('fslroi %s %s %d %d', filtered_func, tempfile, block_onset, block_duration);
                fprintf('%s\n', Command);
                unix(Command);
                
                % Create a timing file
                fir_timing(truncated_block_counter, :)=[truncated_onset, 1, weight];
                
                % Either copy or append this temporarily created file
                if truncated_block_counter == 1
                    Command=sprintf('cp %s %s', tempfile, truncatedFile);
                    fprintf('%s\n', Command);
                    unix(Command);
                else
                    Command=sprintf('fslmerge -t %s %s %s', truncatedFile, truncatedFile, tempfile);
                    fprintf('%s\n', Command);
                    unix(Command);
                end
                
                % Truncate the Confound file too.
                for TRIdx = block_onset+1:block_onset+block_duration
                    included_TRs(end + 1) = TRIdx;
                end
                
                % What is the elapsed time
                truncated_onset = truncated_onset + block_duration*TR;
                
                % Increment the block counter
                truncated_block_counter = truncated_block_counter + 1;
            end
            
        end
        
        % Were any blocks made? If not then don't make a timing file
        if truncated_block_counter > 1
            
            % Print the results
            fprintf('Timing file for %s\n', FunctionalName);
            fprintf('%d %d %d\n', fir_timing');
            
            % Make the timing file
            dlmwrite(FIR_timingFile, fir_timing, '\t');
            
            % Remove temp file
            unix(sprintf('rm -f %s', tempfile));
            
            % Make the confound file
            OverallConfounds_id=fopen(OverallConfounds_output, 'w');
            
            % Trim the included TRs to account for any that may exceed the duration of
            % the functional (if there wasn't a full burn out
            included_TRs = included_TRs(included_TRs <= size(OverallConfounds, 1));
            
            %             % Figure out which time points won't be included and thus the confounds are
            %             % irrelevant
            %             confound_idxs = sum(OverallConfounds > repmat((max(OverallConfounds) / 2), size(OverallConfounds, 1), 1), 1) == 1; % Find the idxs that are confounds
            %             usable_confound_idxs = sum(OverallConfounds(included_TRs, :) > repmat((max(OverallConfounds) / 2), length(included_TRs), 1), 1) == 1; % Take only the included TR confounds
            %             usable_coefs = [find(confound_idxs == 0), find(usable_confound_idxs == 1)];
            
            % Write all of the included timepoints
            for TRIdx = included_TRs
                %                 fprintf(OverallConfounds_id, sprintf('%s\n', sprintf('%d ', OverallConfounds(TRIdx, usable_coefs)')));
                fprintf(OverallConfounds_id, sprintf('%s\n', sprintf('%d ', OverallConfounds(TRIdx, :)')));
            end
            
            % Finish up
            fclose(OverallConfounds_id);
            
            % Decorrelate data and deal with missing columns
            motion_decorrelator(OverallConfounds_output, OverallConfounds_output);
        else
            fprintf('No timing information was stored for %s because this run was excluded\n', univariate_folder);
        end
    else
        
        if required_TRs <= size(OverallConfounds,1)
            % If there are not enough TRs, skip this run and continue
            fprintf('There are insufficient TRs to continue for %s. Confound file has %d TRs, necessary TRs is %d\n\n', univariate_folder, size(OverallConfounds,1), required_TRs);
        else
            fprintf('There is more than one unique block duration in %s so not using any times\n', univariate_folder)
        end
    end
    
    
end