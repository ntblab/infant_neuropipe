% Add in time after motion to account for recovery of T1 magnetization
%
% When there is motion through a plane, this will mean some slices will
% receive more RF and others less, and this will change those voxel's
% signal for the period following the motion.
% 
% To implement this, take the confound files, find the columns with only a
% single 1, check that a confound doesn't follow it and then if not and add
% a new column where this time point is excluded.
%
% C Ellis 2/23/19

function motion_recovery(input_confound_mat, output_confound_mat, recovery_TRs)

% Convert string to num
if isstr(recovery_TRs)
    recovery_TRs = str2num(recovery_TRs);
end

% Load in the input
input_mat = dlmread(input_confound_mat);

% What indexs are TRs
confound_idxs = find(sum(input_mat(:,find(sum(input_mat) == 1)),2));

% Cycle through the excluded TRs and add these new time points if they are
% necessary
recovery_idxs = [];
for confound_idx = confound_idxs'
    for recovery_TR = 1:recovery_TRs
        
        % If this TR is not found in the list of confound_idxs, at it to
        % recovery idxs
        if isempty(find(confound_idxs == confound_idx + recovery_TR))
            recovery_idxs(end+1) = confound_idx + recovery_TR;
        end
    end
end

% Make sure you ignore the ones at the end
recovery_idxs = recovery_idxs(recovery_idxs<=size(input_mat,1));

% Add a column to the end of the output data for each recovery TR
output_mat = input_mat;
for recovery_idx = recovery_idxs
    
    % Insert the confound TR
    confound_vector = zeros(size(input_mat,1), 1);
    confound_vector(recovery_idx) = 1;
    
    % Append the vector
    output_mat(:, end+1) = confound_vector;
    
end

% Give a summary
fprintf('An additional %d TRs were excluded, bringing the total to %d (%0.2f percent)\n\n', length(recovery_idxs), length(confound_idx) + length(recovery_idxs), (length(confound_idx) + length(recovery_idxs)) * 100 /  size(input_mat,1));

dlmwrite(output_confound_mat, output_mat, 'delimiter',' ');