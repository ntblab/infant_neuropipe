#!/bin/bash
# Make the freesurfer folder so that you can run the subsequent steps of making the inflated and spherical version
#
# Point this to a directory that is produced from iBEAT containing the seg and surface files. 
# This will use name suffixes to find it so make sure there is nothing else called *-iBEAT.nii.gz and 4 *.vtk for inner vs outer and left vs right surfaces
#
# Expected files in this directory:
# subject-X-iBEAT.nii.gz
# subject-X-T1w.nii.gz
# subject-X-iBEAT.?h.InnerSurf.*.vtk
# subject-X-iBEAT.?h.OuterSurf.*.vtk
#
# Point to a freesurfer directory that you can use for getting baseline aseg and annotation files
#
# This will create a folder under analysis/freesurfer/iBEAT/
#
# Once created, you should check that the surfaces are aligned to the highres
#
# Example command:
# ./scripts/iBEAT/scaffold_iBEAT.sh analysis/freesurfer/iBEAT/raw/ analysis/freesurfer/petra01_brain/

source globals.sh

# What is the directory containing the output from iBEAT directly
raw_dir=$1

# What is the directory containing the freesurfer data you want to use for reference
baseline_fs_dir=$2

# Where should the data go
FS_DIR=analysis/freesurfer/iBEAT/

# Create the directory
mkdir -p ${FS_DIR}
mkdir -p ${FS_DIR}/mri/
mkdir -p ${FS_DIR}/mri/orig/
mkdir -p ${FS_DIR}/surf/
mkdir -p ${FS_DIR}/stats/
mkdir -p ${FS_DIR}/label/
mkdir -p ${FS_DIR}/scratch/

iBEAT_file=`ls ${raw_dir}/*-iBEAT.nii.gz`
fslmaths $iBEAT_file  -thr 1 -bin ${FS_DIR}/mri/mask.nii.gz
fslmaths $iBEAT_file  -thr 3 -bin ${FS_DIR}/mri/wm.nii.gz

# Copy over the data
T1w_file=`ls ${raw_dir}/*-T1w.nii.gz`
cp ${T1w_file} ${FS_DIR}/mri/T1.nii.gz
cp ${T1w_file} ${FS_DIR}/mri/brainmask.nii.gz
cp ${baseline_fs_dir}/mri/aseg.mgz ${FS_DIR}/mri/
cp ${baseline_fs_dir}/label/*annot ${FS_DIR}/label/

# Make the vtk files into gifti and fix the headers 
surfaces=`ls ${raw_dir}/*.vtk`
for surface in $surfaces
do

	# Pull out the Hemi and Layer information
	hemi=`echo ${surface#*iBEAT.}`
	hemi=`echo ${hemi%%.*}`
	
	layer=`echo ${surface#*${hemi}.}`
	layer=`echo ${layer%Surf*}`

	# Convert the data to gii
	mris_convert ${surface} ${FS_DIR}/scratch/${hemi}.${layer}.surf.gii

	# Update the header of the gii file
	./scripts/iBEAT/change_gii_meta_data.sh ${FS_DIR}/scratch/${hemi}.${layer}.surf.gii ${FS_DIR}/scratch/${hemi}.${layer}.surf.gii
done

# Make the masks
fslmaths ${FS_DIR}/mri/brainmask.nii.gz -mas ${FS_DIR}/mri/mask.nii.gz ${FS_DIR}/mri/brainmask.nii.gz
fslmaths ${FS_DIR}/mri/mask.nii.gz -mul 255 ${FS_DIR}/mri/filled.nii.gz
fslmaths ${FS_DIR}/mri/T1.nii.gz -mas ${FS_DIR}/mri/mask.nii.gz ${FS_DIR}/mri/brain.nii.gz

# Convert all the data to mgz
mri_convert ${FS_DIR}/mri/T1.nii.gz ${FS_DIR}/mri/T1.mgz
mri_convert ${FS_DIR}/mri/brain.nii.gz ${FS_DIR}/mri/brain.mgz
mri_convert ${FS_DIR}/mri/brainmask.nii.gz ${FS_DIR}/mri/brainmask.mgz
mri_convert ${FS_DIR}/mri/filled.nii.gz ${FS_DIR}/mri/filled.mgz
mri_convert ${FS_DIR}/mri/wm.nii.gz ${FS_DIR}/mri/wm.mgz
cp ${FS_DIR}/mri/T1.mgz ${FS_DIR}/mri/orig.mgz

echo Finished
