%% Extract timing information for SubMem_Categories
% Prepare details about the timing of the Memory encoding task
%
% Output the AnalysedData and necessary timing file information
%
% First take in the block names
% Store the timing information for each image
% Specify information about the TR timing
%
% Note that this makes files for all events (VPC and encoding) and
% Timing_Condition will separate by VPC and encoded-remembered or
% encoded-forgotten trials (based on looking behavior)
%
% TSY 12/20/2019
% Edits 01/06/2020

function [AnalysedData, Timing]=Timing_SubMem_Categories(varargin)

% What inputs are relevant
GenerateTrials_All=varargin{1};
Data_All=varargin{2};
BlockName=varargin{3};
Data=varargin{4};

% You know the experiment name
ExperimentName='Experiment_SubMem_Categories';

% Pull out experiment specific information
Stimuli=Data_All.(ExperimentName).(BlockName).Stimuli;

%if you pulled from a previous session, you may have 0s
%instead of time stamps --> so we will turn those values to NaNs!
nan_idxs=find(Data.ImageOns==0);

Data.ImageOns(nan_idxs)=NaN;
Data.ITIOns(nan_idxs)=NaN;
%The isVPC part also needs to be nan'd out
Stimuli.isVPC(nan_idxs)=NaN;

% Then let's save these non nan indices because our timing file struct will
% only include the non nan values
non_nans=find(~isnan(Data.ImageOns));


Timing.isVPC=Stimuli.isVPC(non_nans);
Timing.Category=Stimuli.Category(non_nans);

% Presentation duration (not including the ITI)
AnalysedData.TrialDuration=Data.ITIOns - Data.ImageOns;

% Trial starts
AnalysedData.TrialStart=Data.ImageOns;

%Block duration
AnalysedData.BlockDuration=Data.TestEnd- Data.TestStart;

%First TR
AnalysedData.TR_First=Data.TR(1);

%Time between recorded TRs
AnalysedData.TR_Elapsed= Data.TR(2:end) - Data.TR(1:end-1);

%TRs are recorded
AnalysedData.TR=Data.TR;

%Record the data necessary for the event related design

%What is the file name?
Timing.Name=[ExperimentName(min(strfind(ExperimentName, '_'))+1:end), '-Block'];

% How long before the first REAL task event? 
Timing.InitialWait=Data.ImageOns(non_nans(1))-Data.TestStart; %How long before the first task event?

%What is the file name for the events %% only check those that are not
%nans!!
Timing.Events=sum(~isnan(Data.ImageOns));
Timing.Name_Events=repmat({[Timing.Name,'_Events']},Timing.Events,1);

%What are the timing properties of the events

Timing.Task_Event=AnalysedData.TrialDuration(non_nans); %How long is each trial relevant event
Timing.TimeElapsed_Events=[diff(Data.ImageOns(non_nans)); Data.TestEnd-Data.ImageOns(end)]; %How long is it between the image appearances? (includes the ITI)

%Then change the NaNs back to 0s
%Timing.TimeElapsed_Events(isnan(Timing.TimeElapsed_Events))=0;

end