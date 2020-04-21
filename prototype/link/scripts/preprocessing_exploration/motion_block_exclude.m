%% Remake a timing file based on whether blocks should be excluded due to confounds
% Take in a timing file, confound file and an output for the timing file
% Use the confound file to discern the TRs excluded per block
% Recode any blocks that should be excluded with a weight of zero
% Remake the confound file with the regressor of the excluded blocks

function motion_block_exclude(input_timing_file, confound_file, eye_exclude_epoch_file, output_timing_file, regress_out_excluded)

% Do you want to regress out the blocks you have excluded?
if nargin < 5
    regress_out_excluded = 0;
end    


% Convert string to num
if isstr(regress_out_excluded)
    regress_out_excluded = str2num(regress_out_excluded);
end

% Read in the globals
addpath scripts
globals_struct=read_globals; % Load the content of the globals folder

%Hard code the TR
TR=str2num(globals_struct.TR);
proportion_excluded_threshold=0.5; % Same as analysis timing
max_block_duration=100/TR; % Ignore movies
burnout_TR=3;  % How many burn out TRs are there?

% Load in the files
timing_mat =textread(input_timing_file);
confound_mat=dlmread(confound_file);

% Preset
output_timing_mat=timing_mat;
output_timing_mat(:,3) = 1; % Default to assume it is used

% Load in the eye data file, if it exists, and remove those blocks. THis
% will only work at the block level, individual events won't be excluded.
if exist(eye_exclude_epoch_file) > 0
    eye_exclude_epoch = textread(eye_exclude_epoch_file);  % Load the data file
    
    for epoch_counter = 1:size(eye_exclude_epoch, 1)
        idx = find(output_timing_mat(:,1) == eye_exclude_epoch(epoch_counter, 1));
        
        % If you found a match, set it to zero
        if ~isempty(idx)
            output_timing_mat(idx,3) = 0; % Exclude block
        else
            fprintf('No block onset found for eye exclusion epoch starting at %0.2f. Not excluding anything\n', eye_exclude_epoch(epoch_counter, 1)); 
        end
    end
end

%Find the columns with an exclusion
confound_mat=confound_mat(:, sum(confound_mat==1, 1)>0);

% Warn if there are multiple confound TRs in a regressor
if any(sum(confound_mat==1, 1)>1)
    warning('Some regressors have multiple confound TRs in %s', input_timing_file);
end

%Exclude a column if there are duplicates
duplicate_rows=find(sum(confound_mat,2)>1); % FInd duplicate rows
for row_counter=1:length(duplicate_rows)

    % Find the first instance of a duplicate column
    duplicate_columns=find(confound_mat(duplicate_rows(row_counter),:));
    new_columns=setdiff(1:size(confound_mat,2), duplicate_columns(2:end));

    % Rewrite with the new columns
    confound_mat=confound_mat(:,new_columns);
end

% Find the proportion of TRs excluded from each row of the
% timing file and exclude it if it exceeds the threshold
for block_counter=1:size(timing_mat,1)

    % Get the event times
    block_onset = ceil(timing_mat(block_counter, 1) / TR) + 1; % Make the 0th TR equal to 1
    block_duration = ceil(timing_mat(block_counter, 2) / TR) + burnout_TR + 1; % Make it like how analysis timing computes the TR number

    % If the block duration is too long (there was no burn out, often happens with resting state) then shorten it
    if block_onset+block_duration > size(confound_mat, 1)
        block_duration = size(confound_mat, 1) - block_onset + 1;
    end

    % Find the TRs that are excluded
    block_TRs=confound_mat(block_onset:block_onset+block_duration - 1, :);
    proportion_excluded = sum(block_TRs(:))/block_duration;

    % Set the weight to zero on a block that is excluded
    if proportion_excluded >= proportion_excluded_threshold || block_duration > max_block_duration
        output_timing_mat(block_counter, 3) = 0;
        fprintf('Excluding block %d, starting at: %d, duration: %d\n', block_counter, block_onset, block_duration);
    end
end

% Save the file
dlmwrite(output_timing_file, output_timing_mat, 'delimiter', '\t')

if sum(output_timing_mat(:,3)==0) > 0  && regress_out_excluded == 1
    % Make a new Confound file with the excluded blocks set as regressors
    fprintf('Convolving the excluded blocks with the HRF and then combining it with the OverallConfounds\n');
    confound_mat=dlmread(confound_file); % Reload the mat file after editing it
    
    % Take only the excluded blocks
    confound_regressor_mat=output_timing_mat;
    confound_regressor_mat = confound_regressor_mat(confound_regressor_mat(:,3)==0,:);
    confound_regressor_mat(:,3) = 1;
    
    % Save it as a temp file
    excluded_timing_file=[output_timing_file(1:end-4), '_excluded.txt'];
    dlmwrite(excluded_timing_file, confound_regressor_mat, 'delimiter', '\t')
    
    % Convolve the timing matrix with the HR
    excluded_regressor_file=[confound_file(1:end-4), '_excluded.mat'];
    Confound_epoch='analysis/firstlevel/Confounds/Epochs_design.fsf';
    command=sprintf('./scripts/convolve_timing_file.sh %s %s %s', Confound_epoch, excluded_timing_file, excluded_regressor_file)
    unix(command);
    
    % Read in the file
    excluded_regressor=dlmread(excluded_regressor_file);
    
    % Clip the file length to match the confound mat
    excluded_regressor=excluded_regressor(1:size(confound_mat,1));
    
    % Combine the confounds and this new regressor
    confound_mat(:,end+1)=excluded_regressor;
    
    % Save the confound matrix
    dlmwrite(confound_file, confound_mat, 'delimiter', '\t')
end


