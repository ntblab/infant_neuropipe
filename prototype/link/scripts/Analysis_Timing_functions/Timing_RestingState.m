%% Extract timing information for Resting state
% Prepare details about the timing of the resting state data collection.
% This will create an event file in order to force a burn in and burn out
%
% Output the AnalysedData and necessary timing file information
%
% First take in the block names
% Specify information about the TR timing
%
% Created by C Ellis 7/31/16
function [AnalysedData, Timing]=Timing_RestingState(varargin)

%What inputs are relevant
Data=varargin{4};

%You know the name
ExperimentName='Experiment_RestingState';

%How long is the block?
AnalysedData.Duration=Data.Duration;

%What is the file name?
Timing.Name=[ExperimentName(min(strfind(ExperimentName, '_'))+1:end), '-All'];

% Timing.Name_Events={[ExperimentName(min(strfind(ExperimentName, '_'))+1:end), '-DefaultLength']};
% Timing.Events=1;
% Timing.Task_Event=110; %Set so it is constant across participants
% Timing.InitialWait=0; % This could be non zero if you want to remove any lag between experiments
% Timing.TimeElapsed_Events=0;
% 
% if (Timing.Task_Event+Timing.InitialWait)>AnalysedData.Duration
%     
%     Timing.Task_Event=AnalysedData.Duration-Timing.InitialWait;
%     warning('Resting state scan insufficient length, setting to max possible duration: %0.1f', Timing.Task_Event)
%     
% end