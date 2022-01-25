%% Extract timing information for Repetition Narrowing
% Prepare details about the timing of the repetition narrowing task
%
% Output the AnalysedData and necessary timing file information
%
% First take in the block names
% Store the timing information for each image
% Specify information about the TR timing
%
% Created by C Ellis 4/28/18
% Edited T Yates 2019

function [AnalysedData, Timing]=Timing_RepetitionNarrowing(varargin)

%What inputs are relevant
GenerateTrials_All=varargin{1};
Data=varargin{2};
BlockName=varargin{3};
Timing=varargin{4};

%You know the experiment name
ExperimentName='Experiment_RepetitionNarrowing';

% What is the relevant timing information
GenerateTrials=GenerateTrials_All.(ExperimentName);

%Pull out the block names
AllBlockNames=GenerateTrials.Parameters.BlockNames;

%What is the actual block they did
Temp=BlockName(strfind(BlockName, 'Block_')+6 : strfind(BlockName, 'Block_')+7);
BlockNumber=str2double(Temp(isstrprop(Temp, 'digit')));

% NOTE: The following is legacy code to account for changes in the naming of conditions that happened before the data collection reported here
%try this first --> it's the old naming system
Temp1=AllBlockNames{BlockNumber}(strfind(AllBlockNames{BlockNumber}, '; nth')-2 : strfind(AllBlockNames{BlockNumber}, '; nth')-1);
%second oldest naming system
Temp2=AllBlockNames{BlockNumber}(strfind(AllBlockNames{BlockNumber}, '; Block')-1);

if ~isempty(Temp1)
    if str2double(Temp1(isstrprop(Temp1, 'digit')))==1
        iBlockName=[AllBlockNames{BlockNumber}(1:strfind(AllBlockNames{BlockNumber}, ';')-1), '_Reps'];
    else
        iBlockName=[AllBlockNames{BlockNumber}(1:strfind(AllBlockNames{BlockNumber}, ';')-1), '_NoReps'];
    end
    
elseif ~isempty(Temp2(isstrprop(Temp2, 'digit')))
    if str2double(Temp2(isstrprop(Temp2, 'digit')))==1
        iBlockName=[AllBlockNames{BlockNumber}(1:strfind(AllBlockNames{BlockNumber}, ';')-1), '_Reps'];
    else
        iBlockName=[AllBlockNames{BlockNumber}(1:strfind(AllBlockNames{BlockNumber}, ';')-1), '_NoReps'];
    end
    
    %if there is no 'nth', or any type of number
else
    Temp=AllBlockNames{BlockNumber}(1:strfind(AllBlockNames{BlockNumber}, 'Block')-2);
    
    if ~contains(Temp,'Novel')
        iBlockName=[AllBlockNames{BlockNumber}(1:strfind(AllBlockNames{BlockNumber}, ';')-1), '_Reps'];
    else
        iBlockName=[AllBlockNames{BlockNumber}(1:strfind(AllBlockNames{BlockNumber}, ';')-1), '_NoReps'];
    end
    
end

%The block name 'Scenes_Reps' is a lie --> change it accordingly
if contains(iBlockName, 'Scenes_Reps')
    iBlockName='Scenes_NoReps';
end

% Skip a lot if there are no VPC trials
if isfield(Data.(ExperimentName).(BlockName), 'VPC')
    
    % Flip the orientation if there is a coding error
    if size(Timing.LoomingOffs,2)>1
        Timing.LoomingOffs=Timing.LoomingOffs';
    end
    
    % Presentation duration
    AnalysedData.SmallDuration=Timing.LoomingOns - Timing.SmallImageOns;
    AnalysedData.LoomingDuration=Timing.LoomingOffs - Timing.LoomingOns;
    AnalysedData.LargeDuration=Timing.ShrinkingOns - Timing.LargeImageOns;
    AnalysedData.ShrinkingDuration=Timing.ShrinkingOffs - Timing.ShrinkingOns;
    
    % Trial starts
    AnalysedData.TrialStart=Timing.SmallImageOns;
    
    % Trial to trial duration
    AnalysedData.TrialDuration=Timing.SmallImageOns(2:end)-Timing.SmallImageOns(1:end-1);
    
    % How many flips
    AnalysedData.LoomingFlips=Timing.LoomingFlips;
    AnalysedData.ShrinkingFlips=Timing.ShrinkingFlips;
    
    %Block duration
    AnalysedData.BlockDuration=Timing.ShrinkingOffs(end)- Timing.TestStart;
    
end

%First TR
AnalysedData.TR_First=Timing.TR(1);

%Time between recorded TRs
AnalysedData.TR_Elapsed= Timing.TR(2:end) - Timing.TR(1:end-1);

%TRs are recorded
AnalysedData.TR=Timing.TR;

%What is the file name?
Timing.Name=[ExperimentName(min(strfind(ExperimentName, '_'))+1:end), '-', iBlockName];

%Record the data necessary for the event related design. In this case there
%is only one event and it is the entire block of the data before the VPC.
%This file can then be used for analysis, rather than including the VPC

%What is the file name for the events
if isfield(Data.(ExperimentName).(BlockName), 'VPC')
    Timing.Events=1;
    Timing.Name_Events=repmat({[Timing.Name, '_Events']}, Timing.Events,1);
    
    %What are the timing properties of the events
    Timing.Task_Event=AnalysedData.BlockDuration; %How long is each trial relevant event
    Timing.InitialWait=0; %How long before the first task event?
    Timing.TimeElapsed_Events=0; %How long is it between the large image appearances?
end

end


