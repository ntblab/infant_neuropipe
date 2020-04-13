function globals_struct = read_globals(globals_path)
% Take the globals function (assumed to be in the current directory) and
% extract the paths
% Be aware that the variables are all written as bash readible, which means
% that if there are some variables used then these won't render
% appropriately.
%
% First created by C Ellis 3/23/18

% Does the globals file live on this path? If not, search for it
if nargin==0
    if exist('globals.sh') == 2
        globals_path='./';
    else
        % Assume you are in the participant directory, then search for the
        % folder two above the subjects folder
        current_dir=pwd;
        
	if strfind(current_dir, 'analysis') > 0
		globals_path=current_dir(1:strfind(current_dir, 'analysis')-1);
	else
		% Find the relevant features in the path
		folder_idxs=strfind(current_dir, '/');
		subject_idx=strfind(current_dir, 'subjects/');
		
		% Find the first slash after the 'subjects/'
		globals_path=current_dir(1:folder_idxs(find(folder_idxs > subject_idx + 9)));
	end
    end
end

fid = fopen([globals_path, 'globals.sh']);


% Read in the first line
line = fgetl(fid);

% Go through the text line by line 
while length(line) > 1 || all(line ~= -1)
    
    % Evaluate this line if it contains an '=' otherwise ignore
    if ~isempty(strfind(line, '='))
        
        % Preprocess the line if necessary
        if ~isempty(strfind(line, 'export '))
            line = line(strfind(line, 'export ') + length('export '):end);
        end
        
        % Add quotes around the content after the equals to make everything into strings
        if ~strcmp(line(strfind(line, '=')+1), '''')
            line = [line(1:strfind(line, '=')), '''', line(strfind(line, '=')+1:end), ''''];
        end
        
        % Evaluate the functions that can be evaluated
        evalc(line);
        
    end
    
    % Read the next line
    line = fgetl(fid);
end

% Close file
fclose(fid);

% Clean up
clearvars line fid ans

% Turn the variables into a structure 
workspace = whos;
for counter = 1:length(workspace) 
    globals_struct.(workspace(counter).name) = eval(workspace(counter).name); 
end
