%% If there is missing information then add it
%
% Take in the data and then based on what experiment this, define it for
% values that are necessary.
%
% Values missing that will be added:
%
%           TestStart
%           TestEnd
%
% Values changed:
%
% Values removed:
%
% First drafted C Ellis
% Updated C Ellis 12/20/16 to take in the whole blocks information
%
function Timing=Timing_UpdateInformation(Data, ExperimentName)

%Pull out the timing information
Timing=Data.Timing;

if strcmp(ExperimentName, 'Experiment_StatLearning')
    
    %Rename
    if ~isfield(Timing, 'TestStart')
        Timing.TestStart=Timing.InitPulseTime;
    end
    
    if ~isfield(Timing, 'TestEnd')
        if isfield(Timing, 'BlockEndTime')
            Timing.TestEnd=Timing.BlockEndTime;
        else
            Timing.TestEnd=Timing.InitPulseTime + Data.totalRunTime; %Oldest version of experiment
            Timing.totalRunTime=Data.totalRunTime;
        end
    end
   
end