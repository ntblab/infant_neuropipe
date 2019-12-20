%% Extract timing information for Stat Learning
% Prepare details about the timing of the Stat learning task
%
% Output the AnalysedData and necessary timing file information
%
% First take in the block names
% Specify information about the TR timing
%
% Created by C Ellis 7/31/16
function [AnalysedData, Timing]=Timing_StatLearning(varargin)

%What inputs are relevant
GenerateTrials_All=varargin{1};
Data_All=varargin{2};
BlockName=varargin{3};
Data=varargin{4};

%You know the experiment name
ExperimentName='Experiment_StatLearning';
GenerateTrials=GenerateTrials_All.(ExperimentName);

%Guess the block time if you don't have the details
%otherwise
if isfield(Data, 'BlockEndTime')==0
    Data.BlockEndTime=Data.InitPulseTime + Data.totalRunTime;
end

AnalysedData.Duration=Data.BlockEndTime - Data.InitPulseTime;

%Pull out the block names
AllBlockNames=GenerateTrials.Parameters.BlockNames;

%What block is being done?
iBlockCounter=str2num(BlockName(7:end-2));

%Is the sequence structured
if strcmp(AllBlockNames{iBlockCounter}(1), 's')
    iBlockName='Structured';
else
    iBlockName='Random';
end

%What is the file name?
Timing.Name=[ExperimentName(min(strfind(ExperimentName, '_'))+1:end), '-', iBlockName];

% Append block information to a file that is keeping track of whether these
% blocks are included or excluded and if so for what reason



end
