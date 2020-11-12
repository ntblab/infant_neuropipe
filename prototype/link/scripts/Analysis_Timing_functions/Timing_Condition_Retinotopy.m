% Partition events into conditions for Retinotopy (radialand horizontal/vertical conditions)
%
% This is how Timing_Condition_$Experiment works. For this experiment find
% the condition filenames. These names are stored in the following format.
% For each element of the Name_Condition structure outlines a different way
% of organizing the events (e.g. Left vs right, or valid vs invalid vs
% neutral). The subfields of this structure refer to each level (first or
% second) that these timing files will be made for. Finally for each level
% there are indexes of cells referring to the different possible names for
% this condition. Usually this will only be one element long but if an
% event belongs to multiple conditions simultaneously (if the conditions
% aren't mutually exclusive, like if the conditions were features of a
% stimulus) then this corresponds to different elements of this field. To
% ignore an event, supply nans.
%
% Conditions in this experiment are based on differences in looking time,
% as specified in weights
%
% First created by C Ellis 8/15/17
function [Name_Condition, Weights]=Timing_Condition_Retinotopy(varargin)

%Pull out the input information
Timing=varargin{2};
EventCounter=varargin{3};
Functional_name=varargin{4};

Block=Timing.Name(strfind(Timing.Name, '-')+1:end);

% Make condition files if you have the appropriate variables
if isfield(Timing, 'Stimuli_sequence')
    
    % What is the stimulus sequence
    Stimuli_sequence=Timing.Stimuli_sequence;
    
    %Iterate through each wedge
    for ConditionCounter = 1:size(Stimuli_sequence,2)
        
        %Specify the  timing file names. Make sure these don't
        %have the name of an experiment or else they will be used in
        %FunctionalSplitter
        
        %What condition is it
        Weights{ConditionCounter}=Stimuli_sequence(EventCounter, ConditionCounter);
        
        Base_Name=['Retinotopy-Condition_', Block, '_', num2str(ConditionCounter)];
        
        %Store the first and second level names
        if Weights{ConditionCounter}~=0
            Name_Condition(ConditionCounter).Second{1}=Base_Name;
            Name_Condition(ConditionCounter).First{1}=[Functional_name, '_', Base_Name];
        else
            Name_Condition(ConditionCounter).Second{1}=NaN;
            Name_Condition(ConditionCounter).First{1}=NaN;
        end
        
    end
elseif  isfield(Timing, 'Event_Conditions')
    % If you made a horizontal/vertical labels then use them here
    
    %What condition is it
    Weights={1};

    Base_Name=['Retinotopy-Condition_', Timing.Event_Conditions{EventCounter}];

    %Store the first and second level names
    Name_Condition.Second{1}=Base_Name;
    Name_Condition.First{1}=[Functional_name, '_', Base_Name];
end