% Identify subjects that meet specified criteria
%
% Look through all the details of each participant and identify them based
% on the supplied criteria. This is useful when trying to find all the
% participants wtihin a certain age or have all completed a certain
% experiment. The way this works is with the varargin format
%
% Example command:
% Participant_Index({'included_sessions', {'dev'}, 'Max_Age', 36})
% will list all the sessions with 'dev' in their name AND have an age of less 
% than 36 months. Note that some critiera, like 'included sessions', it accepts a cell
% which can list multiple strings to match for
%
% Note that with adult participants in this directory, the age
% functionality still works, it is just a little clunky to report an
% adult's age in months.
%
% Criteria available:
%
% Min_Age (double):
% How old in months is the minimum to be included.
%
% Max_Age (double):
% How old in months is the maximum to be included
%
% Min_SNR (double):
% The minimum SNR for inclusion
%
% Max_SNR (double):
% The maximum SNR for inclusion
%
% Min_SFNR (double):
% The minimum SFNR for inclusion
%
% Max_SFNR (double):
% The maximum SFNR for inclusion
%
% Experiments (cell):
% Experiment (or experiments) specifying which experiments you are
% interested in
%
% Check_QA (binary):
% If you want to skip checking the QA (time consuming) then set this to
% zero
%
% excluded_sessions (cell):
% Specify the session names that are to be excluded from this. Can use part
% names in order to exclude all names that exclude this string
%
% included_sessions (cell):
% Specify the session names that are to be included from this. Will
% overwrite the results of excluded sessions if used. Can use part names in
% order to exclude all names that exclude this string
%
% C Ellis 6/27/17
function [Choosen_Participants, ParticipantList] =Participant_Index(varargin)

% Get the project directory
addpath prototype/link/scripts
globals_struct=read_globals('prototype/link/'); % Load the content of the globals folder

proj_dir = globals_struct.PROJ_DIR;

% What is the participant information?
fid=fopen([proj_dir, '/scripts/Participant_Data.txt']);

ParticipantList={};

while 1
    line=fgetl(fid);
    
    if all(line==-1)
        break
    end
    
    % Change the months to number from a string
    words=strsplit(line);
    words{3}=str2num(words{3});
    
    ParticipantList(end+1,1:3)=words;
end
fclose(fid);

% Set the baseline

Experiments={};
Min_Age=0;
Max_Age=inf;
Min_SNR=0;
Max_SNR=inf;
Min_SFNR=0;
Max_SFNR=inf;
run_QA=1;

% Iterate through the input arguments
counter=1;
if length(varargin)>0
    while counter<=length(varargin{1})
        if strcmp(varargin{1}{counter}, 'Experiments')
            Experiments=varargin{1}{counter+1};
        elseif strcmpi(varargin{1}{counter}, 'Min_Age')
            Min_Age=str2double(num2str(varargin{1}{counter+1}));
        elseif strcmpi(varargin{1}(counter), 'Max_Age')
            Max_Age=str2double(num2str(varargin{1}{counter+1}));
        elseif strcmpi(varargin{1}{counter}, 'Min_SNR')
            Min_SNR=str2double(num2str(varargin{1}{counter+1}));
        elseif strcmpi(varargin{1}{counter}, 'Max_SNR')
            Max_SNR=str2double(num2str(varargin{1}{counter+1}));
        elseif strcmpi(varargin{1}{counter}, 'Min_SFNR')
            Min_SFNR=str2double(num2str(varargin{1}{counter+1}));
        elseif strcmpi(varargin{1}{counter}, 'Max_SFNR')
            Max_SFNR=str2double(num2str(varargin{1}{counter+1}));
        elseif strcmpi(varargin{1}{counter}, 'excluded_sessions')
            excluded_sessions=varargin{1}{counter+1};
        elseif strcmpi(varargin{1}{counter}, 'included_sessions')
            included_sessions=varargin{1}{counter+1};
        elseif strcmpi(varargin{1}{counter}, 'Check_QA')
            run_QA=str2double(num2str(varargin{1}{counter+1}));
        end
        counter=counter+2;
    end
end

% Check the commands don't conflict
if run_QA==0 
    if Max_SNR~=inf || Max_SFNR~=inf || Min_SFNR~=0 || Min_SFNR~=0
        warning('Must run QA if the SFNR or SNR criterion are set. Aborting');
        return
    end
end

% Pull info from the list
Participant_Names=ParticipantList(:,1);
Age_List=cell2mat(ParticipantList(:,3));

participant_dir=dir('subjects/');
participant_dir = participant_dir(arrayfun(@(x) ~strcmp(x.name(1),'.'), participant_dir));

fprintf('\nParticipants who meet the criteria:\n')

% Iterate through the participant directory names
Choosen_Participants={};
for participant_counter=1:length(participant_dir)
    
    %Preset values
    ExperimentList={};
    runs=[];
    SNR=[];
    SFNR=[];
    
    % Pull out the participant
    participant=participant_dir(participant_counter).name;
    
    % Check if this participant exists in the list
    if ~any(strcmp(participant,Participant_Names))
        warning('Could not find %s in the ParticipantList. Update this list', participant)
        continue
    else
        idx=find(strcmp(participant,Participant_Names));
    end
    
    % What experiments did this participant do?
    Experiments_participant=dir(sprintf('subjects/%s/analysis/secondlevel_*', participant));
    
    %Can the experiment be found
    if ~isempty(Experiments)
        experiment_found=0;
    else
        experiment_found=1; % Since there would be no option otherwise
    end
    
    % Iterate through the experiments for this participant
    
    for ExperimentCounter=1:length(Experiments_participant)
        
        temp_experiment=Experiments_participant(ExperimentCounter).name(13:end);
        
        %What experiments did this participant do?
        ExperimentList{end+1}=temp_experiment;
        
        % Is an experiment specified? If so, did this participant do it?
        if ~isempty(Experiments) && any(strcmp(Experiments, temp_experiment))
            experiment_found=1;
            
            %What runs was this experiment in?
            files=dir(sprintf('subjects/%s/analysis/firstlevel/functional*%s*.txt', participant, temp_experiment));
            for filecounter=1:length(files)
                runs(end+1)=str2double(files(filecounter).name(11:12));
            end
        end
        
    end
    
    % Store additional participant information
    ParticipantList{idx, 4}=ExperimentList;
    
    % If no runs were specified then assume you are using all of them
    if isempty(runs)
        runs=1:length(dir(sprintf('subjects/%s/data/nifti/*functional*.nii.gz', participant)));
    else
        runs=unique(runs); %Remove duplicates
    end
    
    % Collect QA for all runs
    if run_QA==1
        % Pull out the runs used
        functional_runs = dir(sprintf('subjects/%s/data/nifti/*functional*.nii.gz', participant));
        for runcounter=1:length(functional_runs)
            
            %What is the run name
            functional_run = functional_runs(runcounter).name;
            temp_idx = strfind(functional_run, 'functional');
            run_name = functional_run(temp_idx + 10:temp_idx + 11);
            QA_Filename=sprintf('subjects/%s/data/qa/qa_events_%s_functional%s.bxh.xml', participant, participant, run_name);
            
            % If this file doesn't exist then look for different file names
            if exist(QA_Filename) == 0
                
                % Only take the first part
                QA_Filename=sprintf('subjects/%s/data/qa/qa_events_%s_functional%s_part1.bxh.xml', participant, participant, run_name);
            end
            
            % Store the QA file if possible
            [SNR(runcounter), SFNR(runcounter)] = QA_extract(QA_Filename);
        end

        % Store additional participant information
        ParticipantList{idx, 5}=SNR(~isnan(SNR));
        ParticipantList{idx, 6}=SFNR(~isnan(SFNR));
    else
        %Preset value so that it won't violate criteria
        SNR(runs)=inf;
        SFNR(runs)=inf;
    end
    
    % Edit NaN values to be equal to 0 so they are excluded if there is any
    % exclusion criteria
    SNR(isnan(SNR)) = 0;
    SFNR(isnan(SFNR)) = 0;
    
    % Determine if this participant is in the list of excluded participants
    is_excluded_participant = 0; % Set default
    if exist('excluded_sessions', 'var') == 1
        % Check this data is a cell
        if iscell(excluded_sessions) == 1
            for excluded_session_counter = 1:length(excluded_sessions)
                
                if strfind(participant, excluded_sessions{excluded_session_counter}) > 0
                    is_excluded_participant = 1;
                end
            end
        else
            warning('excluded_sessions was not supplied with a cell input (e.g. ''excluded_sessions'', {''ppt_1'', ''ppt_2''}), aborting');
            return
            
        end
         
    end
    
    % Determine if this participant is in the list of included participants
    % (will not run if the ppt has already been marked for exclusion)
    if exist('included_sessions', 'var') == 1 && is_excluded_participant == 0 
        is_excluded_participant = 1; % Set default
        % Check this data is a cell
        if iscell(included_sessions) == 1
            for excluded_session_counter = 1:length(included_sessions)
                
                if strfind(participant, included_sessions{excluded_session_counter}) > 0
                    is_excluded_participant = 0;
                end
            end
        else
            warning('included_sessions was not supplied with a cell input (e.g. ''included_sessions'', {''ppt_1'', ''ppt_2''}), aborting');
            return
            
        end
         
    end
    
    %If this experiment doesn't meet the criteria then skip
    if experiment_found==1 && all(SNR(runs)>=Min_SNR) && all(SNR(runs)<=Max_SNR) && all(SFNR(runs)>=Min_SFNR) && all(SFNR(runs)<=Max_SFNR) && Age_List(idx)>=Min_Age && Age_List(idx)<=Max_Age && is_excluded_participant == 0
        Choosen_Participants{end+1}=participant;
        fprintf('%s\n', participant);
    else
        continue
    end
    
end
end

%Extract the SNR and SFNR information from each run of the participant
function [SNR, SFNR] = QA_extract(FileName)

%Open the ID
FileID=fopen(FileName);
SNR=NaN;
SFNR=NaN;
try
    Line=fgetl(FileID);
    while ischar(Line)
        
        
        %Check whether the line includes the SNR or SFNR
        if strfind(Line, 'mean_snr_middle_slice')
            
            %Where do numbers sit
            OpeningIdxs=strfind(Line, '>');
            ClosingIdxs=strfind(Line, '<');
            
            %Pull ouy the numbers
            SNR=str2num(Line(OpeningIdxs(1)+1 : ClosingIdxs(2)-1));
            
        elseif strfind(Line, 'mean_sfnr_middle_slice')
            
            %Where do numbers sit
            OpeningIdxs=strfind(Line, '>');
            ClosingIdxs=strfind(Line, '<');
            
            %Pull ouy the numbers
            SFNR=str2num(Line(OpeningIdxs(1)+1 : ClosingIdxs(2)-1));
            
            %Close the file
            fclose(FileID);
            
            %Stop searching now
            return
        end
        
        Line=fgetl(FileID);
    end
    
catch
    fprintf('Could not find the sfnr and snr in the text, setting to NAN\n');
end

end

