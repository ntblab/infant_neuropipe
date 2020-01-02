% Create the sliced data to be used for preprocessing exploration
%
% Create a new nifti file for this run in which all of the
% redundant rest (e.g. long burn outs) and long blocks are removed. This means all
% blocks are the same duration.
%
% Make sure the .mat is not in the input_design_mat name
%
% C Ellis 12/09/18

function slice_data(input_data, output_data, input_ev_file, output_ev_file, input_confound_mat, output_confound_mat, decorrelate, use_all_columns)

% Do you want to remove any regressors that are highly correlated?
if nargin < 7
	decorrelate=1;
end

if nargin < 8
        use_all_columns=0;
end

% If this is a string then turn it into a number
if isstr(decorrelate) == 1
    decorrelate = str2num(decorrelate);
end

if isstr(use_all_columns) == 1
    use_all_columns = str2num(use_all_columns);
end

% Set up parameters
BurnoutTRs=3; %How many TRs are you taking after the block ends?

addpath scripts/

if strcmp(input_data, output_data) || strcmp(input_confound_mat, output_confound_mat)
    fprintf('The input and output data are the same, which is not allowed for this code (since you are editting the output in steps\n');
    return
end


%% Load all the data

% % Load the confound parameters
% fid=fopen([input_confound_mat, '.mat']);
% line = fgetl(fid);
% design_mat_str = {};
% design_mat = [];
% starting_idx = 0;
% while all(line ~= -1)
%     
%     % Add this line to the matrix being created
%     if starting_idx > 0
%         design_mat(end+1, :) = cellfun(@str2num, strsplit(line(1:end-1)));
%     end
%     
%     % What is the first index
%     if strcmp(line, '/Matrix')
%         starting_idx = length(design_mat_str) + 1;
%     end
%     
%     % Store the design matrix
%     design_mat_str{end+1} = line; 
%     
%     % If the there is a space then skip it
%     if strfind(line, '/PPheights')
%         design_mat_str{end+1} = '';
%         
%         line = fgetl(fid); 
%     end
%     
%     line = fgetl(fid);
% end
% fclose(fid);
    
% Load in the confound matrix
confound_mat = dlmread(input_confound_mat);

% Pull out the timing file
timing=dlmread(input_ev_file);

%% Pull out information from the data

% Pull out the TR
[~, TR] =unix(sprintf('fslval %s pixdim4', input_data));

% Convert to number
if isstr(TR)
    TR=str2num(TR);
end

% Sometimes stored in ms
if TR >=1000
    TR=TR/1000;
end

% Sort the timing file
[~, idxs]=sort(timing(:,1));
timing = timing(idxs, :);

% Cycle through the blocks, making the nifti and the timing file
totaltime=0; % preset
tempfile=[output_data(1:end-7), '_temp.nii.gz']; % Make it out of the output name
included_TRs=[];
if ~strcmp(output_data, 'None')
	timing_fid = fopen(output_ev_file, 'w');
end
block_time_counter = 0;
for block_counter = 1 : size(timing,1)
    
    % What is the block start time and duration
    block_onset = floor(timing(block_counter,1)/TR);
    block_duration = ceil((timing(block_counter,2)/TR) + BurnoutTRs);
    block_weight = timing(block_counter, 3);
    
    % Is this block to be included
    if block_weight > 0

        % What is the elapsed time
        totaltime = totaltime + block_duration*TR;
	if ~strcmp(output_data, 'None')

		% Pull out the blocks
		Command=sprintf('fslroi %s %s %d %d', input_data, tempfile, block_onset, block_duration);
		fprintf('%s\n', Command);
		unix(Command);
		
		% Either copy or append this temporarily created file
		if exist(output_data) == 0
		    Command=sprintf('cp %s %s', tempfile, output_data);
		    fprintf('%s\n', Command);
		    unix(Command);
		else
		    Command=sprintf('fslmerge -t %s %s %s', output_data, output_data, tempfile);
		    fprintf('%s\n', Command);
		    unix(Command);
		end
	end
        
        % Print the new timing file
	if ~strcmp(output_data, 'None')
        	fprintf(timing_fid, '%0.1f\t%0.1f\t%0.1f\n', block_time_counter * TR, (block_duration - BurnoutTRs)* TR, block_weight);
	end
        block_time_counter = block_time_counter + block_duration;
        
        % Find all the TR idxs (of the design_mat file, that will be
        % included)
        for TRIdx = block_onset+1:block_onset+block_duration
            included_TRs(end + 1) = TRIdx;
        end
    end
end

% Finish up
if ~strcmp(output_data, 'None')
	fclose(timing_fid);
end

% Remove temp file
unix(sprintf('rm -f %s', tempfile));

%% Make the confound file

% Start making the new design matrix file by replicating the header
% information. Change the first two lines because it wil depend on the
% block inclusion
%design_mat_id = fopen([output_design_mat, '.mat'], 'w');
%design_mat_id = fopen([output_design_mat, '_mat.txt'], 'w');
confound_mat_id = fopen(output_confound_mat, 'w');

% Trim the included TRs to account for any that may exceed the duration of
% the functional (if there wasn't a full burn out
included_TRs = included_TRs(included_TRs <= size(confound_mat, 1));

% % Figure out which time points won't be included and thus the confounds are
% % irrelevant
% confound_idxs = sum(confound_mat > repmat((max(confound_mat) / 2), size(confound_mat, 1), 1), 1) == 1; % Find the idxs that are confounds
% usable_confound_idxs = sum(confound_mat(included_TRs, :) > repmat((max(confound_mat) / 2), length(included_TRs), 1), 1) == 1; % Take only the included TR confounds
% usable_coefs = [find(confound_idxs == 0), find(usable_confound_idxs == 1)];
% 
% % % Make the first two lines of the files
% % fprintf(design_mat_id, '/NumWaves\t%d\n', length(usable_coefs));
% % fprintf(design_mat_id, '/NumPoints\t%d\n', length(included_TRs));
% % 
% % % Store the peas for the coefs that will be used
% % pp_peaks = strsplit(design_mat_str{3});
% % fprintf(design_mat_id, '%s\t%s\n', pp_peaks{1}, sprintf('%s\t', pp_peaks{usable_coefs + 1}));
% % 
% % for idx = 4:starting_idx
% %     fprintf(design_mat_id, sprintf('%s\n', design_mat_str{idx}));
% % end
% 

% If any blocks were excluded then the motion_block_exclude function made
% an extra regressor that represents the excluded blocks. In such a case,
% you can remove it here by taking off the last index. Disable this with
% the argument
if sum(timing(:, 3) == 0) > 0 && use_all_columns==0 && length(unique(confound_mat(:, end))) > 2
    included_regressors = 1:size(confound_mat, 2) - 1;
else
    included_regressors = 1:size(confound_mat, 2);
end

% Add all of the time points
for TRIdx = included_TRs
    %fprintf(confound_mat_id, sprintf('%s\n', sprintf('%d ', confound_mat(TRIdx, usable_coefs)')));
    fprintf(confound_mat_id, sprintf('%s\n', sprintf('%d ', confound_mat(TRIdx, included_regressors)')));
end

% Finish up
fclose(confound_mat_id);

% Decorrelate data and deal with missing columns
if decorrelate==1
	fprintf('Running decorrelation\n');
	motion_decorrelator(output_confound_mat, output_confound_mat);
end

% % Create the design.con file
% design_con_id = fopen([output_confound_mat, '_con.txt'], 'w');
% 
% % fprintf(design_con_id, '/ContrastName1\n');
% % fprintf(design_con_id, '/NumWaves\t%d\n', length(usable_coefs));
% % fprintf(design_con_id, '/NumContrasts\t1\n');
% % fprintf(design_con_id, '/PPheights\t1\n'); % This doesn't matter when not using t stat
% % fprintf(design_con_id, '/RequiredEffect\t1\n\n'); % The effect size doesn't matter when you use t stat
% % fprintf(design_con_id, '/Matrix\n');
% fprintf(design_con_id, '%d ', [1, repmat(0, 1, length(usable_coefs) - 1)]);
% fclose(design_con_id);

fprintf('\nFinished\n');
