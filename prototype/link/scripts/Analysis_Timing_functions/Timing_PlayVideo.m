%% Extract timing information for the movie presentation
% Prepare details about the timing of the Memory encoding task
%
% Output the AnalysedData and necessary timing file information
%
% First take in the block names
% Store the timing information for each image
% Specify information about the TR timing
%
% Created by C Ellis 7/31/16
function [AnalysedData, Timing]=Timing_PlayVideo(varargin)

%Pull out the data
BlockName=varargin{3};
Data=varargin{4};


AnalysedData=struct();

%Is it a scanning block? If so then make a timing file name
if strcmp(BlockName(1:7), 'Block_3')
    Timing.Name=['PlayVideo-', BlockName];
else
    
    Timing=struct();
end
%try %The data might not be organized the same

Fields=fieldnames(Data); %Store the names of the fields
MovieNumber=sum(cell2mat(strfind(Fields, 'Movie_')));

if MovieNumber>0
    for MovieCounter=1:MovieNumber
        
        %If no frames are played then skip this
        if sum(Data.(sprintf('Movie_%d', MovieCounter)).Frames.Local>0)>0
            
            %Frame information
            
            %What is the last possible frame with a timing entry (a zero means
            %that that frame wasnt shown)
            MaxIndex= min(find(Data.(sprintf('Movie_%d', MovieCounter)).Frames.Local==0))-1;
            
            %Make it the last if there are no zero frames.
            if isempty(MaxIndex)
                MaxIndex=length(Data.(sprintf('Movie_%d', MovieCounter)).Frames.Local);
            end
            
            AnalysedData.MovieStart(MovieCounter) = Data.(sprintf('Movie_%d', MovieCounter)).movieStart.Local;
            AnalysedData.Frames_Elapsed(MovieCounter) = MaxIndex;
            AnalysedData.Frames_Dropped(MovieCounter) = Data.(sprintf('Movie_%d', MovieCounter)).DroppedFrames;
            AnalysedData.Movie_Duration(MovieCounter) = Data.(sprintf('Movie_%d', MovieCounter)).movieEnd.Local - Data.(sprintf('Movie_%d', MovieCounter)).movieStart.Local;
            AnalysedData.MovieEnd(MovieCounter) = Data.(sprintf('Movie_%d', MovieCounter)).movieEnd.Local;
            
        end
    end

end

end

