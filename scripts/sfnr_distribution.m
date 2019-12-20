% Read in all the SFNR masks and identify the thresholds
% Plot the distribution and also report all runs with thresholds below 5

files=ls('subjects/*/analysis/firstlevel/*/sfnr_prefiltered_func_data_st.nii.gz');
LineEnds=[0, strfind(files,'gz')+2];
Filenames_all={};
Threshold_all=[];

for filecounter=1:length(LineEnds)-1
    
    Filename=files(LineEnds(filecounter)+1:LineEnds(filecounter+1)-1)
    
    % Load in functional (alignment might be wrong)
    nifti=load_untouch_nii(Filename);
    
    sfnr_map = double(nifti.img);
    
    %Load in the mean volume and zero out low values
    nifti=load_untouch_nii([Filename(1:max(strfind(Filename, '/'))), 'mean_func.nii.gz']);
    brain= double(nifti.img);
    sfnr_map(brain<100)=0;
    
    % Find the distribution of the maps.
    [binval, bins]=hist(sfnr_map(~isnan(sfnr_map(:))),100);
    
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
    Filenames_all{end+1}=Filename;
    Threshold_all(end+1)=Threshold;

end

hist(Threshold_all)
Filenames_all{Threshold_all<5}
