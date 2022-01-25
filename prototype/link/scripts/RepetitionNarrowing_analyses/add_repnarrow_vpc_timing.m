% Function to update the timing files for repetition narrowing to include
% the VPC as events
%
% This function is to be run after FunctionalSplitter 
%
% First, this function creates the VPC and star event timing files for different condition types
% (this was neglected when creating timing files during analysis timing)
% Then, the VPC and star event timing files are combined for a given second level analysis
% so they can then be used in the GLM analyses 
%
%02/24/2019 T Yates
%add in the star timing
%06/27/2019
%Change based on secondlevel analysis folder
%11/07/2019

function add_repnarrow_vpc_timing(SecondLevelAnalysisFolder,file_type)

% default values
if nargin==0
    SecondLevelAnalysisFolder='default';
    file_type='';
elif nargin==1
    file_type='';
end

%name of the directory
secondleveldir='analysis/secondlevel_RepetitionNarrowing/'; 
outputdir =sprintf('analysis/secondlevel_RepetitionNarrowing/%s/Timing/',SecondLevelAnalysisFolder); 

%timing files
if ~isempty(file_type)
    TimingFiles=dir([secondleveldir, sprintf('%s/Timing/*-*%s*.txt',SecondLevelAnalysisFolder,file_type)]);
else
    TimingFiles=dir([secondleveldir, sprintf('%s/Timing/*-*.txt',SecondLevelAnalysisFolder)]);
end

%Get the names of the concatenated files
Concat.Block.Files={};
Concat.Block.Mat={};
Concat.Block.Name={};

Concat.Events.Files={};
Concat.Events.Mat={};
Concat.Events.Name={};

Concat.Condition.Files={};
Concat.Condition.Mat={};
Concat.Condition.Name={};

% other files 
Concat.Other.Files={};
Concat.Other.Mat={};
Concat.Other.Name={};

%Load them
for TimingFileCounter=1:length(TimingFiles)
    
    %What timing file is it on this trial
    iTimingFile=TimingFiles(TimingFileCounter).name;
    
    %Store the timing file
    if ~isempty(strfind(iTimingFile, 'Events')) & isempty(strfind(iTimingFile, 'VPC')) & isempty(strfind(iTimingFile, 'Star'))% don't include if VPC and Start timing has already been made
        % if this is not a block or FIR file 
        if isempty(strfind(iTimingFile, 'Block')) & isempty(strfind(iTimingFile, 'FIR')) &  isempty(strfind(iTimingFile, 'Train'))  & isempty(strfind(iTimingFile, 'Test'))   
            Type='Events'; %This is a timing file for the event
        else
            Type='Other';
        end
    elseif ~isempty(strfind(iTimingFile, 'Condition')) 
        Type='Condition'; %This is a timing file for the conditions
    else
        Type='Block'; %If it is neither then assume this is block timing
    end
    
    %Store the relevant information
    Concat.(Type).Files{end+1}=iTimingFile;
    Concat.(Type).Name{end+1}=iTimingFile(1:strfind(iTimingFile, '-')-1);
    %Concat.(Type).Mat{end+1}=textread([secondleveldir, sprintf('%s/Timing/',SecondLevelAnalysisFolder), iTimingFile]);
    Concat.(Type).Mat{end+1}=textread([outputdir, iTimingFile]);
    
end

vpclength = 5; %how long is the VPC?
starlength=6; %how long is the star fixation?
vpcMatrix = []; %preset the VPC matrix
starMatrix=[]; %preset the star matrix 

%We can make the event files for the vpc based on the Event mat files
for MatCounter=1:length(Concat.Events.Mat)
    
    % Read in the timing file
    timing = Concat.Events.Mat{1,MatCounter};
   
    vpcstarttimes = timing(:,1) + timing(:,2) + starlength; %vpc starts the first time stamp after the end of the 6 second fixation stimulus
    temp = repmat(vpclength, length(vpcstarttimes));
    vpclengthtimes =temp(:,1); %temp make a repeating matrix
    lastcolumn =timing(:,3); %second column in new timing file is the length of the VPC
    newmatrix =[vpcstarttimes,vpclengthtimes,lastcolumn]; %form the matrix!
    
    filename = Concat.Events.Files{MatCounter};
    blockname = filename(1:strfind(filename,'_Events')-1); %name 
    
    % save name
    vpcname = strcat(blockname,file_type,'_VPC_Events.txt');
    
    output=strcat(outputdir,vpcname);
   
    % Save the new matrix
    dlmwrite(output, newmatrix, '\t');
    
    vpcMatrix = [vpcMatrix; newmatrix]; %add to the end 
    
    %Don't forget the star! 
    starstarttimes = timing(:,1) + timing(:,2); 
    temp = repmat(starlength, length(vpcstarttimes));
    starlengthtimes =temp(:,1); %temp make a repeating matrix
    starlastcolumn =timing(:,3); %second column in new timing file is the length of the VPC
    starmat=[starstarttimes,starlengthtimes,starlastcolumn]; %form the matrix!
    
    % save name
    starname = strcat(blockname,file_type,'_Star_Events.txt');
    
    output=strcat(outputdir,starname);
   
    % Save the new matrix for stars
    dlmwrite(output, starmat, '\t');
    
    starMatrix = [starMatrix; starmat]; %add to the end  
    
end

%Now that all of those are saved separately, we should combine them for the GLM 

VPCname = strcat('RepetitionNarrowing-All',file_type,'_VPC_Events.txt');
VPCoutput=strcat(outputdir,VPCname);
   
% Save the new matrix
dlmwrite(VPCoutput, vpcMatrix, '\t');

% And stars
Starname = strcat('RepetitionNarrowing-All',file_type,'_Star_Events.txt');
Staroutput=strcat(outputdir,Starname);
   
% Save the new matrix
dlmwrite(Staroutput, starMatrix, '\t');
    

end
