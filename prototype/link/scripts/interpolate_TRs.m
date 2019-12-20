%% Recreate the input volume with the TRs interpolated as specified
% Takes in an input volume, identifies the timepoints to be excluded and
% then interpolates those time points, saving it with the same name and
% saving a backup
%
% C Ellis 08/17/17
%
function interpolate_TRs(Input_file, Output_file, Confounds, interpolation_type)

% Default
if nargin<4
    interpolation_type='mean_included';
end

% Get the project directory
addpath scripts
globals_struct=read_globals; % Load the content of the globals folder

addpath(genpath([globals_struct.PACKAGES_DIR, '/NIfTI_tools/']))

%% Load functional
nifti=load_untouch_nii(Input_file);

brain = double(nifti.img);

fprintf('Loading %s, using %s and %s interpolation to output %s\n', Input_file, Confounds, interpolation_type, Output_file)

%% Exclude some TRs
if isstr(Confounds)==0
    % Assume if you have been given a non string then the supplied
    % timepoints are the excluded TRs
    Excluded_TRs=Confounds;
    
elseif exist(Confounds)==2
    % If you have been a string assume it is a file path and then read it
    % in
    Confounds=dlmread(Confounds);
    
    % Remove all columns that don't sum to one
    Confounds=Confounds(:, sum(Confounds,1)==1);
    
    if size(Confounds,1)==size(brain,4)
        Excluded_TRs=find(sum(Confounds,2)==1);
    else
        fprintf('%s doesn''t match length, not interpolating any TRs\n', Confounds);
        return
    end
    
end

% Perform the interpolation
fprintf('Interpolate %d TRs\n', length(Excluded_TRs));

% Perform the interpolation, differing on method depending on type
if strcmp(interpolation_type, 'mean')
    
    % Take the mean of adjacent TRs, regardless of whether they are also
    % confound TRs
    for Confound_Counter=1:length(Excluded_TRs)
        Border_TRs=[Excluded_TRs(Confound_Counter)-1, Excluded_TRs(Confound_Counter)+1];
        
        Border_TRs=Border_TRs(Border_TRs>0);
        Border_TRs=Border_TRs(Border_TRs<size(brain,4));
        
        %Average the two border TRs
        brain(:,:,:,Excluded_TRs(Confound_Counter))=mean(brain(:,:,:,Border_TRs),4);
    end
    
elseif strcmp(interpolation_type, 'mean_included')
    
    for Confound_Counter=1:length(Excluded_TRs)
        
        % Iterate until you find TRs adjacent to an excluded TR that aren't
        % to be excluded. If all TRs are excluded then quit
        back_reference=1;
        forward_reference=1;
        while 1
            
            Border_TRs=[Excluded_TRs(Confound_Counter)-back_reference, Excluded_TRs(Confound_Counter)+forward_reference];
            
            Border_TRs=Border_TRs(Border_TRs>0);
            Border_TRs=Border_TRs(Border_TRs<=size(brain,4));
            
            % Are either of the bounds excluded TRs
            if isempty(find(Excluded_TRs==Border_TRs(1))) && isempty(find(Excluded_TRs==Border_TRs(end)))
                break
            elseif Border_TRs(1)<Excluded_TRs(Confound_Counter) && ~isempty(find(Excluded_TRs==Border_TRs(1)))
                back_reference=back_reference+1;
            elseif ~isempty(find(Excluded_TRs==Border_TRs(end)))
                forward_reference=forward_reference+1;
            end
        end
        
        %print
        %Border_TRs
        
        %Average the two border TRs
        brain(:,:,:,Excluded_TRs(Confound_Counter))=mean(brain(:,:,:,Border_TRs),4);
    end
end


%% Save the nifti

nifti.img=brain; % Insert the data in the nifti it came from
save_untouch_nii(nifti, Output_file)

fprintf('Saving %s, used %s interpolation\n',Output_file, interpolation_type)



