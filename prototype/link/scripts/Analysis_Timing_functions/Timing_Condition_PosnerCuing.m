% Partition events into conditions for PosnerCuing
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
% Conditions in this experiment are based on whether the target (left vs right) and the cue
% appeared (valid vs invalid vs neutral)
%
% First created by C Ellis 2/9/16
function [Name_Condition, Weights]=Timing_Condition_PosnerCuing(varargin)

%Pull out the input information
EyeData=varargin{1};
Timing=varargin{2}; 
EventCounter=varargin{3};
Functional_name=varargin{4};

Weights = {};
for ConditionCounter = 1:size(Timing.ConditionSuffix,2)
    
    %Store the first and second level condition names
    Name_Condition(ConditionCounter).Second{1}=sprintf('PosnerCuing-Condition_%s', Timing.ConditionSuffix{EventCounter,ConditionCounter});
    
    Name_Condition(ConditionCounter).First{1}=[Functional_name, '_', Name_Condition(ConditionCounter).Second{1}];
    
    % Pull out the weights
    if strcmp(Timing.ConditionSuffix{EventCounter, ConditionCounter}(end-2:end), '_RT')
        % Get the RT data (make it a zero if the trial isn't used)
        Weights{ConditionCounter} = EyeData.ReactionTime.PosnerCuing.(Timing.BlockName).ReactionTime(EventCounter);
        Weights{ConditionCounter}(isnan(Weights{ConditionCounter})) = 0;
        
    elseif isfield(EyeData, 'Weights') && isfield(EyeData.Weights, 'PosnerCuing') && isfield(EyeData.Weights.PosnerCuing, 'Parametric') && isfield(EyeData.Weights.PosnerCuing.Parametric, Timing.BlockName)
        Weights{ConditionCounter} = EyeData.Weights.PosnerCuing.Parametric.(Timing.BlockName)(EventCounter);
    else
        Weights{ConditionCounter} = 0;
    end
end
        
