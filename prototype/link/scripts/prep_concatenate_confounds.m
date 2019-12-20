%% Concatenate the confounds
%
% Take the functional run and find the associated confound files and then
% append them together to form the final version of the confound matrices
%
% This combines the motion parameters and motion confounds
%
% C Ellis 2/23/19

function prep_concatenate_confounds(functional_run, confound_dir, fslmotion_threshold, useRMSThreshold, mahal_threshold, useExtendedMotionParameters, useExtended_Motion_Confounds)

% Convert to a string so you can deal with decimals
if fslmotion_threshold == round(fslmotion_threshold)
    fslmotion_threshold_str=sprintf('%d', fslmotion_threshold);
else
    fslmotion_threshold_str=sprintf('%0.1f', fslmotion_threshold);
    fprintf('Converting fslmotion_threshold to %s', fslmotion_threshold_str);
end

%Pull out the motion parameters, either standard or extended
if useExtendedMotionParameters==1
    Filename=sprintf('%s/MotionParameters_extended_functional%s.par', confound_dir, functional_run);
else
    Filename=sprintf('%s/MotionParameters_standard_functional%s.par', confound_dir, functional_run);
end

% Save the motion parameter setting you will use as the default
Command=sprintf('yes | cp %s %s/MotionParameters_functional%s.par', Filename, confound_dir, functional_run)
unix(Command);

OverallConfound_Mat=dlmread(Filename);

% Append if the threshold is set above zero
Confound_Mat=[];
if fslmotion_threshold>0
    
    %Use the RMS criteria if selected
    if useRMSThreshold==1
        fslmotion_name='refrms';
    else
        %If not, use the default name
        fslmotion_name=sprintf('fslmotion_%s', fslmotion_threshold_str);
    end
    
    %Pull out the fslmotion confounds as specified and append
    Filename=sprintf('%s/MotionConfounds_%s_functional%s.txt', confound_dir, fslmotion_name, functional_run);
    if exist(Filename)~=0
        Motion_Confounds=dlmread(Filename);
        OverallConfound_Mat(:,end+1:end+size(Motion_Confounds,2))=Motion_Confounds;
        Confound_Mat(:,end+1:end+size(Motion_Confounds,2))=Motion_Confounds;
    end
end

% Append if the threshold is set above zero
if useExtended_Motion_Confounds==1 && logical(isstr(mahal_threshold) || mahal_threshold>0)
    
    %Pull out the fslmotion confounds as specified and append
    Filename=sprintf('%s/MotionConfounds_PCA_threshold_%s_functional%s.txt', confound_dir, num2str(mahal_threshold), functional_run);
    if exist(Filename)~=0
        Motion_Confounds=dlmread(Filename);
        OverallConfound_Mat(:,end+1:end+size(Motion_Confounds,2))=Motion_Confounds;
        Confound_Mat(:,end+1:end+size(Motion_Confounds,2))=Motion_Confounds;
    end
end

%Write this confound matrix out
original_confound_name=sprintf('%s/OverallConfounds_functional%s_original.txt', confound_dir, functional_run);
dlmwrite(original_confound_name, OverallConfound_Mat, '\t');

fprintf('Decorrelating motion parameters\n\n')

%Decorrelate the components if appropriate
motion_decorrelator(original_confound_name, sprintf('%s/OverallConfounds_functional%s.txt', confound_dir, functional_run));

% If this is empty still then just set it to zero to make it easier
% for comparison
if isempty(Confound_Mat)
    Confound_Mat=zeros(size(OverallConfound_Mat, 1), 1);
end

% Store the confounds of interest
only_confound_name=sprintf('%s/MotionConfounds_functional%s.txt', confound_dir, functional_run);
dlmwrite(only_confound_name, Confound_Mat, '\t');
