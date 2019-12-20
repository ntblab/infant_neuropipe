%% Edit event information
%
% This script should be used sparingly to fix instances in which events
% occurred in the experiment but were not partitioned by the Gaze coding
% files. If used wrong, this can introduce substantial issues
% 
% The idea of this script is to edit the events that have been pulled out
% and aggregated by the EyeTracking_Aggregate. In service of this you MUST
% edit all of the relevant fields of EyeData to be consistent: Indexes,
% ImageList, IdxNames, Aggregate, Timing, onset_frame. You may want to cut
% corners by only changing some of these but if you do, beware that this
% may be disasterous for you.
%
% To add an experiment, create the function which takes in the following
% input: EyeData and outputs EyeData.
%
% Created by, C Ellis 8/20/19

function EyeData = EyeTracking_Edit_Events(EyeData, Data, GenerateTrials)

Experiments=fieldnames(EyeData.Aggregate);
currentfig=gcf;

% Cycle through the experiments this participant completed
for ExperimentCounter=1:length(Experiments)
    
    % Run the function for this experiment, if it exists
    EyeTracking_Experiment_Function=str2func(sprintf('EyeTracking_Edit_Events_Experiment_%s', Experiments{ExperimentCounter}));
    Function_name=sprintf('EyeTracking_Edit_Events_Experiment_%s.m', Experiments{ExperimentCounter});
    if exist(Function_name)==2
        warning('Editing events for %s. Make sure this works as expected', Experiments{ExperimentCounter});
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