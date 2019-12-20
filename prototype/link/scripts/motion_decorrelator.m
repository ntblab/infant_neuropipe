function motion_decorrelator(run,outFile)
%This function removes highly correlated (>.95) motion
%parameter values any columns with all zeros. Columns with no variance
%(e.g. intercept terms) will be included.
%
% Edited by to deal with nans C Ellis 2/23/17

corr_threshold = 0.95; % What is the correlation required for exclusion

reg_mat = dlmread(run);
reg_mat = reg_mat(:,1:size(reg_mat,2));

% Exclude any zero sum columns
if sum(sum(abs(reg_mat)) == 0)>0
    [~, idxs] = find(sum(abs(reg_mat)) == 0);
    
    % Remove row
    reg_mat(:,idxs) = [];
    fprintf('Removing %d columns because they are sum zero\n', length(idxs))
end
    
% Find the column of correlation matrix that contains the highest correlation
corr_mat = abs(corr(reg_mat)) - eye(size(reg_mat,2));
while max(corr_mat(:)) > corr_threshold
   [~, idx] = max(max(corr_mat)); 
   reg_mat(:,idx) = [];
   corr_mat = abs(corr(reg_mat)) - eye(size(reg_mat,2));
   fprintf('Removing a motion correction variable from %s because of correlation\n', run);
end

dlmwrite(outFile,reg_mat, 'delimiter',' ');
