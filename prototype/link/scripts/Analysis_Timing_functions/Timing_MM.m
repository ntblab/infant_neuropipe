%% Extract timing information for the movie presentation
% Prepare details about the timing of the Movie Memory task
%
% Output the AnalysedData and necessary timing file information
%
% First take in the block names
% Store the timing information for each image
% Specify information about the TR timing
%
% this is practically the same script as play video
% T Yates 04/03/2019
%
% now it's much different - name files according to movie
% add in the functionality to open file with sound info
% 07/23/2019

function [AnalysedData, Timing]=Timing_MM(varargin)

%Pull out the data
GenerateTrials_All=varargin{1};
BlockName=varargin{3};
Data=varargin{4};

AnalysedData=struct();

ExperimentName='Experiment_MM';
audio=[]; %preset
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
    
    
    %now figure out what condition it was in
    sound_file='data/Behavioral/MM_sound_info.txt';
    
    if exist(sound_file) > 0
        
        % Load the file
        fid=fopen(sound_file);
        
        while 1
            Line=fgetl(fid);
            
            %if you are not yet at the end of the document
            if all(Line~=-1)
            
                sound_list=strsplit(Line);
            
                %if it matches the block name
                if contains(sound_list{1,1},BlockName)
                
                    %then evaluate whether sound was playing or not
                    audio=str2num(sound_list{2});
                    break %and you can break
                end
            
            %if you don't find it, break at the end of the document
            %Are you at the end of the document
            else
                text=sprintf('Failed to find sound information for %s %s. Assuming there was no audio',ExperimentName,BlockName);
                warning(text)
                
                iBlockName=['NoAudio'];
                
                break
            end
            
        end
        %if you found the block in the file
        if ~isempty(audio)
            
            if audio == 0
                iBlockName=['NoAudio'];
            elseif audio == 1
                iBlockName=['Audio'];
            else
                fprintf('%s not recognized as an indicator of whether there is audio for MM, assuming no audio\n', num2str(audio));
                iBlockName=['NoAudio'];
            end
        end
        %but if we never found it, then tell the experimenter
    else
        text=sprintf('Failed to find sound information for %s %s. Missing the file "data/Behavioral/MM_sound_info.txt" Assuming there was no audio',ExperimentName,BlockName);
        warning(text)
        
        iBlockName=['NoAudio'];
    end
    
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
    Timing.Name=[ExperimentName(min(strfind(ExperimentName, '_'))+1:end), '-', AllBlockNames{BlockNumber},'_',iBlockName];
    
    end
    
end

end

