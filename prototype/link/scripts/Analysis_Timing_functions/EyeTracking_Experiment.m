%%Summarize eye tracking data
%
% By default, eye tracking data is used to exclude epochs of an experiment
% and this is managed automatically.
%
% When experiments have unique uses of eye tracking (e.g., visualizations) 
% use this script to generate these outputs. For instance quantify looking time
% to stimuli. This is also used to create experiment specific exclusion details.
% For instance, in PosnerCuing, we exclude epochs based on whether the participant
% was looking during the cue. To use this function, you will need to make a script
% named: EyeTracking_Experiment_${Experiment}
%
% To add an experiment, create the function which takes in the following
% inputs: EyeData, Data, GenerateTrials. The output is EyeData but probably
% including (any or all) are Weights, ReactionTime and Exclude. Be careful
% when making this that you don't overwrite any of the previous entries
% (Which is why each experiment should have its own subfield of Weights,
% ReactionTime and Exclude)
%
%ResponseKey
% LeftKey='a'; %Otherwise coded as 1
% RightKey='d'; %Otherwise coded as 2
% CentreKey='s'; %Otherwise coded as 3
% OffCentreKey='x'; %Otherwise coded as 4
% PresentKey='e'; %Otherwise coded as 5
% UndetectedKey='LeftShift'; % Otherwise coded as 6
% NoEyeKey='space'; %Otherwise coded as 0
%
% Weights:
% The weights for looking time are output for selected experiments. If these
% exist then they will be read by the Analysis_Timing function and
% written into the weights in the timing file
%
% ReactionTime:
% How long it took the participant to respond to the element of interest on
% this trial.
%
% Exclude:
% Exclude is a field of EyeData which contains an experiment
% structure (some experiments will be missing) which themselves potentially
% contain the following three fields (where each element is an idx as
% specified in Idx_Names):
%       InvalidCodes: What are the coding responses that are deemed invalid
%           and will count towards invalid (defaults to 0)
%       Criterion: What proportion of valid responses are necessary for
%           inclusion (defaults to 0.5)
%       CriticalWindow: What idxs of the timecourse are relevant (defaults
%           to all)
%
% Updated to be modular, C Ellis 6/15/17
function EyeData=EyeTracking_Experiment(EyeData, Data, GenerateTrials)

%Iterate through the experiment counter
EyeData.ReactionTime=struct;
EyeData.Weights=struct;
EyeData.Exclude=struct;

Experiments=fieldnames(EyeData.Aggregate);

currentfig=gcf;

% Cycle through the experiments this participant completed
for ExperimentCounter=1:length(Experiments)
    
    % Run the function for this experiment, if it exists
    EyeTracking_Experiment_Function=str2func(sprintf('EyeTracking_Experiment_%s', Experiments{ExperimentCounter}));
    Function_name=sprintf('EyeTracking_Experiment_%s.m', Experiments{ExperimentCounter});
    if exist(Function_name)==2
        EyeData=EyeTracking_Experiment_Function(EyeData, Data, GenerateTrials);
    end

end

%Return to original figure
try
    figure(currentfig)
    hold on
catch
    fprintf('No figure found so not returning that figure to default\n');
end
