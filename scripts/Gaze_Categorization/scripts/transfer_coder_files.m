%% Transfer coder files
% Transfer all of the coder files that are stored in the 'Coder_Files' folder into
% the appropriate folder for each participant
%
% If overwrite is set to 1 then it will overwrite even when there is
% already a match. If it is set to 2 (the default) it will overwrite when
% it is newer, when it is 0 it won't overwrite

function transfer_coder_files(participant_criteria, overwrite)

if nargin == 0
    participant_criteria={};
    overwrite=2;
end

% Change directory to the project directory
%cd ../../../

% Add path to main scripts directory
addpath scripts
[~, Participant_Info] = Participant_Index(participant_criteria);

% Pull out the coder names
Coder_Files = dir('scripts/Gaze_Categorization/Coder_Files/*_Coder_*');

% Cycle through the coders
for Coder_Counter = 1:length(Coder_Files)

    File = Coder_Files(Coder_Counter).name;
    
    matlab_name = File(1:strfind(File, '_Coder_') - 1);
    
    idx = find(cellfun(@isempty, strfind(Participant_Info(:,2), matlab_name)) == 0);
    neuropipe_name = Participant_Info{idx, 1};
    
    input_name = sprintf('%s/%s', Coder_Files(Coder_Counter).folder, File); 
    output_name = sprintf('subjects/%s/data/Behavioral/%s', neuropipe_name, File); 
    
    % Copy over the file
    command = sprintf('cp %s %s', input_name, output_name);
    if exist(output_name) == 0
    
        fprintf('\n%s\n', command);
        unix(command);
    else
        
        % Compare the modification date of the two files
        old_file = dir(output_name);
        is_newer = Coder_Files(Coder_Counter).datenum > old_file.datenum;
        
        if overwrite == 1
            fprintf('\n%s exists but overwritting anyway\n%s\n', output, command);
            unix(command);
        elseif overwrite == 2 && is_newer
            fprintf('\nFile is newer, overwritting\n%s\n', command);
            unix(command);
        else
            fprintf('\n%s exists, not overwritting.\n', output_name);
        end
        
    end
    
end
