%% Initial preprocessing of functional and anatomical data
% Does several initial steps of the preprocessing pipeline for analyzing
% infant participants. Must be done on a cluster because it submits jobs,
% like for freesurfer. By default this code should perform reasonable steps
% but there are various parameters that can be provided to do the steps
% differently. Takes as an input the steps to be run, the functionals to be
% run and the burn in TRs. For instance the command might be
% prep_raw_data([1:3,5,7], [1,3] 2). The reason for these inputs is so that
% the function can be easily used by other functions like Analysis_Timing.
% This function also accepts a variety of special terms that follow the
% following format: ..., '$Variable_name', $Variable, ...
%
% Steps are mostly independent although the order matters such that later
% steps may be affected by earlier steps.
%
% To change any of the parameter defaults, alter the file
% $SUBJ_DIR/scripts/prep_set_defaults.m
%
% The 9 steps of this function are: 
%
% 1. Creates backup copies of the original anatomical  files if they
% haven't yet been made, saving with the suffix '_original.nii.gz'.
% Identifies volumes to be merged by looking for a suffix
% '_registered.nii.gz'.
%
% 2. Merges all anatomicals with suffix '_registered.nii.gz', then outputs
% a file stripped of anatomical number named:
% '$anatomical_merged_masked.nii.gz'.
%
% 3. Homogenizes all masked volumes using 3d_Unifize in afni to make
% '_unifize.nii.gz' files. In our scans we do not collect data with the top
% of the head coil on so there is typically a small drop off in signal
% sensitivity in the anterior of the brain. Even with scans that use the
% top of the head coil, there can be inhomogenities which this script can
% deal with. If it was successful then the intensity in anterior regions
% should be similar to posterior regions. I have tested it and I think that
% homogenizing before brain extraction is better. It then performs brain
% extraction using 3d_SkullStrip (which is better than bet) to make
% '_brain.nii.gz'. Renames unifized volumes as the base file name (so that
% BBR would work if it was used).
%
% 4. To help with analysis later it creates a blank brain volume with the
% same dimensions as the petra01. This is a legacy step and is no longer
% necessary
%
% 5. Runs freesurfer on all of the anatomicals. To identify anatomicals,
% this looks for 'mprage', 'petra', or 'space' in the title and submits a
% sbatch job for each. If you have a different type of anatomical you want
% to use then add it to the 'anatomical_list' variable.
%
% 6. For each of the functionals, runs 3dDespike and stores the output in
% the 'analysis/firstlevel' folder. This is a legacy step since 3dDespiking
% is now run at a later step, after having done some preprocessing, in
% FEAT_prestats.sh
%
% 7. Generates motion parameters and uses these to calculate the median TR
% in terms of motion and then calculates the motion parameters again with
% this reference TR. TRs that exceed the motion threshold (default is 3mm)
% are marked exclusion. This function also can identify other types of
% motion exclusions but this is no longer used by default. For instance, it
% is possible to detect zipper artefacts, by setting the mahalanobis
% threshold in the '$SUBJ_DIR/scripts/prep_set_defaults.m' script to a
% non-zero value. This will detect and exclude TRs that have an artefact
% that is diagnostic of within frame motion. The output motion parameters
% (including motion parameters and excluded TRs) for each run are stored in
% 'analysis/firstlevel/Confounds/', along with a figure depicting the x,y,z
% position of the head throughout the run and metrics of the motion. It
% also creates a list of TRs to be excluded because of motion. This occurs
% recursively: if the TR identified as central should be excluded then it
% will be and a new TR must be chosen.
%
% 8. Concatenate the motion parameters and the confounds into a wide matrix for
% each run then decorrelate any highly correlated columns (by removing one).
%
% 9. Visualize motion confound TRs. For each run it will create a volume
% that shows the TRs to be excluded by putting a border around the volume.
% It also creates a subplot with a slice through the TR before and during
% the exclusion. Finally, it also makes a volume of the functional that 
% has a border for TRs where there is movement.
%
% First created by C Ellis 2/22/17

function prep_raw_data(StepsRun, FunctionalRuns, Burn_In_TRs, varargin)

%% SET-UP: set default values and paths, read in input arguments 
% If there are no inputs then specify all possible ones. If there are
% inputs then convert them to number
if nargin==0
    StepsRun=1:100;
end

if nargin<2    
    FunctionalRuns=1:100;
end

if nargin<3
    Burn_In_TRs=3;
end

%Reformat the inputs
if isstr(StepsRun)
    StepsRun=str2num(StepsRun);
end

if isstr(FunctionalRuns)
    FunctionalRuns=str2num(FunctionalRuns);
end

if isstr(Burn_In_TRs)
    Burn_In_TRs=str2num(Burn_In_TRs);
end


%Add paths
addpath scripts
globals_struct=read_globals; % Load the content of the globals folder

addpath(genpath([globals_struct.PACKAGES_DIR, '/NIfTI_tools/']))
addpath([globals_struct.PACKAGES_DIR, '/moutlier1/'])

% Pull out the participant name from the path
curr_dir=pwd;
idxs=strfind(curr_dir, '/');
subj=curr_dir(idxs(end)+1:end);

TR=str2num(globals_struct.TR); % How many seconds is each volume acquistion. This might change

% Get all the default values
prep_set_defaults

% Read in the inputs, starting from the 4th, and allow those values to be
% set. Allows us to update the default values above 
input_counter=3;
conditions='';
% Iterate through each additional variable name/variable one at a time
while nargin > input_counter
    % Input format should be '$Variable_name', $Variable, ... If one of
    % these is supplied but not both (ie 4 args total) then abort
    var_name=varargin{input_counter-2};
    if nargin < input_counter+2
        warning('Insufficient inputs, the variable value for %s was not supplied. Aborting', var_name);
        return;
    end
    var_value=varargin{input_counter-1};
    
    % Default to convert any strings to numbers
    if isstr(var_value);
        var_value=str2num(var_value);
    end
    
    % Depending on the var input name, set local variable accordingly
    if strcmp(var_name, 'mahal_threshold')
        var_value=varargin{input_counter-1}; % What is the threshold for striping to be detected? (can be IQR, a number below 1 (a criterion cut off) or a number above 1 (absolute threshold))
        mahal_threshold=var_value;
        if isstr(var_value)
            % Turn into a number if this is not IQR
            if ~strcmp(var_value, 'IQR')
                mahal_threshold=str2num(var_value);
            end
        end
    elseif strcmp(var_name, 'fslmotion_threshold')
        fslmotion_threshold=var_value; %What is the millimeter threshold for exclusion?
    elseif strcmp(var_name, 'pca_components')
        pca_components=var_value; %How many PCA components to consider for zippers
    elseif strcmp(var_name, 'TR')
        TR=var_value; % How many seconds is each volume acquistion. This might change
    elseif strcmp(var_name, 'useExtendedMotionParameters')
        useExtendedMotionParameters=var_value; %Do you want to use extended motion parameters?
    elseif strcmp(var_name, 'useCentroidTR')
        useCentroidTR=var_value; %Do you want to use the optimal TR for analysis?
    elseif strcmp(var_name, 'Loop_Centroid_TR')
        Loop_Centroid_TR=var_value;% Do you want to loop through the centroid TRs to find one that isn't excluded?
    elseif strcmp(var_name, 'useRMSThreshold')
        useRMSThreshold=var_value; %Do you want to use the RMS threshold as your default?
    elseif strcmp(var_name, 'useExtended_Motion_Confounds')
        useExtended_Motion_Confounds=var_value; %Do you want to look for stripping in the planes of a volume and exclude based on that?
    elseif strcmp(var_name, 'data_dir')
        data_dir=varargin{input_counter-1}; % Do you want to specify the data directory (can be useful if trying to run this on pseudorun data)
    else
        warning('The variable name %s was not found. Aborting', var_name);
        return;
    end
    
    % Store the conditions
    if ~strcmp(var_name, 'data_dir')
        conditions=[conditions, '_', var_name, '_', num2str(var_value)];
    end
    
    % Move input counter to next variable input
    input_counter= input_counter+2;
end 
  

%Set up the variables
if exist('data_dir') == 0 % If it doesn't exist
    data_dir=[globals_struct.NIFTI_DIR, '/'];
end
analysis_dir=[globals_struct.FIRSTLEVEL_DIR, '/'];
confound_dir=[analysis_dir, '/Confounds/'];


% If the threshold is 0 then set this to zero
if mahal_threshold==0
    useExtended_Motion_Confounds=0;
end    
  
% Create separate lists containing all masked anatomicals and functions in
% the nifti directory
anatomicals_masked=dir([data_dir, '*_masked.nii.gz']);
functionals=dir([data_dir, '*functional*.nii.gz']);

        
%Restrict the number of functionals to those specified
FunctionalRuns=FunctionalRuns(FunctionalRuns<=length(functionals)); %Reduce to max
functionals=functionals(FunctionalRuns);

%Create a list of all possible anatomical types
anatomical_list ={'petra','mprage','space'};

%Print summary of steps:
StepDescriptions={'1. Backup originals',...
    '2. Merge anatomicals',...
    '3. Homogenize anatomicals',...
    '4. Create blank volume',...
    '5. Run freesurfer',...
    '6. Despike the data',...
    '7. Generate motion parameters and confounds',...
    '8. Concatenate and decorrelate the nuissance regressors',...
    '9. Visualizing TRs selected for exclusion',...
    };

fprintf('\nPerforming the following steps:\n');
for StepCounter=1:length(unique(StepsRun))
    if StepsRun(StepCounter)<=length(StepDescriptions)
        StepDescription=StepDescriptions{StepsRun(StepCounter)};
        fprintf('\t%s\n', StepDescription);
    end
end

fprintf('\nThese steps are being run on functional runs:\n%s\n%s Burn In TRs will be excluded. Using %s for PCA threshold\n', sprintf('%s\n', functionals(:).name), num2str(Burn_In_TRs), num2str(mahal_threshold));

%%  STEP 1: Create back-up copies of original files and identify volumes to be merged
% For every step, check to make sure that it is listed as steps to run
% before executing

% Cycle through the anatomicals to check to see if any are name
% _registered (prepped for merging)
if ~isempty(find(StepsRun==1))
    fprintf('######################################\n\n\tSTEP 1: Create back-up copies and identify volumes to be merged\n\n######################################\n');
    MergeList='';
    for anatomicalCounter=1:length(anatomicals_masked)
        
        %Pull out the base name for this anatomical
        basename=anatomicals_masked(anatomicalCounter).name(1:(strfind(anatomicals_masked(anatomicalCounter).name, '_masked.nii.gz'))-1);
        
        %Does registered file exist? If so, add to merge list
        registeredname=[data_dir, basename, '_registered.nii.gz'];
        if exist(registeredname)>0
            MergeList=sprintf('%s %s', MergeList, registeredname);
        end
        
        %If the base name hasn't been renamed as _original then do that here
        if exist([data_dir, basename, '_original.nii.gz'])==0
            Command=sprintf('mv %s %s', [data_dir, basename, '.nii.gz'], [data_dir, basename, '_original.nii.gz']) %Print
            unix(Command); %Don't have a space because of how MergeList is created
            
        end
    end
end

%% STEP 2: Merge all anatomicals
% Merge anatomicals identified in step 1 to base anatomical
if ~isempty(find(StepsRun==2))
    fprintf('######################################\n\n\tSTEP 2: Merge all anatomicals\n\n######################################\n');
    if ~isempty(MergeList)
        
        anatomical_type='';
        % Pull out all of the petra anatomicals for merging
        for a = 1:length(anatomical_list)
            if ~isempty(strfind(MergeList, anatomical_list{a}))
                anatomical_type=anatomical_list{a};
            end
        end
        
        if ~isempty(anatomical_type)
            
            MergeName=[data_dir, subj, '_',anatomical_type, '_merged_masked.nii.gz'];
            
            %Run the merge command and then average
            %fslmerge concatenates volumes in time
            Command=sprintf('fslmerge -t %s%s', MergeName, MergeList) %Print
            unix(Command); %Don't have a space because of how MergeList is created
            Command=sprintf('fslmaths %s -Tmean %s', MergeName, MergeName) %Print
            unix(Command);
        else
            fprintf('Could not find anatomical name (e.g., "petra") in the list of possible anatomicals for merging. Update the anatomical list with desired anatomical name.\n')
        end
    end
end

%% STEP 3: Homogenize all masked volumes and skull strip 
%Collect all files that have an _masked suffix (may now include merged
%files) and unifize, then skullstrip them
if ~isempty(find(StepsRun==3))
    fprintf('######################################\n\n\tSTEP 3: Create back-up copies and identify volumes to be merged\n\n######################################\n');
    anatomicals_masked=dir([data_dir, '*_masked.nii.gz']); %Since this may have updated
    for anatomicalCounter=1:length(anatomicals_masked)
        
        %Pull out the base name for this anatomical
        basename=anatomicals_masked(anatomicalCounter).name(1:(strfind(anatomicals_masked(anatomicalCounter).name, '_masked.nii.gz'))-1);
        
        %Unifize the volumes
        Command=sprintf('3dUnifize -input %s -prefix %s', [data_dir, anatomicals_masked(anatomicalCounter).name], [data_dir, basename, '_unifize.nii.gz'])
        unix(Command);
        
        %Skull strip the volumes
        Command=sprintf('3dSkullStrip -input %s -prefix %s', [data_dir, basename, '_unifize.nii.gz'], [data_dir, basename, '_brain.nii.gz'])
        unix(Command);
        
        %Duplicate unifize to have the basename
        Command=sprintf('cp %s %s', [data_dir, basename, '_unifize.nii.gz'], [data_dir, basename, '.nii.gz'])
        unix(Command);
    end
end

%% STEP 4: Create a blank volume
if ~isempty(find(StepsRun==4))
    fprintf('######################################\n\n\tSTEP 4: Create a blank volume\n\n######################################\n');
    
    % Get the functional name    
    functional=[data_dir, functionals(1).name];
    
    % Pull out the functional properties
    Command=sprintf('fslval %s dim1', functional)
    [~, dim1]=unix(Command);
    
    Command=sprintf('fslval %s dim2', functional)
    [~, dim2]=unix(Command);
    
    Command=sprintf('fslval %s dim3', functional)
    [~, dim3]=unix(Command);
    
    Command=sprintf('fslval %s pixdim1', functional)
    [~, pixdim1]=unix(Command);
    
    Command=sprintf('fslval %s pixdim2', functional)
    [~, pixdim2]=unix(Command);
    
    Command=sprintf('fslval %s pixdim3', functional)
    [~, pixdim3]=unix(Command);
    
    % create an empty anatomical image with the appropriate dimensions and
    % voxel size. Downsample and only necessary for registration
    Command=sprintf('fslcreatehd %s %s %s 1 %s %s %s %0.2f 0 0 0 16 %s', dim1(1:end-1), dim2(1:end-1), dim3(1:end-1), pixdim1(1:end-1), pixdim2(1:end-1), pixdim3(1:end-1), TR, [data_dir, 'Blank.nii.gz'])
    unix(Command);
end

%% STEP 5: Run freesurfer
if ~isempty(find(StepsRun==5))
    fprintf('######################################\n\n\tSTEP 5: Run freesurfer\n\n######################################\n');
    
    % identify all files with petra or mprage
    anatomicals=[];
    for anatomical_counter = 1:length(anatomical_list)

	% Get the anatomical type
	anatomical_type = anatomical_list{anatomical_counter};

	% Get any anatomicals with this name
        new_anatomicals=dir(sprintf('%s/%s*%s*.nii.gz', data_dir, subj, anatomical_type));
	
	% Append the anatomicals to the list
	if length(anatomicals) == 0
	    anatomicals=new_anatomicals;
	else
	    anatomicals(end+1:end+length(new_anatomicals))=new_anatomicals;
	end
    end

    % iterate through each one in this list and run freesurfer
    for anatomicalCounter=1:length(anatomicals)
        
        %Pull out the base name
        starting_idx = strfind(anatomicals(anatomicalCounter).name, 'petra');
        if isempty(starting_idx)
            starting_idx = strfind(anatomicals(anatomicalCounter).name, 'mprage');
        end
        basename=anatomicals(anatomicalCounter).name(starting_idx:strfind(anatomicals(anatomicalCounter).name, '.nii.gz')-1);
        
        % Run freesurfer. 
        % recon-all performs the FreeSurfer cortical reonstruction process
        % inputs: subject data, subject dir, all (do everything, including
        % subcortical segmentation), -cw256 (?)
        Command=sprintf('sbatch ./scripts/run_recon-all.sh %s %s analysis/freesurfer', [data_dir, anatomicals(anatomicalCounter).name], basename)
        unix(Command);
    end
end

%% STEP 6: Run 3dDespike on all the functional data
if ~isempty(find(StepsRun==6, 1))
    fprintf('######################################\n\n\tSTEP 6: Run 3dDespike on all the functional data\n\n######################################\n');
    for functionalCounter=1:length(functionals)
        
        functional=[data_dir, functionals(functionalCounter).name];
        despike_name=[analysis_dir, functionals(functionalCounter).name(1:end-7), '_despiked.nii.gz'];
        
        %Run the motion outliers
        % 3dDespike removes 'spikes' from the 3D+time input dataset and
        % writes a new dataset with the spike values replaced
        Command=sprintf('3dDespike -prefix %s %s', despike_name, functional)
        unix(Command);
        
    end
end

%% STEP 7: Generate motion parameters, calculate median TR
% determine TRs to exclude. 

% Create the motion parameters and motion outliers and store them in the
% Confounds folder. Store motion parameters and confound TRs separately,
% combine them in Step 8 if necessary
if ~isempty(find(StepsRun==7))
    fprintf('######################################\n\n\tSTEP 7: Generate motion parameters, calculate median TR\n\n######################################\n');
    for functionalCounter=1:length(functionals)
        
        
        %% Calculate the motion parameters for the centroid TR
        
        %What is the functional
        Functional=[data_dir, functionals(functionalCounter).name];
        
        % Get the name of the run that is being used
        functional_run=Functional(strfind(Functional, 'functional')+10:strfind(Functional, '.nii.gz') - 1); %What number functional is it

        % Perform the centroid TR analysis
        prep_select_centroid_TR(Functional, functional_run, confound_dir, Burn_In_TRs, useRMSThreshold, fslmotion_threshold, mahal_threshold, useCentroidTR, Loop_Centroid_TR, pca_components, conditions);
         
    end
end

%% STEP 8: Concatenate the nuisance regression files, if they exist and use a consistent naming system, regardless of the thresholds used.
if ~isempty(find(StepsRun==8))
    fprintf('######################################\n\n\tSTEP 8: Concatenate the nuisance regression files, if they exist and use a consistent naming system, regardless of the thresholds used.\n\n######################################\n');
    for functionalCounter=1:length(functionals)
        
        %Get the names necessary
        functional=[data_dir, functionals(functionalCounter).name];
        functional_run=functional(strfind(functional, 'functional')+10:strfind(functional, 'functional')+11);
        
        % Concatenate the files from this analysis
        prep_concatenate_confounds(functional_run, confound_dir, fslmotion_threshold, useRMSThreshold, mahal_threshold, useExtendedMotionParameters, useExtended_Motion_Confounds)
        
    end
end

%% STEP 9: Visualize confound TRs, if they exist
if ~isempty(find(StepsRun==9))
    
    fprintf('######################################\n\n\tSTEP 9: Visualize confound TRs, if they exist\n\n######################################\n');
    for functionalCounter=1:length(functionals)
        
        %Get the names necessary
        functional=[data_dir, functionals(functionalCounter).name];
        functional_run=functional(strfind(functional, 'functional')+10:strfind(functional, 'functional')+11);

        confound_name=sprintf('%s/OverallConfounds_functional%s.txt', confound_dir, functional_run);
        
        % Only run if the confound file exists
        if exist(confound_name)==2
            
            % Pull out the volume, ignore burn in
            nii=load_untouch_nii(functional);
            volume=double(nii.img(:,:,:,Burn_In_TRs+1:end));
            
            % What is the mid point of the slice
            Mid_X=round(size(volume,1)/2);
            
            % Which TRs are excluded
            confounds=dlmread(confound_name);
            confounds(:,find(sum(confounds,1)==1));
            
            %Find the TRs to be excluded
            confounds=confounds(:,find(sum(confounds,1)==1));
            confound_TRs=unique(find(sum(confounds,2)>0));
            
            % Print output of analysis
            fprintf('From %s, removing TRs: %s\n\n', functionals(functionalCounter).name, sprintf('%d ', confound_TRs));
            
            % Create a new volume with the excluded TRs highlighted
            borderwidth=1;
            border_val=max(volume(:));
            border=ones(size(volume,1), size(volume,2), size(volume,3),length(confound_TRs)) * border_val;
            border(borderwidth+1:end-borderwidth,borderwidth+1:end-borderwidth,borderwidth+1:end-borderwidth,:)=0; % Hollow it out
            
            % Insert the border in 
            volume(:,:,:,confound_TRs)=volume(:,:,:,confound_TRs)+border;
            
            % Save the volume you just made
            nii.img=volume;
            nii.hdr.dime.dim(5)=size(volume,4);
            save_untouch_nii(nii, sprintf('%s/Excluded_TRs_functional%s.nii.gz', confound_dir, functional_run))
            
            %Make plot of the to be excluded TRs next to the preceeding TRs
            %(limit to 4 TRs per plot)
            
            subplotsperplot=3;
            confound_counter=1;
            for plots=1:ceil(length(confound_TRs)/subplotsperplot)
                
                %Go through the subplots
                subplotcounter=1;
                figure
                
                while subplotcounter<=(subplotsperplot * 3) && confound_counter<=length(confound_TRs)
                    
                    % Plot TR before and after the excluded one
                    precedingTR=confound_TRs(confound_counter)-1;
                    procedingTR=confound_TRs(confound_counter)+1;
                    
                    if precedingTR>0
                        subplot(subplotsperplot,3,subplotcounter);
                        imagesc(rot90(squeeze(volume(Mid_X,:,:,precedingTR))));
                        hold on
                        title(precedingTR)
                        hold off
                        colormap('gray');
                        axis('off')
                    end
                    
                    % Plot the excluded TR
                    subplot(subplotsperplot,3,subplotcounter + 1)
                    imagesc(rot90(squeeze(volume(Mid_X,:,:,confound_TRs(confound_counter)))));
                    hold on
                    title(confound_TRs(confound_counter))
                    hold off
                    colormap('gray');
                    axis('off')
                    
                    if procedingTR<=size(volume, 4)
                        subplot(subplotsperplot,3,subplotcounter + 2);
                        imagesc(rot90(squeeze(volume(Mid_X,:,:,procedingTR))));
                        hold on
                        title(procedingTR)
                        hold off
                        colormap('gray');
                        axis('off')
                    end
                    
                    %Increment
                    subplotcounter=subplotcounter+3;
                    confound_counter=confound_counter+1;
                end
                
                suptitle(sprintf('Preceding (left), excluded (middle) and following (right) TRs\nrun %d part %d', functionalCounter,  plots))
                
                savename=sprintf('%s/Excluded_TRs_functional%s_part_%d.png', confound_dir, functional_run, plots)
                saveas(gcf, savename);
                
            end
        end
    end
end
end
