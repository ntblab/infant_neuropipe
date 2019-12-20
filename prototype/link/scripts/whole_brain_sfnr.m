%% Calculate whole brain SFNR
%
% Take in all the functional volumes from a given folder, mask them and
% calculate the SD of these volumes over time. Will not work well if there
% is large amounts of movements (although the masking is conservative
% enough to deal with small amounts of movement).
% 
% Supply the path which specifies the functionals to be tested and their
% outputs

function whole_brain_sfnr(Input_file, Output_dir, Confound_File)

if nargin==0
    Input_file='data/nifti/*functional*.nii.gz';
    Output_dir='data/qa/';
end

% Get the project directory
addpath scripts
globals_struct=read_globals; % Load the content of the globals folder

addpath(genpath([globals_struct.PACKAGES_DIR, '/NIfTI_tools/']))

% If there are no slashes then assume that you should be using the full
% path for this file
if strcmp(Input_file(1), '/')==0
    Input_file=[pwd, '/', Input_file];
    
    fprintf('Assuming that the full path of the files is %s\nFull path is necessary to determine what Confound file is associated with this volume\n\n', Input_file);
end

% Identify the subject directory for finding the confound file
if nargin~=3 || ~isempty(Confound_File)
    slash_idxs=strfind(Input_file, '/');
    Idx=strfind(Input_file, '/subjects/')+10<slash_idxs; Idx=slash_idxs(min(find(Idx==1))); % Find the minimum index of a slash that comes after the subjects directory, that is the last character of the subject directory
    subject_dir=Input_file(1:Idx);
end

%What are the file names for the functionals
Filenames=dir(Input_file);
Filenames = Filenames(arrayfun(@(x) ~strcmp(x.name(1),'.'), Filenames));

for Filecounter = 1:length(Filenames)
    
    %% Load functional
    
    Base=Input_file(1:max(strfind(Input_file, '/')));
    
    %What is the filename
    Filename=[Base, Filenames(Filecounter).name];
    
    % Load in functional (alignment might be wrong)
    nifti=load_untouch_nii(Filename);
    
    brain = double(nifti.img);
    
    fprintf('Loading %s\n', Filename)
    
    %% Exclude some TRs
    
    % Identify the TRs that will be included in the analysis going forward
    
    if nargin<3
        % What run is this
        Run=Filename(strfind(Filename, 'functional')+10:strfind(Filename, 'functional')+11);
        Confound_File=sprintf('%s/analysis/firstlevel/Confounds/MotionConfounds_%s.txt', subject_dir, Run);
    end
    
    if exist(Confound_File)==2
        Confounds=dlmread(Confound_File);
        
        % Remove all columns that don't sum to one
        Confounds=Confounds(:, sum(Confounds,1)==1);
        
        if size(Confounds,1)==size(brain,4)
            Excluded_TRs=find(sum(Confounds,2)==1);
            Included_TRs=setdiff(1:size(brain,4),Excluded_TRs);
            
            brain=brain(:,:,:,Included_TRs);
            
            fprintf('Using %s to exclude %d TRs\n', Confound_File, length(Excluded_TRs));
        else
            fprintf('%s doesn''t match length, not excluding any TRs\n', Confound_File);
        end
    else
        fprintf('%s not found, not excluding any TRs\n', Confound_File);
    end
    
    
    %% Calculate sfnr
    
    % Find the sfnr of each voxel (Calculated using Friedman and Glover
    % (2006), 'Reducing interscanner variability of activation in a
    % multicenter fMRI study: controlling for
    % signal-to-fluctuation-noise-ratio (SFNR) differences.')
    % Use a second order polynomial for detrending
    order=2;
    
    %Create a detrended time series of each voxel. First reorganize the
    %brain to be voxel by TR
    brain_mat=reshape(brain, size(brain,1)*size(brain,2)*size(brain,3), size(brain,4));
    detrended_brain=brain_mat;
    
    trs=1:size(brain_mat,2);
    for VoxelCounter=1:size(brain_mat,1)
        
        coefs=polyfit(trs, brain_mat(VoxelCounter,:), order);
        
        predicted=(coefs(1)*trs.^2)+(coefs(2)*trs)+coefs(3);
        
        detrended_brain(VoxelCounter,:)=predicted-brain_mat(VoxelCounter,:);
    end
    
    %Reshape the detrended brain
    detrended_brain= reshape(detrended_brain, size(brain,1), size(brain,2), size(brain,3), size(brain,4));
    
    sfnr_map=mean(brain, 4) ./ std(detrended_brain, [], 4);
    
    %If the mean is very low (below hundred, assume that the sfnr should be
    %zero). This is a very important line. Without this, the maps look very
    %different. Generally it improves things but not necessarily
    
    sfnr_map(mean(brain, 4)<100)=0;
    
    % Find the distribution of the maps.
    [binval, bins]=hist(sfnr_map(~isnan(sfnr_map(:))),100);
    
    % Zero pad the values so that if the first peak is near zero then you
    % will still catch it
    padding = zeros(1,5);
    bins = [padding, bins];
    binval = [padding, binval];
    
    %% Make an sfnr mask
    
    %Find all the peaks in the data
    [peaks, peak_idx]=findpeaks(binval);
    
    %Pick the two highest peaks (If the data is not bimodal this may act
    %strange)
    if length(peaks)>=2
        [~,max_idx]=max(peaks);
        [~,max_idx(2)]=max(peaks(setdiff(1:length(peaks),max_idx)));
        
        % Take the inverse of the values between these peaks
        binval_inv=max(binval(peak_idx(min(max_idx)):peak_idx(max(max_idx))))-binval(peak_idx(min(max_idx)):peak_idx(max(max_idx)));
        
        % Find the peak of the inverse (minima)
        [~, min_idx]=max(binval_inv);
        
        % What is the sfnr threshold
        Threshold=bins(peak_idx(min(max_idx))+min_idx-1); 
    else
        Threshold=0;
    end
    
    % Make the mask
    mask = sfnr_map > Threshold;
    
    %% Plot
    
    hist(sfnr_map(~isnan(sfnr_map(:))), 100);
    hold on;
    plot([Threshold, Threshold], [0, max(binval)*1.1]);
    hold off;
    xlim([0 100]);
    ylim([0 max(binval)*1.1]);
    title(Filenames(Filecounter).name);
    
    %Save the figure
    saveas(gcf, [Output_dir, 'sfnr_', Filenames(Filecounter).name(1:end-6), 'fig']);
    
    %% Save the nifti
    nifti.hdr.dime.dim(5)=1; % Change so that it is only 1 TR
    
    nifti.img=sfnr_map;
    nifti.hdr.dime.cal_max=max(sfnr_map(:));
    nifti.hdr.dime.cal_min=min(sfnr_map(:));
    save_untouch_nii(nifti, [Output_dir, 'sfnr_', Filenames(Filecounter).name])
    
    % Save the mask
    nifti.img=double(mask);
    nifti.hdr.dime.cal_max=1; % Change the range
    nifti.hdr.dime.cal_min=0;
    save_untouch_nii(nifti, [Output_dir, 'sfnr_mask_', Filenames(Filecounter).name])
    
    fprintf('Saving %s, threshold is %0.02f\n', [Output_dir, 'sfnr_mask_', Filenames(Filecounter).name], Threshold)
    
end

