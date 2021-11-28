%% Take the eye tracker regressors and concatenate them
%
% Inputs are the name of the output data file, the name of the movie as it was being collected, the movie length, the experiment that was run, and the shift
% Specify the shift you want to use to align the eye tracking data to the fMRI data (-2 would be appropriate)

function generate_eyetracker_confounds(output_name, movie, movie_length, experiment_name, shift)

% Get the globals
addpath scripts

% Convert from streng
if isstr(movie_length)
    movie_length = str2num(movie_length);
end

% Get the timing files for this participant by looking at second level
timing_dir = sprintf('analysis/secondlevel_%s/default/Timing/', experiment_name);
timing_file = [timing_dir, movie,'Only.txt'];

% Get the analysed data so that you can confirm the block type
load('analysis/Behavioral/AnalysedData.mat', 'AnalysedData');

% Get the block names from these movies
block_names = {};
for temp_block_name = fieldnames(AnalysedData.(sprintf('Experiment_%s', experiment_name)))'
    
    % Is this block of the conditon we care about?
    block_struct = AnalysedData.(sprintf('Experiment_%s', experiment_name)).(temp_block_name{1});
    
    if isfield(block_struct, 'Timing')
        temp_movie = block_struct.Timing.Name;
        
        % Check the movie is in this block and that it is included
        if strcmp(temp_movie, movie(1:end-1)) && block_struct.Include_Block
            fprintf('Found %s for %s\n', temp_movie, temp_block_name{1});
            
            % store the block names
            block_names{end + 1} = temp_block_name{1};
            
        end
    end
end

% Get the order the blocks were in, store the names
timing_mat = dlmread(timing_file);

% Check that the sizes of the files is as expected
if size(timing_mat, 1) ~= length(block_names)
    warning('Number of lines in timing_mat (%d) does not match number of blocks found (%d)', size(timing_mat, 1), length(block_names))
end

% Load the regressors and extend them to movie length
eye_reg_all = zeros(movie_length, length(block_names));

for block_counter = 1:length(block_names)
    reg_name = sprintf('analysis/Behavioral/MM_%s.txt', block_names{block_counter});
    
    % If the file exists then load it, otherwise make a dummy
    if exist(reg_name) == 2
        eye_reg = dlmread(reg_name);
    else
        eye_reg = zeros(movie_length, 1);
        warning('Could not find %s', reg_name);
    end
    
    eye_reg_all(1:length(eye_reg), block_counter) = eye_reg;
end

% Shift regressor by the specified amount
if shift < 0 % This means delayed onset
    
    % Append some elements at the start and remove from the end
    eye_reg_all = [zeros(abs(shift), size(eye_reg_all, 2)); eye_reg_all(1:end - abs(shift), :)];
    
elseif shift > 0 % This means predictive onsets
    
    % Append some elements at the start and remove from the end
    eye_reg_all = [eye_reg_all(abs(shift) + 1:end, :); zeros(abs(shift), size(eye_reg_all, 2))];
end

if length(block_names) > 1
    fprintf('%d blocks were detected. Only going to use the first one but check this correct\n', length(block_names));
end

% Append the regressors from a participant
eye_reg = eye_reg_all(:, 1);

% Store the file
dlmwrite(output_name, eye_reg);

fprintf('%d TRs closed for %s\n', sum(eye_reg), output_name);



