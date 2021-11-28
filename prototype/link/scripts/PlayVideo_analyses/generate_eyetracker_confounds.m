%% Take the eye tracker regressors and concatenate them
% 
% Specify the shift you want to use to align the eye tracking data to the fMRI data (-2 would be appropriate but you maybe want to do that at a later step)
%
function generate_eyetracker_confounds(output_name, movie, movie_length, experiment_name, shift)

% Get the globals
addpath scripts
globals_struct=read_globals();


% Convert from streng
if isstr(movie_length)
    movie_length = str2num(movie_length);
end

% Get the timing files for this participant by looking at second level
timing_dir = sprintf('analysis/secondlevel_%s/default/Timing/', experiment_name);
timing_files = dir([timing_dir, movie(1:end-1),'*Only.txt']);

% Get the analysed data so that you can confirm the block type
load('analysis/Behavioral/AnalysedData.mat', 'AnalysedData');

% Get the order the blocks were in, store the names
block_names_unordered = {};
onsets=[];
for timing_counter = 1:length(timing_files)
    
    % Pull out the timing information
    timing_mat = dlmread([timing_dir, timing_files(timing_counter).name]);
    onsets(timing_counter) = timing_mat(1,1);
    
    % Pull out the name
    timing_name = timing_files(timing_counter).name;
    timing_name(strfind(timing_name, '-')) = '_'; % Convert hyphens to underscores
    block_names_unordered{timing_counter} = timing_name(1:strfind(timing_name, '_Only')-1);
end

% Order the blocks
[~, order] = sort(onsets);
block_names = block_names_unordered(order);

% Load the regressors and extend them to 74
eye_reg_all = zeros(movie_length, length(block_names));
for block_counter = 1:length(block_names)
    
    reg_name = sprintf('analysis/Behavioral/%s.txt', block_names{block_counter});
    
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

% Append the regressors from a participant
eye_reg = eye_reg_all(:);

% If there is only one movie then append some zeros
if size(eye_reg_all, 2) == 1
    eye_reg = [eye_reg_all; zeros(movie_length, 1)];
end

% Store the file
dlmwrite(output_name, eye_reg);

fprintf('\n%d TRs closed for %s\n', sum(eye_reg), output_name);