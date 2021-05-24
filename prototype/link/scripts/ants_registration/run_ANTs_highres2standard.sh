#!/bin/bash
#
# Run the alignment of the high res anatomical image to standard space using ANTs
#
# This takes in as an input the name of the highres file you are using (e.g., petra01). Could be more specific too (e.g., petra01_brain)
# It first finds a freesurfer directory with this brain mask and transforms it into this participant space
# It then creates the skullstripped brain that is to be used for the input, but in the space used for alignment
# The data is shown to the user to check that alignment and skull strip is good. Make sure the skull strip includes the cerebellum. It is possible to do a manual edit at this step
# The age of the participant is then found and the appropriate standard space volume used
# The ANTs is then run on the data as a job script. This script hangs, waiting for that job to end. Takes about 10 minutes
# Finally it will do the last alignment step, if necessary, from infant standard to adult standard
# This also aligns the example functional image from second level to standard for comparison and then shows it for review
#
# If files already exist then this script skips those steps to expedite processing
#
# It helps to run this script on a node since there is some I/O that will tax the head node
#
# C Ellis 12/12/20

# Load the modules
source globals.sh

# Get anatomical name
anat_name=$1

# Do you want to fix the seed? There is randomness here which could affect your ability to replicate results
fix_seed="-e 1"

# Even though the analyses are in 3d, you want to set up the files to be 4d so that you can use them later for transforming the functional data to standard
dimensionality=3

# Make the ANTs directory
ants_dir=analysis/secondlevel/registration_ANTs
mkdir -p $ants_dir

# Get path to FSL standard directory
fsl_data=`which fsl`
fsl_data=${fsl_data%bin*}
fsl_data=$fsl_data/data/standard/

# Preset file names to be used later
mask_vol=$ants_dir/mask.nii.gz
ref_vol=analysis/secondlevel/highres_original.nii.gz
aligned_vol=$ants_dir/highres_brain.nii.gz

# Align the freesurfer data to the volume to use the mask from freesurfer
# This transformation should be the combination of the q form matrices and have a solution similar to "1  0  0  22\n0  0  1  22\n0 -1  0  277\n0  0  0  1"; however, to be more generally useable, it is empirically decided here
if [ ! -e $aligned_vol ]
then

	echo "Looking for skull stripped data from $anat_name"

	# Check the freesurfer directories to find the one with a brain
	fs_dirs=`ls analysis/freesurfer/${anat_name}*/mri/brain.mgz`

	# Get the first volume
	brain_vol_mgz=`echo $fs_dirs | head -n1 | awk '{print $1;}'`

	# Convert volume into nifti
	brain_vol=$ants_dir/fs_vol.nii.gz
	mri_convert $brain_vol_mgz $brain_vol

	# Run a flirt where you align this data to the reference in second level. Should just be a rotation
	
	fs_vol=$ants_dir/fs_brain.nii.gz
	flirt -in $brain_vol -ref $ref_vol -omat $ants_dir/fs_alignment.mat -o ${fs_vol} -dof 6

	# Look at the volumes to compare fit
	fslview $ref_vol ${fs_vol}

	printf "\nDoes the mask look correct (i.e., the borders line up precisely with the brain). Note, in our infant data this is good enough only a third of the time? If not press ctrl + C now to quit, otherwise wait 10s\n"
	echo "If you want to edit it, you can use the alignment you have to make a mask: fslmaths ${fs_vol} -thr 0 -bin $mask_vol; Now make the manual edits. Then do to make the final version: fslmaths $ref_vol -mas $mask_vol $aligned_vol;"
	sleep 10s

	# Make the freesurfer mask
	fslmaths ${fs_vol} -thr 0 -bin $mask_vol

	# Mask the data (it is probably the same as fs_vol but could be homogenized)
	
	fslmaths $ref_vol -mas $mask_vol $aligned_vol
else
	echo Skullstripped anatomical already created skipping 

fi

## Figure out the relevant standard volume

# Get the participant information
Participant_Data=`cat $PROJ_DIR/scripts/Participant_Data.txt`

# Get the standard brain being used
standard_vol=`scripts/age_to_standard.sh`

# Find the participant name and then the age (this is annoying since you are doing most of the work of the age_to_standard script, but otherwise it is difficult to get the naming system to call the standards_infant or _child or something
CorrectLine=0
for word in $Participant_Data
do
	# This word is the age
	if [[ $CorrectLine == 2 ]]; then
		Age=$word
		CorrectLine=0
	fi

	# Don't take the word immediately after the subject name, take the one after
	if [[ $CorrectLine == 1 ]]; then
		CorrectLine=2
	fi

	# Are you on the correct line
	if [[ $word == ${SUBJ} ]] && [[ $CorrectLine == 0 ]]; then
		CorrectLine=1
	fi

done

# Round the age to the nearest integer (although it doesn't do swedish rounding)
Age=`echo $Age | xargs printf "%.*f\n" 0`
if [ $Age -lt 60 ]
then

	# What brain type are they
	TRANSFORM_STANDARD=${standard_vol::-17}_2_MNI152_T1_1mm.mat
	brain_type='infant'
	
elif [ $Age -lt 200 ]
then

	# What brain type are they
	TRANSFORM_STANDARD=${standard_vol::-17}_2_MNI152_T1_1mm.mat
	brain_type='child'
		
else
	# If they are adults than the infant atlases then use this
	TRANSFORM_STANDARD=$PROJ_DIR/prototype/copy/analysis/secondlevel/identity.mat
	standard_vol=$fsl_data/MNI152_T1_1mm_brain.nii.gz #Default to standard
	brain_type='adult'
fi

# Copy infant standard in so you have it 
cp $standard_vol $ants_dir/infant_standard.nii.gz

# #Overwrite changes
#standard_vol=/gpfs/milgram/apps/hpc.rhel7/software/FSL/5.0.9/data/standard/MNI152_T1_1mm_brain.nii.gz
#TRANSFORM_STANDARD=$PROJ_DIR/prototype/copy/analysis/secondlevel/identity.mat

adult_standard=$fsl_data/MNI152_T1_1mm.nii.gz

echo "Using $standard_vol"

## Submit the data to ANTs
output_prefix=$ants_dir/highres2infant_standard_

# Submit job and wait
echo "Running the registration script. This will likely take ~10mins to complete. Script will wait until files are created"

# If the files exist, delete the files created from this step for clarity
if [ -e $ants_dir/*Warped.nii.gz ]
then
rm -f $ants_dir/highres2*
rm -f $ants_dir/example_func*
fi

sbatch ./scripts/ants_registration/antsRegistrationSyNQuick.sh -d $dimensionality -m $aligned_vol -f $standard_vol -o $output_prefix $fix_seed

# Copy over the affine matrix to go from infant to adult standard
cp $TRANSFORM_STANDARD $ants_dir/infant_standard2standard.mat

# Crop a TR for use later (while you are waiting)
fslroi analysis/secondlevel/default/func2highres_unmasked.nii.gz $ants_dir/example_func.nii.gz 0 1

# Align it to highres (should be just an identity matrix away)
flirt -in $ants_dir/example_func.nii.gz -ref $ref_vol -applyxfm -init analysis/secondlevel/identity.mat -o $ants_dir/example_func2highres.nii.gz

echo "If you are impatient then you can quit and run the following command when the job is done"
echo flirt -in ${output_prefix}Warped.nii.gz -ref $adult_standard -init $ants_dir/infant_standard2standard.mat -applyxfm -o $ants_dir/highres2standard.nii.gz
echo antsApplyTransforms -d $dimensionality -i $ants_dir/example_func2highres.nii.gz -o $ants_dir/example_func2infant_standard.nii.gz -r $standard_vol -t ${output_prefix}1Warp.nii.gz -t ${output_prefix}0GenericAffine.mat
echo flirt -in $ants_dir/example_func2infant_standard.nii.gz -ref $adult_standard -init $ants_dir/infant_standard2standard.mat -applyxfm -o $ants_dir/example_func2standard.nii.gz
echo flirt -in ${output_prefix}1Warp.nii.gz -init analysis/secondlevel/identity.mat -ref ${output_prefix}1Warp.nii.gz -applyisoxfm 3  -o ${output_prefix}1Warp_3mm.nii.gz
echo fslview $ants_dir/example_func2standard.nii.gz $manual_reg $adult_standard $ants_dir/highres2standard.nii.gz

# Wait until the file exists
while [ ! -e ${output_prefix}Warped.nii.gz ]
do
sleep 10s
done

echo "ANTs is complete, wrapping up"

# Once it finds it, wait a little more since the file appears before it is ready
sleep 30s

# Transform the warped output to adult standard
flirt -in ${output_prefix}Warped.nii.gz -ref $adult_standard -init $ants_dir/infant_standard2standard.mat -applyxfm -o $ants_dir/highres2standard.nii.gz

#If it exists, get the name of the manual registration to standard
manual_reg=analysis/secondlevel/registration.feat/reg/highres2standard.nii.gz
if [ ! -e $manual_reg ]
then
manual_reg="" # If the file doesn't exist then remove it
fi
 
# Transform an example TR from the default folder into this space
antsApplyTransforms -d $dimensionality -i $ants_dir/example_func2highres.nii.gz -o $ants_dir/example_func2infant_standard.nii.gz -r $standard_vol -t ${output_prefix}1Warp.nii.gz -t ${output_prefix}0GenericAffine.mat

flirt -in $ants_dir/example_func2infant_standard.nii.gz -ref $adult_standard -init $ants_dir/infant_standard2standard.mat -applyxfm -o $ants_dir/example_func2standard.nii.gz

# Downsample the warp file so that if you want to make a functional alignment then you can
flirt -in ${output_prefix}1Warp.nii.gz -init analysis/secondlevel/identity.mat -ref ${output_prefix}1Warp.nii.gz -applyisoxfm 3  -o ${output_prefix}1Warp_3mm.nii.gz

echo "Showing the results of ANTs"
fslview $ants_dir/example_func2standard.nii.gz $manual_reg $adult_standard $ants_dir/highres2standard.nii.gz 




