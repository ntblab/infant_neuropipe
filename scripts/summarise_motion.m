%% Check the global motion parameters from each participant
%
% Load in all of the motion information and average

function output = summarise_motion(output_name, varargin)

% How much motion makes it an outlier
translation_threshold = 3;

% Get the participants
[included_sessions, ParticipantList]=Participant_Index([{'Check_QA', '0'}, varargin{1}]);

output.sessionwise_mean_motion=[];
output.sessionwise_outlier_motion=[];
output.sessions = {};
for session = included_sessions
    
    % Get the amount of functional data from the participant
    confound_path=sprintf('subjects/%s/analysis/firstlevel/Confounds/', session{1});
    motion_files = dir(sprintf('%s/MotionMetric_fslmotion_1_functional*.txt', confound_path));
    
    % Iterate through the files
    runwise_mean_motion = [];
    runwise_outlier_motion = [];
    for file_counter = 1:length(motion_files)
        
        % Pull out the framewise displacement
        fd_vals = dlmread([confound_path, motion_files(file_counter).name]);
        
        % How much motion is there per run
        runwise_mean_motion(end+1) = mean(fd_vals);
        runwise_outlier_motion(end+1) = mean(fd_vals < translation_threshold);
        
    end
    
    % Summarise and store the session
    output.runwise_mean_motion.(['ppt_', session{1}]) = runwise_mean_motion;
    output.runwise_outlier_motion.(['ppt_', session{1}]) = runwise_outlier_motion;
    output.sessionwise_mean_motion(end+1) = mean(runwise_mean_motion);
    output.sessionwise_outlier_motion(end+1) = mean(runwise_outlier_motion);
    output.sessions{end+1} = session{1};
    
end

save(output_name, 'output');