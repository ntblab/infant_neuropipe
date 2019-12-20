% Upload any missing eye tracking coding data.
% Looks in all the participant directories on jukebox and checks whether there are coding
% files on dropbox that haven't yet been uploaded.
%
% Must be run locally with the cluster and dropbox mounted 
%
% C Ellis 7/9/17
function Upload_EyeTracker_Coding_Data

jukeboxpath='/Volumes/dev02/subjects/';
dropboxpath='~/Dropbox/Dev_Gaze_Categorization/Coder_Files/';

addpath('/Volumes/dev02/scripts');
Ignored_Coders={'CE', 'LS', 'NC', 'JO', 'Pilot'};

%Get the mapping of fmri names and matlab names
[~, ParticipantList] = Participant_Index({'Check_QA', 0});

% What are the file names
fmri_names=ParticipantList(:,1);
matlab_names=ParticipantList(:,2);

%Iterate through the participant directories
for participantcounter=1:length(fmri_names)
    
    % What are the file names
    fmri_name=fmri_names{participantcounter};
    matlab_name=matlab_names{participantcounter};
    
    % Try and pull the coder files out
    try
        all_coder_struct=dir([dropboxpath, matlab_name, '_Coder*']);
        
        % If this is a '_1' (first session) then the files might not be
        % stored with the appropriate name
        if strcmp(matlab_name(end-1:end), '_1')
            additional_dir=dir([dropboxpath, matlab_name(1:end-2), '_Coder*']);
            
            for counter=1:length(additional_dir)
                all_coder_struct(end+1)=additional_dir(counter);
            end
        end
            
    catch
        fprintf('No coding files for %s. Skipping\n\n', matlab_name)
        continue
    end
    
    % Reform the struct into a cell
    all_coder_files={};
    for file_counter = 1:length(all_coder_struct)
        all_coder_files{end+1} = all_coder_struct(file_counter).name;
    end
    
    % Remove any irrelevant coders:

    % Cycle through the names that have been pulled out
    file_counter=1;
    while file_counter <= length(all_coder_files)
        
        % Does this file contain a to be excluded coder
        for ignored_coder_counter =1:length(Ignored_Coders)
            
            file = all_coder_files{file_counter};
            
            % Is there a match
            if ~isempty(strfind(file(strfind(file, 'Coder_'):end), Ignored_Coders{ignored_coder_counter}))
                fprintf('Not considering %s\n', file);
                
                % Remove the offending file name
                all_coder_files=[all_coder_files(1:file_counter-1), all_coder_files(file_counter+1:end)];
                break
            end
        end
        file_counter=file_counter+1;
    end
    
    % Is this a directory
    if isdir([jukeboxpath, fmri_name])
        
        % Compare the files and add if necessary. If it has Pilot in the
        % name then ignore it
        for counter=1:length(all_coder_files)
            filename=all_coder_files{counter};
            
            % Does the file have pilot in the name and does the file exist? If not then add it
            if exist([jukeboxpath, fmri_name, '/data/Behavioral/', filename])==0
                fprintf('Adding %s to %s\n\n', filename, fmri_name);
                copyfile([dropboxpath, filename], [jukeboxpath, fmri_name, '/data/Behavioral/', filename]);
            end
                
        end
        
    else
        fprintf('%s was not detected as a directory.\n\n', fmri_name)
        
    end
end