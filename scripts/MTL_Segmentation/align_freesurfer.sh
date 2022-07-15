#!/bin/bash
# Align hippocampus from FreeSurfer to native space

SUBJ=$1
cd subjects/$SUBJ

source globals.sh

output=$PROJ_DIR/data/MTL_Segmentations/segmentations_freesurfer/$SUBJ.nii.gz

# Check if file exists
if [ -e $output ]
then
echo $output exists, quitting
exit
else
echo Analyzing $SUBJ
fi


files=`ls analysis/freesurfer/*/mri/brain.mgz`
for file in $files
do
mri_convert $file temp_vol.nii.gz; 
fslmaths temp_vol.nii.gz -sub analysis/secondlevel/registration_ANTs/fs_vol.nii.gz temp_diff.nii.gz; 
diff_val=`fslstats temp_diff.nii.gz -M`

if (( $(echo "$diff_val == 0" |bc -l) ))
then
break
fi
done

echo Using $freesurfer_folder

# Get the freesurfer folder
freesurfer_folder=${file%/mri/*}
freesurfer_folder=${freesurfer_folder#*freesurfer/}

# Get the aseg file
aseg=analysis/freesurfer/${freesurfer_folder}/mri/aseg.mgz

# If there is no aseg file then quit here
if [ ! -e $aseg ]
then
echo "$(pwd)/$aseg file not found, quitting"
exit
fi

# If the file chosen is not the same as the anatomical used for segmentation then quit
if [ ! -e data/masks/*${freesurfer_folder%_*}*CE.nii.gz ]
then
echo "freesurfer folder chosen mismatches mask file used, proceed manually"
echo "Chosen aseg: $aseg"
echo "Chosen mask: data/masks/*${freesurfer_folder%_*}*CE.nii.gz"
exit
fi

# Convert the aseg file to nifti
mri_convert $aseg temp_vol.nii.gz

# Transform the data into native space
flirt -in temp_vol.nii.gz -ref data/nifti/${SUBJ}_${freesurfer_folder}.nii.gz -init analysis/secondlevel/registration_ANTs/fs_alignment.mat -applyxfm -o $output -interp nearestneighbour

# Get just the hippocampus from the segmentation file
# Right HPC = 53; Left HPC = 17
fslmaths $output -thr 53 -uthr 53 -bin -mul 6 temp_right.nii.gz
fslmaths $output -thr 17 -uthr 17 -bin -mul 5 temp_left.nii.gz
fslmaths temp_right.nii.gz -add temp_left.nii.gz $output

# Plot the alignment
fslview data/nifti/${SUBJ}_${freesurfer_folder}.nii.gz $output -l Random-Rainbow
