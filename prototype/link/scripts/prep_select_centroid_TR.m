%% Determine what the centroid TR is for the given run and output
%% appropriate motion parameters/exclusions for this functional
%
% Take in the path of the functional to be run, the name of the functional
% run you want to store it as, as well as the output directory within which
% to put the files
%
% C Ellis 2/23/19

function prep_select_centroid_TR(Functional, functional_run, confound_dir, Burn_In_TRs, useRMSThreshold, fslmotion_threshold, mahal_threshold, useCentroidTR, Loop_Centroid_TR, pca_components, conditions)

% Convert to a string so you can deal with decimals
if fslmotion_threshold == round(fslmotion_threshold)
    fslmotion_threshold_str=sprintf('%d', fslmotion_threshold);
else
    fslmotion_threshold_str=sprintf('%0.1f', fslmotion_threshold);
end

% Remove if it exists
Command=sprintf('rm -f temp_%s.nii.gz', functional_run)
unix(Command);

% Convert to a float (it changes what the example func is)
Command=(sprintf('fslmaths %s temp_%s.nii.gz -odt float', Functional, functional_run))
unix(Command);

% dim4: time dimension of functional run. Use to find total TRs
Command=sprintf('fslval temp_%s.nii.gz dim4', functional_run)
[~, TR_total]=unix(Command);

% Get the TRs minus the burnin
TR_total=str2double(TR_total);
TR_total=TR_total-Burn_In_TRs;

% Take the volume without the burn in TR. Need the exact number of TRs for later versions of FSL
Command=sprintf('fslroi temp_%s.nii.gz temp_%s.nii.gz %d %d', functional_run, functional_run, Burn_In_TRs,TR_total)
unix(Command);


%What is the middle TR
MiddleTR=floor(TR_total/2);

%Make an example func of the first TR
%fslroi extracts region of interest from an image, allows you to
%control time and space limits to the ROI
Command=sprintf('fslroi temp_%s.nii.gz temp_%s_example_func.nii.gz %d 1', functional_run, functional_run, MiddleTR)
unix(Command);

% Pull out the motion parameters for this functional
Command=sprintf('mcflirt -in temp_%s.nii.gz -out temp_mclfirt_%s -plots -reffile temp_%s_example_func.nii.gz', functional_run, functional_run, functional_run)
unix(Command);

% Identify the best example func based on how close they are to one
% another.
motionparameters=dlmread(sprintf('temp_mclfirt_%s.par', functional_run));

% Use the xyz parameters to establish distance between points (maybe
% you should include the rotation too?)
TR_distance=dist(motionparameters(:,1:3)');

%% Set up file names

%Use the RMS criteria if selected
if useRMSThreshold==1
    Threshold_text='--refrms';
    fslmotion_name='refrms';
else
    %If not, use the default name
    Threshold_text=sprintf('--fd --thresh=%s', fslmotion_threshold_str);
    fslmotion_name=sprintf('fslmotion_%s', fslmotion_threshold_str);
    
end

% What is the file name
parameters_name_standard=sprintf('%s/MotionParameters_standard_functional%s.par', confound_dir, functional_run);
parameters_name_extended=sprintf('%s/MotionParameters_extended_functional%s.par', confound_dir, functional_run);
confound_name_fslmotion=sprintf('%s/MotionConfounds_%s_functional%s.txt', confound_dir, fslmotion_name, functional_run);
metric_name=sprintf('%s/MotionMetric_%s_functional%s', confound_dir, fslmotion_name, functional_run);
confound_name_zipper=sprintf('%s/MotionConfounds_PCA_threshold_%s_functional%s.txt', confound_dir, num2str(mahal_threshold), functional_run);
confound_image_zipper=sprintf('%s/MotionConfounds_PCA_threshold_%s_functional%s.png', confound_dir, num2str(mahal_threshold), functional_run);

% Cycle through this procedure until the optimal TR is not an
% excluded TR
centroid_TR_is_Confound_TR=1;
excluded_centroid_TRs=[];
while centroid_TR_is_Confound_TR==1
    
    % Find the point with the minimum distance from all other
    % points but make sure it hasn't been excluded
    
    [~, centroid_TRs]=sort(mean(TR_distance));
    centroid_TRs=setdiff(centroid_TRs, excluded_centroid_TRs, 'stable'); %Exclude the timepoints that will be labelled as outliers
    centroid_TR=centroid_TRs(1);
    
    % Plot the positions of the head across time (blue), the default example func
    % (red) and the optimal example func (green)
    figure
    hold on;
    scatter3(motionparameters(:,1), motionparameters(:,2), motionparameters(:,3), 'b');
    scatter3(motionparameters(MiddleTR,1), motionparameters(MiddleTR,2), motionparameters(MiddleTR, 3), 'r.');
    scatter3(motionparameters(centroid_TR,1), motionparameters(centroid_TR,2), motionparameters(centroid_TR, 3), 'g.');
    plot3(motionparameters(:,1), motionparameters(:,2), motionparameters(:,3));
    hold off
    
    % Save the figure
    saveas(gcf, sprintf('%s/MotionPosition_functional%s.fig', confound_dir, functional_run));
    saveas(gcf, sprintf('%s/MotionPosition_functional%s.png', confound_dir, functional_run));
    
    %Make a new example func
    if useCentroidTR==1
        Command=sprintf('fslroi temp_%s.nii.gz %s/example_func_functional%s.nii.gz %d 1', functional_run, confound_dir, functional_run, centroid_TR-1)
    else
        % If you aren't using the centroid then use the middle TR
        Command=sprintf('fslroi temp_%s.nii.gz %s/example_func_functional%s.nii.gz %d 1', functional_run, confound_dir, functional_run, MiddleTR)
    end
    
    unix(Command);
    
    % Re run the motion correction with the new example_func
    if useCentroidTR==1
        Command=sprintf('mcflirt -in temp_%s.nii.gz -out temp_mclfirt_%s -plots -reffile %s/example_func_functional%s.nii.gz', functional_run, functional_run, confound_dir, functional_run)
        unix(Command);
    end
    
    % Save these motion parameters as the standard
    Command=sprintf('yes | cp temp_mclfirt_%s.par %s', functional_run, parameters_name_standard)
    unix(Command);
    
    %Create extended motion parameters and then either add them or
    %leave them
    Command=sprintf('mp_diffpow.sh temp_mclfirt_%s.par temp_mclfirt_%s_diff', functional_run, functional_run)
    unix(Command);
    
    Command=sprintf('paste -d '' '' temp_mclfirt_%s.par temp_mclfirt_%s_diff.dat > %s', functional_run, functional_run, parameters_name_extended)
    unix(Command);
    
    %% Calculate the TRs to be excluded
    
    %Run the motion outliers (treating the last burn out TR as the
    %baseline, the example func is used to create the motion parameters
    %but is not used as the reference). This will mean the plots and
    %the files do not align completely
    
    if Burn_In_TRs>0
        if useCentroidTR==1
            Command=sprintf('scripts/fsl_motion_outliers_example_func.sh -i %s -o %s --dummy=%d %s -p %s -s %s --reffile %s/example_func_functional%s.nii.gz', Functional, confound_name_fslmotion, Burn_In_TRs-1, Threshold_text, metric_name, [metric_name, '.txt'], confound_dir, functional_run)
        else
            Command=sprintf('fsl_motion_outliers -i %s -o %s --dummy=%d %s -p %s -s %s', Functional, confound_name_fslmotion, Burn_In_TRs-1, Threshold_text, metric_name, [metric_name, '.txt'])
        end
        
        unix(Command);
        
        %The motion confound files were made to have one extra TR at the
        %start to be used as the reference. Remove this
        if exist(confound_name_fslmotion)==2
            temp=dlmread(confound_name_fslmotion);
            fprintf('Removing first TR of confounds\n');
            dlmwrite(confound_name_fslmotion, temp(2:end,:), '\t');
        end
        
        if exist([metric_name, '.txt'])==2
            temp=dlmread([metric_name, '.txt']);
            fprintf('Removing first TR of metric\n');
            dlmwrite([metric_name, '.txt'], temp(2:end,:), '\t');
        end
    else
        
        if useCentroidTR==1
            Command=sprintf('scripts/fsl_motion_outliers_example_func.sh -i %s -o %s --dummy=%d %s -p %s -s %s --reffile %s/example_func_functional%s.nii.gz', Functional, confound_name_fslmotion, Burn_In_TRs, Threshold_text, metric_name, [metric_name, '.txt'], confound_dir, functional_run)
        else
            Command=sprintf('fsl_motion_outliers -i %s -o %s --dummy=%d %s -p %s -s %s', Functional, confound_name_fslmotion, Burn_In_TRs, Threshold_text, metric_name, [metric_name, '.txt'])
        end
        
        unix(Command);
    end
    
    % Load the fslmotion file if it exists
    if exist(confound_name_fslmotion)==2
        confounds_fslmotion=dlmread(confound_name_fslmotion);
    else
        confounds_fslmotion=[];
    end
    
    confounds_zipper=[];
    
    % Run additional motion outliers detection
    if isstr(mahal_threshold) || mahal_threshold>0
        
        % Pull out the volume, ignore burn in
        nii=load_untouch_nii(Functional);
        volume=double(nii.img(:,:,:,Burn_In_TRs+1:end));
        
        % Mask clearly non brain voxels
        brain_planes_number=16; %How many planes are you saying are brain?
        mask=mean(volume,4)>100;
        [~, idxs]=max(squeeze(mean(mean(mask,1),2)));
        brain_planes_idxs=idxs-(brain_planes_number/2):idxs+(brain_planes_number/2);
        
        %Bound
        brain_planes_idxs=brain_planes_idxs(brain_planes_idxs>0);
        brain_planes_idxs=brain_planes_idxs(brain_planes_idxs<=size(volume,3));
        
        mask=reshape(repmat(reshape(mask, size(volume,1)*size(volume,2)*size(volume,3), 1),1,size(volume,4)), size(volume));
        volume(mask==0)=nan;
        
        % Look at differences across planes for each TR
        planes=squeeze(nanmean(nanmean(volume,1),2));
        
        %Only consider planes that probably have brain
        brain_planes=planes(brain_planes_idxs,:);
        
        % Save a depiction of the brain planes artifacts
        imagesc(brain_planes);
        saveas(gcf, confound_image_zipper);
        
        % Do PCA on the data and identify the outliers using the early
        % components
        coefs=pca(brain_planes);
        
        %Which TRs ought to be excluded? Are you using an absolute
        %threshold or a relative cut off or IQR?
        if isstr(mahal_threshold) && strcmp(mahal_threshold, 'IQR')
            [~, mahalanobis_distance]=mahal_outlier(coefs(:,1:pca_components),0.05);
            Exclude_difference_Idxs=find(mahalanobis_distance>prctile(mahalanobis_distance,75)+iqr(mahalanobis_distance)*1.5);
        elseif mahal_threshold<1
            % Calculate the mahalanobis distance
            [~, mahalanobis_distance, pca_threshold]=mahal_outlier(coefs(:,1:pca_components),mahal_threshold);
            Exclude_difference_Idxs=find(mahalanobis_distance>pca_threshold);
        else
            [~, mahalanobis_distance]=mahal_outlier(coefs(:,1:pca_components),0.05);
            Exclude_difference_Idxs=find(mahalanobis_distance>mahal_threshold);
        end
        
        % Exclude TRs
        confounds_zipper=zeros(size(volume,4), 1);
        for Exclude_Counter=1:length(Exclude_difference_Idxs)
            Idx=Exclude_difference_Idxs(Exclude_Counter);
            confounds_zipper(Idx,Exclude_Counter)=1;
            
        end
        
        % Save the confound files
        dlmwrite(confound_name_zipper, confounds_zipper, '\t')
        
    end
    
    % Combine so that you can test whether this centroid TR is
    % excluded
    confounds_overall=[confounds_fslmotion, confounds_zipper];
    
    % Is the centroid_TR a confound? If so, then keep looping until
    % you find a TR that this doesn't happen for. If this is the last TR available then just take a TR
    % that will be excluded since you probably won't use this
    % block anyway.
    if length(confounds_overall)==0 || sum(confounds_overall(centroid_TR,:))==0 || length(excluded_centroid_TRs)==size(motionparameters,1) || Loop_Centroid_TR==0  || size(confounds_overall,1)-size(confounds_overall,2)<5
        % Break the loop
        centroid_TR_is_Confound_TR=0;
        
        % Warn if all or almost all of the TRs are to be excluded
        if str2double(TR_total)-size(confounds_overall,2)<5
            warning('There are as many confound TRs as here are TRs. Since the whole block will be excluded, you can just use whatever TR, it won''t matter')
        end
        
        % What is the name of this example func that is being run
        conditions_TR=['TR_', num2str(centroid_TR + Burn_In_TRs), conditions];
        
        % Save the example functional with the identifer for its
        % condition
        Command=sprintf('cp %s/example_func_functional%s.nii.gz %s/example_func_functional%s_%s.nii.gz', confound_dir, functional_run, confound_dir, functional_run, conditions_TR)
        unix(Command);
        
        % Remove any temp files made in the progress
        Command=sprintf('rm -f temp_*%s* ', functional_run)
        unix(Command);
    else
        % Delete all the files that were made that now need to be
        % remade
        Command=sprintf('rm -f %s %s', parameters_name_standard, parameters_name_extended, confound_name_fslmotion, confound_name_zipper)
        unix(Command);
        
        % Add to the list of TRs that can't be a centroid
        excluded_centroid_TRs(end+1)=centroid_TR;
        
        fprintf('The TR selected to be the centroid: %d is a confound to be excluded. Running again...\n\n', centroid_TR);
        
    end
    
end
end


function [o, D2_reordered, D2C]=mahal_outlier(X,alpha)
%Calculate the mahalanobis distance of the points using a modified version
%of the moutlier1 script used by:
%  Trujillo-Ortiz, A., R. Hernandez-Walls, A. Castro-Perez and K. Barba-Rojo. (2006).
%    MOUTLIER1:Detection of Outlier in Multivariate Samples Test. A MATLAB file. [WWW document].
%    URL http://www.mathworks.com/matlabcentral/fileexchange/loadFile.do?objectId=12252
%
%Takes in a set of coordinates and a significance threshold to determine
%which coordinates are multivariate outliers


if nargin < 2
    alpha = 0.05;  %(default)
end

if nargin < 1
    error('Requires at least one input arguments.');
end

mX = mean(X); %Means vector from data matrix X.
[n,p] = size(X);
difT = [];

for j = 1:p
    eval(['difT=[difT,(X(:,j)-mean(X(:,j)))];']); %squared Mahalanobis distances.
end

S = cov(X);
D2T = difT*inv(S)*difT';
[D2,cc] = sort(diag(D2T));  %Ascending squared Mahalanobis distances.

D2C = ACR(p,n,alpha);

idx = find(D2 >= D2C);
o = cc(idx);

% Reorder this file to be in TR time
D2_reordered=zeros(length(D2),1);
for counter=1:length(D2)
    D2_reordered(cc(counter))=D2(counter);
end
end
