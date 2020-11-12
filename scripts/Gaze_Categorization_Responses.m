%% Set up the variables that will be used to define the categorization steps for each experiment
% Here are the key code mappings between the responses possible for gaze
% coding, and the conditions those map on to. This also stores information
% for each experiment about how they ought to be coded
%
% If you want to add a key code (e.g. up) or response combination (e.g.
% left vs centre vs undetected) or experiment then find the comments with
% hashes.
%
% To add a new experiment you must add a line to the ExperimentDefinitions
% variable. If necessary you can also add a ResponseStr and ResponseAllowed.
%
%##############################
%
%DO NOT REMOVE! Only add lines! If you remove lines some functionality may
%change without you anticipating it
%
%##############################

%What are the different eye fixation key presses
LeftKey='a'; %Otherwise coded as 1
RightKey='d'; %Otherwise coded as 2
CentreKey='s'; %Otherwise coded as 3
OffCentreKey='x'; %Otherwise coded as 4
PresentKey='e'; %Otherwise coded as 5
UndetectedKey='LeftShift'; %Otherwise coded as 6
OffScreenKey='space'; %Otherwise coded as 0
UpKey='w'; %Otherwise coded as 7
DownKey='z'; %Otherwise coded as 8
UpLeftKey='u'; %Otherwise coded as 9
UpRightKey='i'; %Otherwise coded as 10
DownLeftKey='j'; %Otherwise coded as 11
DownRightKey='k';  %Otherwise coded as 12

% Additional keys
BackKey='b';

% 
% #### IF YOU WANT TO ADD AN ALLOWED RESPONSE CATEGORY, THEN APPEND IT HERE ####
%
% What are the different response names
ResponseNames={'OffScreen', 'Left', 'Right', 'Centre', 'OffCentre', 'Present', 'Undetected', 'Up', 'Down', 'UpLeft', 'UpRight', 'DownLeft', 'DownRight'};

% What is the mapping of the key press and the code (shifted one, so that
% the first index means a code of zero)
% 
% #### IF YOU WANT TO ADD A KEY, THEN APPEND IT HERE ####
%
key_code_mapping = {OffScreenKey, LeftKey, RightKey, CentreKey, OffCentreKey, PresentKey, UndetectedKey, UpKey, DownKey, UpLeftKey, UpRightKey, DownLeftKey, DownRightKey};

% What key codes are allowed for each kind
% 
% #### IF YOU WANT TO ADD AN ALLOWED RESPONSE CATEGORY, THEN APPEND IT HERE ####
%
ResponseAllowed_code{1} = [1, 2, 3, 6, 0];
ResponseAllowed_code{2} = [3, 4, 6, 0];
ResponseAllowed_code{3} = [5, 6, 0];
ResponseAllowed_code{4} = [1, 2, 6, 0];
ResponseAllowed_code{5} = [1, 2, 3, 7, 8, 6, 0];
ResponseAllowed_code{6} = [1, 2, 3, 9, 10, 11, 12 6, 0];

% Convert the codes into lists of allowed responses
for response_categories = 1:length(ResponseAllowed_code)
    
    ResponseStr{response_categories}='';
    for response_options = 1:length(ResponseAllowed_code{response_categories})
        
        % What index of the key code mappings does this response code
        % correspond to?
        Response_idx=ResponseAllowed_code{response_categories}(response_options)+1;
        
        % List the allowed responses
        ResponseAllowed{response_categories}{response_options} =  key_code_mapping{Response_idx};
        
        ResponseStr{response_categories}=sprintf('%s%s: ''%s'', ', ResponseStr{response_categories}, ResponseNames{Response_idx}, key_code_mapping{Response_idx});
           
    end
    
    % Append this to the end to make this response also allowable
    ResponseStr{response_categories} = [ResponseStr{response_categories}, 'Back: ''', BackKey, ''''];
        
end

%Define the experiment name, string to identify the TrialStartMessage (as outputted in the code),
%the string for TrialEndMessage and the response category this task
%falls in to.
% 
% #### IF YOU WANT TO ADD AN EXPERIMENT, THEN APPEND IT HERE ####
%
ExperimentDefinitions={...
    'EyeTrackerCalib', 'Position:', 'End_of_Trial_Time', 1; ...
    'StatLearning', 'Start_Of_Block', 'End', 3; ...
    'Retinotopy', 'SMP', '# Message: Finished_', 5;...
    'PosnerCuing', 'Start_of_Trial_', 'Trial_end_Time', 1; ...
    'PlayVideo_Block_3', 'Movie_Start_Time:_', 'Movie_Stop_Time:_', 3; ...
    };
