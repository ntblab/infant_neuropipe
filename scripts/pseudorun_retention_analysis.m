%% Test the number of TRs that would be included at each threshold according to the Deen et al., (2018) threshold analysis
% In this analysis, any motion over 0.5mm is excluded and the preceding TR.
% If there is motion over 2mm then the data is carved into pseudoruns
% (different from the pseudoruns that we created) which must be at least 72s
% long

function output = pseudorun_retention_analysis(output_dir, varargin)

% Preset parameters
framewise_threshold = 0.5;  % How much movement between runs is allowed
pseudorun_threshold = 2;  % How much movement is allowed before a pseudorun is made
TR_duration = 2; % Assume the TR duration is 2s
min_pseudorun_length = 72 / TR_duration; % What is the minimum number of TRs for a pseudorun (equating the duration of pseudoruns from the Deen analysis)
motion_metric = 0; % Do you want to use motion metric or motion parameters for computing between frame motion? If set to zero this is saying whether motion and rotation information are used as an 'or' for exclusion
ignore_resting_state = 1; % Do you want to exclude any time points that were set to resting state, even if the child wasn't moving
ignore_eyetracking = 1; % Do you want to exclude time points where the child's eyes were closed?

% Make directory if it doesnt exist yet
if exist(output_dir, 'dir') == 0
    mkdir(output_dir);
end

% Find the participants
[included_sessions, ParticipantList]=Participant_Index([{'Check_QA', '0'}, varargin{1}]);

% Exclude participants with 1.5s TR
excluded_sessions = {'0315161_dev02', '0319161_dev02'};
included_sessions = setdiff(included_sessions,excluded_sessions);

output.pseudorun_useable = {};
output.pseudorun_total = {};
output.pseudorun_useable_session = {};
output.pseudorun_total_session = {};
for session = included_sessions
    
    % Get the amount of functional data from the participant
    confound_path=sprintf('subjects/%s/analysis/firstlevel/Confounds/', session{1});
    
    % What motion file do you want to use
    if motion_metric == 1
        motion_files = dir(sprintf('%s/MotionMetric_fslmotion_3_functional*.txt', confound_path));
    else
        motion_files = dir(sprintf('%s/MotionParameters_functional*.par', confound_path));
        framewise_threshold(2) = 0.5;
        pseudorun_threshold(2) = 2;
    end
    
    % Iterate through the files
    total_TRs_session=[];
    useable_TRs_session=[];
    figure
    hold on
    for file_counter = 1:length(motion_files)
        
        % Ignore pseudoruns
        if strfind(motion_files(file_counter).name, '.') - strfind(motion_files(file_counter).name, 'functional') == 12
            
            % Pull out functional run from the name
            functional_run = motion_files(file_counter).name(strfind(motion_files(file_counter).name, 'functional') + 10:strfind(motion_files(file_counter).name, '.') - 1);
            
            % Are you using motion metric or motion parameters to compute
            % the threshold
            motion_data = dlmread([confound_path, motion_files(file_counter).name]); % Load in the motion data
            if motion_metric == 1
                % Pull out the framewise displacement
                fd_vals = motion_data;
                
                % Find the timepoints with excessive motion
                ignored_idxs = find(fd_vals > framewise_threshold == 1);
                pseudorun_boundary_idxs = find(fd_vals > pseudorun_threshold == 1);
            else
                
                % Pull out the two information types
                translation = [0, 0, 0; diff(motion_data(:, 1:3))];
                rotation = [0, 0, 0; diff(motion_data(:, 4:6))];
                
                % Get the indexes that pass either threshold
                ignored_idxs = [find(sum(abs(translation), 2) > framewise_threshold(1)); find(sum(abs(rotation), 2) > framewise_threshold(2))];
                pseudorun_boundary_idxs = [find(sum(abs(translation), 2) > pseudorun_threshold(1)); find(sum(abs(rotation), 2) > pseudorun_threshold(2))];
                
            end
            
            % How many TRs are there
            total_TRs = size(motion_data, 1);
            
            % What are the actual idxs of the motion TRs
            ignored_TRs = [ignored_idxs; ignored_idxs - 1]; % Also ignore the preceding TR to mean that the pair of TRs is removed involved in the motion
            ignored_TRs = unique(ignored_TRs);
            ignored_TRs = ignored_TRs(ignored_TRs>0); % Exclude a zero
            
            %% Create the pseudorun boundary
            
            % Cycle through the idxs of pseudorun boundaries and see if
            % there are any that are sufficiently far apart
            lower_bound = 1;
            for boundary_counter = 1:length(pseudorun_boundary_idxs)
                
                % What is the upper bound of this
                upper_bound = pseudorun_boundary_idxs(boundary_counter);
                
                % Which TRs are included
                bounded_ignored_TRs = ignored_TRs(logical(ignored_TRs >= lower_bound & ignored_TRs <= upper_bound));
                
                % What TRs are left after taking out these banded TRs
                pseudorun_idxs=setdiff(lower_bound:upper_bound, bounded_ignored_TRs);
                
                % If this pseudo run has insufficient TRs then make all of
                % those TRs in this run to be ignored
                if length(pseudorun_idxs) < min_pseudorun_length
                    ignored_TRs(end+1:end+upper_bound-lower_bound+1) = lower_bound:upper_bound;
                    
                    ignored_TRs=unique(ignored_TRs);
                end
                
                % Update the lower bound
                lower_bound = upper_bound;
            end
            
            % If there were no pseudorun boundaries (due to >2mm movement)
            % then you might still have to exclude the run because there
            % are not enough points below the framewise threshold
            if isempty(pseudorun_boundary_idxs)
                if(total_TRs - length(ignored_TRs)) < min_pseudorun_length
                    ignored_TRs = 1:total_TRs;
                end
            else
                % If there were boundaries then finish of these steps in
                % order to figure out which TRs were left
                upper_bound = total_TRs;
                
                % Which TRs are included
                bounded_ignored_TRs = ignored_TRs(logical(ignored_TRs >= lower_bound & ignored_TRs <= upper_bound));
                
                % What TRs are left after taking out these banded TRs
                pseudorun_idxs=setdiff(lower_bound:upper_bound, bounded_ignored_TRs);
                
                % If this pseudo run has insufficient TRs then make all of
                % those TRs in this run to be ignored
                if length(pseudorun_idxs) < min_pseudorun_length
                    ignored_TRs(end+1:end+upper_bound-lower_bound+1) = lower_bound:upper_bound;
                    
                    ignored_TRs=unique(ignored_TRs);
                end
                
            end
            
            %% Ignore any TRs that are coded as resting state
            if ignore_resting_state == 1
                timing_path=sprintf('subjects/%s/analysis/firstlevel/Timing/', session{1});
                resting_state_file = dir(sprintf('%s/functional%s*_RestingState-All.txt', timing_path, functional_run));
                
                for block_counter = 1:length(resting_state_file)
                    
                    % Load in the data
                    resting_state = dlmread([resting_state_file(block_counter).folder, '/', resting_state_file(block_counter).name]);
                    
                    % Add all of the TRs corresponding to the resting state
                    lower_bound=(resting_state(:, 1) ./ TR_duration) + 1;
                    upper_bound=((resting_state(:, 1) + resting_state(:, 2)) ./ TR_duration) - 1;
                    for block_counter = 1:length(lower_bound)
                        
                        % Add to the list these TRs
                        ignored_TRs=[ignored_TRs(:); (floor(lower_bound(block_counter)):floor(upper_bound(block_counter)))'];
                    end
                    
                    ignored_TRs=unique(ignored_TRs);
                end
            end
            
            %% Add all of the TRs corresponding to eye tracking exclusion
            if ignore_eyetracking == 1
                EyeData_Exclude_file = sprintf('%s/EyeData_Exclude_Epochs_functional%s.txt', confound_path, functional_run);
                
                if exist(EyeData_Exclude_file, 'file') > 0
                    
                    % Load in the data
                    EyeData_Exclude = dlmread(EyeData_Exclude_file);
                    
                    % Add all of the TRs corresponding to the resting state
                    lower_bound=(EyeData_Exclude(:, 1) ./ TR_duration) + 1;
                    upper_bound=((EyeData_Exclude(:, 1) + EyeData_Exclude(:, 2)) ./ TR_duration) -1;
                    for block_counter = 1:length(lower_bound)
                        
                        % Add to the list these TRs
                        ignored_TRs=[ignored_TRs(:); (floor(lower_bound(block_counter)):floor(upper_bound(block_counter)))'];
                    end
                    
                    ignored_TRs=unique(ignored_TRs);
                end
            end
            %% Draw the figure
            scatter(1:total_TRs, repmat(file_counter, total_TRs, 1), 'g.');
            scatter(ignored_TRs, repmat(file_counter, length(ignored_TRs), 1), 'r.');
            scatter(pseudorun_boundary_idxs, repmat(file_counter, length(pseudorun_boundary_idxs), 1), 'k.');
            
            %% Summarise the run
            
            % Figure out how many TRs are left to be useable after this
            % analysis
            useable_TRs = total_TRs - length(ignored_TRs);
            
            if any(ignored_TRs < 0)
                warning('There are some negative TRs in %s, probably because the onset time of the timing file for this run (%s) has negative values. Fix it and run this again\n', session{1}, functional_run);
                return;
            end
            
            % Store the data for later
            total_TRs_session(end+1) = total_TRs;
            useable_TRs_session(end+1) = useable_TRs;
            
            functional_run = motion_files(file_counter).name(strfind(motion_files(file_counter).name, 'functional')+10:strfind(motion_files(file_counter).name, '.txt')-1);
            output.pseudorun_useable(end+1,:) = {[session{1}, '_', functional_run], useable_TRs};
            output.pseudorun_total(end+1,:) = {[session{1}, '_', functional_run], total_TRs};
            
        else
            fprintf('Not using %s %s\n', session{1}, motion_files(file_counter).name);
        end
    end
    
    % Save the figure
    ylabel('Run number');
    xlabel('TR');
    title(session{1});
    saveas(gcf, [output_dir, '/pseudorun_plot_', session{1}, '.png']);
    
    close
    
    % Store the sessionwise data
    output.pseudorun_useable_session(end+1,:) = {session{1}, sum(useable_TRs_session)};
    output.pseudorun_total_session(end+1,:) = {session{1}, sum(total_TRs_session)};
    
end

% find the age for each session
session_age = [];
for session_counter = 1:size(output.pseudorun_useable_session, 1)
    
    % Pull out the age for this session
    session_age(end + 1) = ParticipantList{strcmp(ParticipantList(:,1), output.pseudorun_useable_session(session_counter, 1)), 3};
    
end

% Report the results here
pseudorun_sessionwise=mean(cell2mat(output.pseudorun_useable(:,2))./cell2mat(output.pseudorun_total(:,2)));
pseudorun_runwise=mean(cell2mat(output.pseudorun_useable_session(:,2))./cell2mat(output.pseudorun_total_session(:,2)));

fprintf('\nUsing the analysis from Deen et al., 2017 we have a sessionwise retention rate of %0.3f\nRunwise the rate is %0.3f\n', pseudorun_sessionwise, pseudorun_runwise);
fprintf('\nSession summary:\nName\t\tAge\tUsable\tTotal\n----------------------------------\n');
for ppt_counter = 1:size(output.pseudorun_useable_session, 1)
    fprintf('%s\t%0.1f:\t%d\t%d\n', output.pseudorun_useable_session{ppt_counter,1}, session_age(ppt_counter), output.pseudorun_useable_session{ppt_counter,2}, output.pseudorun_total_session{ppt_counter,2});
end
fprintf('----------------------------------\n');

% Create a scatter plot of the participant data retention
figure
scatter(cell2mat(output.pseudorun_useable_session(:,2)), cell2mat(output.pseudorun_total_session(:,2)));
xlim([-10, max(cell2mat(output.pseudorun_total_session(:,2)))]);
xlabel('Usable data')
ylabel('Available data');
saveas(gcf, [output_dir, '/sessionwise_usable_data_scatter.png']);

% Save the data
save([output_dir, '/pseudorun_summary.mat'], 'output');

