% Set default values for the prep_raw_data script

%% Motion exclusion
% Framewise displacement parameters
fslmotion_threshold=3; %What is the millimeter threshold for exclusion?
useRMSThreshold=0; %Do you want to use the RMS threshold as your default?

% Zipper artefact detection
mahal_threshold=0; % What is the threshold for striping to be detected? (can be IQR, a number below 1 (a criterion cut off) or a number above 1 (absolute threshold). If 0 then this is not used)
pca_components=3; %How many PCA components to consider for zippers

%% Motion parameters
useExtendedMotionParameters=0; %Do you want to use extended motion parameters?
useExtended_Motion_Confounds=0; %Do you want to look for stripping in the planes of a volume and exclude based on that?

%% Using centroid TR
useCentroidTR=1; %Do you want to use the optimal TR for analysis?
Loop_Centroid_TR=1; % Do you want to loop through the centroid TRs to find one that isn't excluded?

