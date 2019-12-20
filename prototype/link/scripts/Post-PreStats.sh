#!/bin/bash
#
# Run the analyses to align and aggregate across runs after the firstlevel feats.
# The result is data aligned to anatomy that has experiment and run specific
# masks in 'analysis/secondlevel/default/'. This also produces a volume
# concatenated across all runs in that folder but this is not used by default
# (there is functionality for FunctionalSplitter to use it but that is legacy). 
# #
# Example call: sbatch./scripts/Post-PreStats.sh
# #
# By default this only runs on feat folders without a suffix (e.g.
# functional01.feat); however, if an input is supplied, then that is the suffix
# of the folder which contains the data to be processed, e.g.. 'sbatch
# ./scripts/Post-PreStats.sh _smoothing8' will take all
# functional??_smoothing8.feat. as input.
# 
# This peforms six steps: aligning the firstlevel data to highres, normalizing
# volumes, concatenating motion parameters, concatenating volumes, masking
# volumes and then registering these volumes to standard.  Not all of these
# steps are necessary anymore but are included for legacy.
# #
# Note: standard space is automatically chosen to be age appropriate based on
# the information in the $PROJ_DIR/scripts/Participant_Data.txt file.
# 
# 1. Uses the transformation matrix for each run to put the functionals in
# highres space while retaining the voxel size of the functionals. This means
# the images change shape but don't become prohibitively large. This uses the
# transformation matrix and applyisoxfm. If the registrations are changed (e.g.,
# re-running manual registration), this will need to be re-run
# 
# 2. Normalizes the functional runs. This can be done by Z scoring using
# the zscore function, which takes the time series mean, subtracts each
# volume from this mean, divides by the standard deviation and then
# multiplies by negative 1 (so that values greater than the mean are
# positive). This functionality isn't needed anymore because 
# FunctionalSplitter does the Z scoring (in order to consider only used
# blocks) but it is still included.
# 
# 3. Concatenates confound regressors. Take in the motion parameters,
# and confound TRs from firstlevel and concatenate
# them to make a big file stored in the second level. Since 
# FunctionalSplitter does this cutting up, again this is legacy. For 
# instance you will notice it uses a file called 
# 'EyeData_Exclude_Epochs_functionalXX.txt' if available. This file 
# specifies blocks or events that need to be excluded because of eye 
# tracking. This information is now ignored, but it is still stored in
# case it could be useful in the future
# 
# 4. Concatenates all functional runs and stores the resulting file
# (fslmerge -t firstlevel/func_reg functional01.feat/func_reg_Z.nii.gz
# ...). Also creates a concatenated functional that is not Z scored.
# 
# 5. Masks out regions not shared between volumes. First you have to make
# a mask of the newly registered functional (fslmaths
# func2highres.nii.gz -abs -Tmean -bin mask_edit.nii.gz), then find the
# intersect of all the masks (fslmaths $Mask1 -mul $Mask2 -mul $Mask3
# ... $IntersectMask) and finally mask out the registered functionals
# (fslmaths $Functional -mas $IntersectMask $Functional)
# 
# 6. Registers to standard space. Create a registration.feat folder with
# a guess of the appropriate alignment to standard space. Since the data
# is already aligned to highres space, the example_func2standard
# transformation is the same as the highres2standard.
# 
# First made by C Ellis 4/26/16 Added motion parameter concatenator C
# Ellis 2/1/17
# Extended functionality, C Ellis 4/4/18
# Shifted the focus to be on firstlevel, rather than on the concatenated secondlevel, C Ellis 3/3/19
#
#SBATCH --output=./logs/Post-PreStats-%j.out
#SBATCH -p short
#SBATCH -t 300
#SBATCH --mem 20G

#Stop at any error
#set -ue

#Preload these values
source globals.sh
interpolation=nearestneighbour  #What interpolation method should be used

#Specify which feat directories you want to aggregate
if [ $# -eq 0 ]
then

	analysis_type=''
	analysis_name='default'
	echo "No analysis name supplied. Assuming analysis is the default"
	
else
	analysis_type="_$1"
	analysis_name=$1
	echo "Assuming the feat directory ends with ${analysis_name}"
fi

#Save the folder
saveFolder=$REGCONCAT_DIR/${analysis_name}

# Make the folder if it doesn't exist already
if [ ! -d $saveFolder ]; then
	mkdir $saveFolder
fi

# Remove the current contents of the folder
rm -f $saveFolder/*.gz
rm -f $REGCONCAT_DIR/Confounds/MotionParameters.txt
rm -f $REGCONCAT_DIR/Confounds/MotionConfounds.txt
rm -f $REGCONCAT_DIR/Confounds/EyeData_Exclude_Epochs.txt
rm -f $REGCONCAT_DIR/Confounds/Motion_Exclude_Epochs.txt
rm -f $REGCONCAT_DIR/Confounds/OverallConfounds*.txt

#Find the  feat directories
FeatFolders=`ls -d $PRESTATS_DIR/functional*${analysis_type}.feat`

# If no analysis_type is specified but there are other analysis types in the folder then you need to remove them from this list
if [[ $analysis_type == '' ]]
then
	all_FeatFolders=$FeatFolders
	FeatFolders=''
	for folder in $all_FeatFolders
	do
		
		# If this folder name has an underscore then it shouldn't be included
		if [[ $folder != *"functional"*"_"*".feat" ]]
		then
			FeatFolders="${FeatFolders} ${folder}"
		fi
	done
fi

#Make a mask to start with 
rm -f $saveFolder/mask*.nii.gz # Deleting the experiment specific masks (so that new ones are made)


#Iterate through all of the feat directories (ignores +s so make sure
#the first feat is the one you care about)
#
for featFolder in $FeatFolders
do
	
	# What is the feat number (plus pseudorun index if necessary)
	functionalName=`echo ${featFolder%${analysis_type}.feat*}`
	functionalName=${functionalName#*functional}
	
	#Find the length in TRs of the file
	TotalTRs=`fslval $featFolder/filtered_func_data.nii.gz dim4`
	voxel_size=`fslval $featFolder/filtered_func_data.nii.gz pixdim1`
	
	# Create a folder to put the aligned data into
	aligned_highres=$featFolder/aligned_highres/
	rm -rf $aligned_highres
	mkdir -p $aligned_highres
	
	#### STEP 1. REGISTRATION TO HIGHRES ####
	echo \#\#\#\# STEP 1. REGISTRATION TO HIGHRES \#\#\#\#
	echo  Functional $functionalName
	
	#Realign the functionals
	flirt -in $featFolder/filtered_func_data.nii.gz -applyisoxfm $voxel_size -init $featFolder/reg/example_func2highres.mat -out $aligned_highres/func2highres_unmasked.nii.gz -ref $featFolder/reg/highres.nii.gz -interp $interpolation
	
	# To convert from this low res to highres, do the following
	#flirt -in $func -applyxfm -init $SUBJECT_DIR/analysis/secondlevel/identity.mat -out $func_highres -ref $highres 

	#### STEP 2. NORMALIZATION ####
	echo \#\#\#\#\#\#\#\#\# STEP 2. NORMALIZATION \#\#\#\#\#\#\#\#\#
	echo Functional $functionalName
	
	#Generate the normalized volume
	# $SCRIPT_DIR/zscore_nii.sh $aligned_highres/func2highres_unmasked.nii.gz $aligned_highres/func2highres_Z_unmasked.nii.gz
	 
	#Remove the variance volume
	# rm -f $aligned_highres/func2highres_*std*.nii.gz

	#Create a new mask based on this newly registered volume
	flirt -in $featFolder/mask.nii.gz -applyisoxfm $voxel_size -init $featFolder/reg/example_func2highres.mat -out $aligned_highres/mask2highres.nii.gz -ref $featFolder/reg/highres.nii.gz -interp $interpolation
	
	if [ ! -e $saveFolder/mask.nii.gz ]
	then
		x=`fslval $aligned_highres/func2highres_unmasked.nii.gz dim1`
		y=`fslval $aligned_highres/func2highres_unmasked.nii.gz dim2`
		z=`fslval $aligned_highres/func2highres_unmasked.nii.gz dim3`
		tr=`fslval $aligned_highres/func2highres_unmasked.nii.gz dim3`
		fslcreatehd $x $y $z 1 $voxel_size $voxel_size $voxel_size $tr 0 0 0 16 $saveFolder/mask.nii.gz
		fslmaths $saveFolder/mask.nii.gz -add 1 $saveFolder/mask.nii.gz
	fi
	
	#Find all the timing files from this functional
	root=analysis/firstlevel/Timing/functional${functionalName}
	run_timing_files=`ls ${root}*.txt`
	
	# Iterate through all of the txt files
	for run_timing_file in $run_timing_files
	do
		# Remove the text from the timing file
		experiment_name=`echo ${run_timing_file#*functional${functionalName}_}`
		experiment_name=`echo ${experiment_name%-*}`

		#Make a mask if it doesn't exist
		if [ ! -e $saveFolder/mask_${experiment_name}.nii.gz ]; then

			x=`fslval $aligned_highres/func2highres_unmasked.nii.gz dim1`
			y=`fslval $aligned_highres/func2highres_unmasked.nii.gz dim2`
			z=`fslval $aligned_highres/func2highres_unmasked.nii.gz dim3`
			tr=`fslval $aligned_highres/func2highres_unmasked.nii.gz dim3`
			fslcreatehd $x $y $z 1 $voxel_size $voxel_size $voxel_size $tr 0 0 0 16 $saveFolder/mask_${experiment_name}.nii.gz
			fslmaths $saveFolder/mask_${experiment_name}.nii.gz -add 1 $saveFolder/mask_${experiment_name}.nii.gz

		fi
		
		#Create experiment specific masks
		fslmaths $saveFolder/mask_${experiment_name}.nii.gz -mul $aligned_highres/mask2highres.nii.gz $saveFolder/mask_${experiment_name}.nii.gz
	done
			
	#Create an overall mask with this in preparation for Step 5.
	fslmaths $saveFolder/mask.nii.gz -mul $aligned_highres/mask2highres.nii.gz $saveFolder/mask.nii.gz
	
	#### STEP 3. CONFOUNDS ####
	echo \#\#\#\# STEP 3. CONCATENATING CONFOUNDS \#\#\#\#
	echo Functional $functionalName
	
	# Do the same for each confound type separately ()
    MotionFile=$FIRSTLEVEL_DIR/Confounds/MotionParameters_functional${functionalName}.par
	matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('$SCRIPT_DIR'); append_regressor_file('$MotionFile', '$REGCONCAT_DIR/Confounds/MotionParameters.txt', '0');"
		
	#Concatenate the confound files (if it doesn't exist then make it)
	ConfoundFile=$FIRSTLEVEL_DIR/Confounds/MotionConfounds_functional${functionalName}.txt
    line_num=`cat $ConfoundFile 2>/dev/null | wc -l`
    if [ $line_num -gt 0 ]; then
		matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('$SCRIPT_DIR'); append_regressor_file('$ConfoundFile', '$REGCONCAT_DIR/Confounds/MotionConfounds.txt', '1');"
	else		
		matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('$SCRIPT_DIR'); append_regressor_file('$TotalTRs', '$REGCONCAT_DIR/Confounds/MotionConfounds.txt', '0');"
	fi
	
	#Concatenate the EyeData_Exclude_Epochs files (if it doesn't exist then make it)
	EyeData_Exclude_File=$FIRSTLEVEL_DIR/Confounds/EyeData_Exclude_Epochs_functional${functionalName}.mat
    line_num=`cat $EyeData_Exclude_File 2>/dev/null | wc -l`
    if [ $line_num -gt 0 ]; then
		matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('$SCRIPT_DIR'); append_regressor_file('$EyeData_Exclude_File', '$REGCONCAT_DIR/Confounds/EyeData_Exclude_Epochs.txt', '1');"
	else		
		#Make a list of 0s the same size as there are TRs
		matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('$SCRIPT_DIR'); append_regressor_file('$TotalTRs', '$REGCONCAT_DIR/Confounds/EyeData_Exclude_Epochs.txt', '0');"
	fi
	
	#Concatenate the Motion_Exclude_Epochs files (if it doesn't exist then make it)
	Motion_Exclude_File=$FIRSTLEVEL_DIR/Confounds/Motion_Exclude_Epochs_functional${functionalName}.mat
    line_num=`cat $Motion_Exclude_File 2>/dev/null | wc -l`
	if [ $line_num -gt 0 ]; then
		matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('$SCRIPT_DIR'); append_regressor_file('$Motion_Exclude_File', '$REGCONCAT_DIR/Confounds/Motion_Exclude_Epochs.txt', '1');"
	else		
		matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('$SCRIPT_DIR'); append_regressor_file('$TotalTRs', '$REGCONCAT_DIR/Confounds/Motion_Exclude_Epochs.txt', '0');"
	fi

	# Force a sleep so that you have time to make all the regressors
	sleep 60s
	
done

# Concatenate the columns of the Confound regressors to make an overall file

paste -d' ' $REGCONCAT_DIR/Confounds/MotionParameters.txt $REGCONCAT_DIR/Confounds/MotionConfounds.txt > $REGCONCAT_DIR/Confounds/OverallConfounds_original.txt
#paste -d' ' $REGCONCAT_DIR/Confounds/MotionParameters.txt $REGCONCAT_DIR/Confounds/MotionConfounds.txt $REGCONCAT_DIR/Confounds/EyeData_Exclude_Epochs.txt $REGCONCAT_DIR/Confounds/Motion_Exclude_Epochs.txt > $REGCONCAT_DIR/Confounds/OverallConfounds_original.txt
#paste -d' ' $REGCONCAT_DIR/Confounds/MotionParameters.txt $REGCONCAT_DIR/Confounds/MotionConfounds.txt $REGCONCAT_DIR/Confounds/EyeData_Exclude_Epochs.txt > $REGCONCAT_DIR/Confounds/OverallConfounds_original.txt
#paste -d' ' $REGCONCAT_DIR/Confounds/MotionParameters.txt $REGCONCAT_DIR/Confounds/MotionConfounds.txt > $REGCONCAT_DIRConfounds//OverallConfounds_original.txt

# De-correlate the overall confounds
matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('$SCRIPT_DIR'); motion_decorrelator('$REGCONCAT_DIR/Confounds/OverallConfounds_original.txt', '$REGCONCAT_DIR/Confounds/OverallConfounds.txt');"

#### STEP 4. CONCATENTATE ####

echo \#\#\# STEP 4. CONCATENATING FUNCTIONALS \#\#\#
echo Functional all

#Merge the files
for featFolder in $FeatFolders
do
	# If this file doesn't exist then make it, otherwise append
	if [ ! -e $saveFolder/func2highres_unmasked.nii.gz ]
	then
		cp $featFolder/aligned_highres/func2highres_unmasked.nii.gz $saveFolder/func2highres_unmasked.nii.gz 
		#cp $featFolder/aligned_highres/func2highres_Z_unmasked.nii.gz $saveFolder/func2highres_Z_unmasked.nii.gz
	else
		fslmerge -t $saveFolder/func2highres_unmasked.nii.gz $saveFolder/func2highres_unmasked.nii.gz $featFolder/aligned_highres/func2highres_unmasked.nii.gz 
		#fslmerge -t $saveFolder/func2highres_Z_unmasked.nii.gz $saveFolder/func2highres_Z_unmasked.nii.gz $featFolder/aligned_highres/func2highres_Z_unmasked.nii.gz
	fi
done

#### STEP 5. MASKING ####

echo \#\#\#\#\#\# STEP 5. MASKING \#\#\#\#\#\#
echo Functional all

# Binarise the masks
masks=`ls $saveFolder/mask*.nii.gz`
for mask in $masks
do
	fslmaths $mask -bin $mask
done

# Make a version of the firstlevel data that is masked with the interrun intersect
for featFolder in $FeatFolders
do
	fslmaths $featFolder/aligned_highres/func2highres_unmasked.nii.gz -mas $saveFolder/mask.nii.gz $featFolder/aligned_highres/func2highres.nii.gz
	#fslmaths $featFolder/aligned_highres/func2highres_Z_unmasked.nii.gz -mas $saveFolder/mask.nii.gz $featFolder/aligned_highres/func2highres_Z.nii.gz
done

#Mask out the volumes with only the intersect at secondlevel
fslmaths $saveFolder/func2highres_unmasked -mas $saveFolder/mask.nii.gz $saveFolder/func2highres 
#fslmaths $saveFolder/func2highres_Z_unmasked -mas $saveFolder/mask.nii.gz $saveFolder/func2highres_Z

#### STEP 6. REGISTRATION TO STANDARD ####
echo \#\#\#\# STEP 6. REGISTRATION TO STANDARD \#\#\#
echo Functional all

# Run the registration script to align to second level
if [ ! -e analysis/secondlevel/registration.feat/ ]
then
    ./scripts/register_secondlevel.sh
fi

echo \#\#\#\# FINISHED \#\#\#

# Force a sleep to let all the scripts finish
sleep 60s
