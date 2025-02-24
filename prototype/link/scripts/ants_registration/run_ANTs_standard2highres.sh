#!/bin/bash
#
# Use the ANTs transformation to align a volume from (adult) standard space into the infant anatomical space
# This first checks that the ANTs code has been run and the folder exists
# It then transforms from standard to infant standard, then runs the inverse of the ants
#
#SBATCH --output=logs/ants_standard2highres-%j.out
#SBATCH -p psych_day
#SBATCH -t 60
#SBATCH --mem 10000

source globals.sh

# The name of the file in standard space you want in anatomical space
input_file=$1

# Where do you want to save this file
output_file=$2

# If an extra argument is supplied then use it as the directory to move into to run this code
if [ "$#" -gt 2 ]
then

ppt_dir=$3

echo Moving in to $ppt_dir
cd $ppt_dir

fi

echo Using $input_file
echo Outputting $output_file

# Set up some variables
dimensionality=3
ants_dir=analysis/secondlevel/registration_ANTs
infant_standard_vol=$ants_dir/infant_standard.nii.gz

# Check that the directory exists
if [ ! -e $ants_dir ]
then

echo ANTs directory does not exist, exiting. 
echo Run `scripts/ants_registration/run_ANTs_highres2standard.sh`

fi

# Transform from standard to infant standard
infant_standard_transform=${ants_dir}/infant_standard2standard.mat
inv_infant_standard_transform=${ants_dir}/standard2infant_standard.mat

# Check if this file exists, if not, creating
if [ ! -e ${inv_infant_standard_transform} ]
then
echo Creating ${inv_infant_standard_transform}
convert_xfm -omat ${inv_infant_standard_transform} -inverse $infant_standard_transform
fi

# Make the transformed image
rand_num=$(((RANDOM%1000)))
temp_name=${ants_dir}/temp_${rand_num}.nii.gz

# Transform to infant standard using flirt
flirt -in $input_file -ref $infant_standard_vol -init ${inv_infant_standard_transform} -applyxfm -o ${temp_name}

# Transform to anatomical using ANTs
antsApplyTransforms -d $dimensionality -i $temp_name -o ${output_file} -r $ants_dir/example_func2highres.nii.gz -t [ $ants_dir/highres2infant_standard_0GenericAffine.mat, 1 ] -t $ants_dir/highres2infant_standard_1InverseWarp.nii.gz 

rm -f $temp_name

echo Finished
