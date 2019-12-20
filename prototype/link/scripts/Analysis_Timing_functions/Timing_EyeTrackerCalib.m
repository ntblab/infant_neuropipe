%% Extract timing information for the memory encoding
% Prepare details about the timing of the Memory encoding task
%
% Output the AnalysedData and necessary timing file information
%
% You don't need much to be analysed
%
% Created by C Ellis 7/31/16
%
% Edited to allow for TR collection TY 04/11/2019

function [AnalysedData, Timing]=Timing_EyeTrackerCalib(varargin)

%What inputs are relevant
BlockName=varargin{3};
Data=varargin{4};

AnalysedData=struct();

%add in timing information in case this is run during a functional run
Timing.Name=['EyeTrackerCalib-', BlockName];

%check if there are TRs that we collected
%also make sure that the timing of the first TR happened after the start of
%the calibration (i.e., you didn't start with the scanner off and continue
%with the scanner on)

if isempty(Data.TR) 
    Timing=struct();

%may want to add an elseif to check TR length / start time etc.
%elseif 
%    Timing=struct();

else
    fprintf('This participant has TRs for EyeTracking Calibration. Was this expected?\n');
    AnalysedData.TrialDuration=Data.TrialOffs-Data.TrialOns;
end


end




