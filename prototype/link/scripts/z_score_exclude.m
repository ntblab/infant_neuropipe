%% Z score a functional while ignoring specified timepoints.
%
% Takes in a functional, loads it in, takes the mean and standard deviation
% of each voxel, excluding certain timepoints and then z scores across
% those time points. The excluded timepoints are then interpolated, using the
% default method.
%
% C Ellis 08/17/17
%
function z_score_exclude(Input_file, Output_file, Excluded_TRs)

% Convert if appropriate
if isstr(Excluded_TRs)
   Excluded_TRs= str2num(Excluded_TRs);
end

% Get the project directory
addpath scripts
globals_struct=read_globals; % Load the content of the globals folder

addpath(genpath([globals_struct.PACKAGES_DIR, '/NIfTI_tools/']))

%% Load functional
nifti=load_untouch_nii(Input_file);

fprintf('Loading %s\n', Input_file)
brain = double(nifti.img);

Included_TRs=setdiff(1:size(brain,4), Excluded_TRs);

% Zero out all the excluded TRs
brain(:, :, :, Excluded_TRs)=0;

% Find the mean and standard deviation of the included TRs
brain_mean=mean(brain(:, :, :, Included_TRs), 4);
brain_std=std(brain(:, :, :, Included_TRs), [], 4);

% Perform z scoring
for TR_Counter =1:length(Included_TRs)
    brain(:, :, :, Included_TRs(TR_Counter))=(brain(:, :, :, Included_TRs(TR_Counter))-brain_mean) ./ brain_std;
end

% Make all nans into zeros
brain(isnan(brain))=0;

%% Save the nifti

nifti.img=brain; % Insert the data in the nifti it came from
save_untouch_nii(nifti, Output_file)

fprintf('Saving %s\n',Output_file)

%% Do interpolation
interpolate_TRs(Output_file, Output_file, Excluded_TRs);

