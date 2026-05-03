%% Extract timing information for the movie presentation
% Prepare details about the timing of the Cartoon vs. Realistic videos
%
% Output the AnalysedData and necessary timing file information
%
% First take in the block names
% Store the timing information for each image
% Specify information about the TR timing
%
% similar to MM / ChildPlay
% T Yates 03/10/2022

function [AnalysedData, Timing]=Timing_CartoonLive(varargin)

%Pull out the data
GenerateTrials_All=varargin{1};
BlockName=varargin{3};
Data=varargin{4};

AnalysedData=struct();

ExperimentName='Experiment_CartoonLive';
Timing=struct();

%If no frames are played then skip this
if sum(Data.Movie_1.Frames.Local>0)>0
    
    %Frame information
    
    %What is the last possible frame with a timing entry (a zero means
    %that that frame wasnt shown)
    MaxIndex= min(find(Data.Movie_1.Frames.Local==0))-1;
    
    %Make it the last if there are no zero frames.
    if isempty(MaxIndex)
        MaxIndex=length(Data.Movie_1.Frames.Local);
    end
    
    % check if you have TRs 
    if isempty(Data.TR)
        Timing=struct();
    else
        
        AnalysedData.MovieStart = Data.Movie_1.movieStart.Local;
        AnalysedData.Frames_Elapsed = MaxIndex;
        AnalysedData.Frames_Dropped = Data.Movie_1.DroppedFrames;
        AnalysedData.Movie_Duration = Data.Movie_1.movieEnd.Local - Data.Movie_1.movieStart.Local;
        AnalysedData.MovieEnd = Data.Movie_1.movieEnd.Local;
   
    %Pull out the block names
    AllBlockNames=GenerateTrials_All.(ExperimentName).Parameters.BlockNames;
    
    %what block again?
    Temp=BlockName(strfind(BlockName, 'Block_')+6 : strfind(BlockName, 'Block_')+7);
    BlockNumber=str2double(Temp(isstrprop(Temp, 'digit')));
    
    %add the condition info to the name
    Timing.Name=[ExperimentName(min(strfind(ExperimentName, '_'))+1:end), '-', AllBlockNames{BlockNumber}];
    
       
    end
end

end

