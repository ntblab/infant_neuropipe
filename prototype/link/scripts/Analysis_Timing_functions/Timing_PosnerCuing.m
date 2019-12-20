
%% Extract timing information for Posner Cuing
% Prepare details about the timing of the Posner task
%
% Output the AnalysedData and necessary timing file information
%
% First take in the block names
% Store the timing information for each trial
% Specify information about the TR timing
%
% Created by C Ellis 7/31/16
function [AnalysedData, Timing]=Timing_PosnerCuing(varargin)

%What inputs are relevant
Data_All=varargin{2};
BlockName=varargin{3};
UpdatedTiming=varargin{4};
Window=varargin{5};

%You know the experiment name
ExperimentName='Experiment_PosnerCuing';

%Pull out the experiment specific data
Data=Data_All.(ExperimentName).(BlockName);
TR=Window.TR;

%What is the actual block they did
Temp=BlockName(strfind(BlockName, 'Block_')+6 : strfind(BlockName, 'Block_')+7);
BlockNumber=str2double(Temp(isstrprop(Temp, 'digit')));

if BlockNumber==1
    iBlockName='Exogenous';
else
    iBlockName='Endogenous';
end

%Block duration
AnalysedData.BlockDuration = UpdatedTiming.TestEnd - UpdatedTiming.TestStart;

%What is the file name?
Timing.Name=[ExperimentName(min(strfind(ExperimentName, '_'))+1:end), '-', iBlockName];

% If the block was quit before the participant even did a trial, you might
% want to quit
if ~isfield(UpdatedTiming, 'PostFixationOns')
    return
end

%Presentation duration
AnalysedData.FixationDuration= UpdatedTiming.PostFixationOns - UpdatedTiming.trialstart;
AnalysedData.PostFixationDuration= UpdatedTiming.CueOns(:,2) - UpdatedTiming.PostFixationOns; %Time after a key press and before the cue. Includes TR wait time
AnalysedData.CueDuration= UpdatedTiming.CueTargetOns - UpdatedTiming.CueOns;
AnalysedData.CueTargetDuration= UpdatedTiming.TargetOns - UpdatedTiming.CueTargetOns;
AnalysedData.TargetDuration= UpdatedTiming.ITIOns(:,2) - UpdatedTiming.TargetOns(:,2);
AnalysedData.ITIDuration= UpdatedTiming.ITIOns(:,1);

%Add the time it takes for the first trial to start
Timing.InitialWait=UpdatedTiming.CueOns(1, 2)-UpdatedTiming.TestStart;

% %Add the time from the end of the burn in to the timelocking TR
% %and initialize the value for TotalTime in the events
% Timing.TotalTime_Events=TotalTime+InitialWait;

%How many events/trials are there?
Timing.Events=size(UpdatedTiming.trialstart,1);

%Cycle through the trials that have an ITI (you didn't quit before it finished)
for TrialCounter=1:size(UpdatedTiming.ITIOns,1)
    
    %Pull out the TRs for this trial
    AnalysedData.TR_Elapsed.(sprintf('Trial_%d', TrialCounter))= diff(UpdatedTiming.TR_Trialwise.(sprintf('Trial_%d', TrialCounter)));
   
    %Make the event names
    Timing.Name_Events{TrialCounter,1}=[Timing.Name, '_Events'];
    
    %When is the time locking TR of the trial? This is the first TR after the post fixation onset
    StartingTR=UpdatedTiming.TR(find(UpdatedTiming.TR>UpdatedTiming.PostFixationOns(TrialCounter), 1, 'first')-1);
    
    %If there are no TRs on this trial then skip them. Also skip if the ITI onsets before the last TR (as in there aren't any TRs after this trial ends) 
    if isempty(StartingTR) && (UpdatedTiming.TR(end) < UpdatedTiming.ITIOns(TrialCounter, 2))
        Timing.Events=Timing.Events-1;
        continue
    end
    
    %Assign the conditions for this trial
    if Data.Response.Cue_Location(TrialCounter)==0
        Timing.ConditionSuffix{TrialCounter,1}=[iBlockName, '_Neutral'];
    else
        if Data.Response.isValid(TrialCounter)==1
            Timing.ConditionSuffix{TrialCounter,1}=[iBlockName, '_Valid'];
        else
            Timing.ConditionSuffix{TrialCounter,1}=[iBlockName, '_Invalid'];
        end
    end
    
    if Data.Response.Target_Location(TrialCounter)==1
        Timing.ConditionSuffix{TrialCounter,2}=[iBlockName, '_Left'];
    else
        Timing.ConditionSuffix{TrialCounter,2}=[iBlockName, '_Right'];
    end
    
    % Add the third column which stores the RT data
    Timing.ConditionSuffix{TrialCounter,3} = [iBlockName, '_RT'];
    
end

%How long is the trial relevant event
Timing.Task_Event=UpdatedTiming.ITIOns(:,2) - UpdatedTiming.CueOns(:, 2);
    
% Get the Timing between each event
Timing.TimeElapsed_Events = [diff(UpdatedTiming.CueOns(:, 2)); UpdatedTiming.TestEnd - UpdatedTiming.CueOns(end, 2)];

end
