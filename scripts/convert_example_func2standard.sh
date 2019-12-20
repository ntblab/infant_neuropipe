#!/bin/bash
#
# Make the alignment to standard for all of the brains
#SBATCH --output=./logs/example_func2standard-%j.out
#SBATCH -p all
#SBATCH -t 500
#SBATCH --mem 2000


for ppt in 011917_dev02 0422171_dev02 0505171_dev02 1027161_dev02 1210161_dev02 0414172_dev02 0422172_dev02 0525172_dev02 1209161_dev02 
do
for z_type in .nii.gz _Z.nii.gz
do
for preprocessing_type in default srm
do
path=/jukebox/ntb/projects/dev02/subjects/$ppt/
input=/scratch/cellis/robust_SRM/input_nii/${preprocessing_type}/${ppt}${z_type}
output=/scratch/cellis/robust_SRM/input_standard_nii/${preprocessing_type}/${ppt}${z_type}
transformation_matrix=${path}/analysis/secondlevel/registration.feat/reg/example_func2standard.mat
standard=${path}/analysis/secondlevel/registration.feat/reg/standard.nii.gz

# Map to standard but retain voxel size
echo flirt -in $input -ref $standard -applyisoxfm 3 -init $transformation_matrix -o $output
flirt -in $input -ref $standard -applyisoxfm 3 -init $transformation_matrix -o $output
done
done
done


# Map to standard
cp /jukebox/ntb/projects/dev02/group/atlases/masks/occipital_MNI_1mm.nii.gz /scratch/cellis/robust_SRM/occipital_standard.nii.gz
cp /jukebox/ntb/projects/dev02/group/atlases/masks/A1_MNI_1mm.nii.gz /scratch/cellis/robust_SRM/A1_standard.nii.gz
