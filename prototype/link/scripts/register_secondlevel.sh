#!/bin/bash
#
# Generate the default registration at second level. This uses the first
# functional run for the highres2standard alignment. Since the data at
# second level is aligned to the highres (but downsampled) then the
# alignment of the functionals to highres is trivial. 
# Check that this worked by checking:
#      fslview example_func2standard.nii.gz standard.nii.gz
# If this doesn't look good then you have a few steps you can take:
# 	1. Give a different standard brain as the reference (by giving a path as an argument to this function)
# 	2. Perform more skull stripping on the highres you are using (and then only run the second half of this code). Could use bet2 with the -g parameter
# 	3. Use manual alignment (scripts/manual_registration.sh)
#
#SBATCH --output=./logs/register_secondlevel-%j.out
#SBATCH -p short
#SBATCH -t 30
#SBATCH --mem 10G
#
# C Ellis 042618 

# Source globals
source globals.sh

# Do you want to register to a new standard
if [ $# -eq 1 ]
then
	new_standard=$1
	refit_standard=1  # Do you want to use a new standard for alignment
else
	refit_standard=0  # Do you want to use a new standard for alignment
fi


# Set variable
reg_dir=analysis/secondlevel/registration.feat/reg

rm -rf analysis/secondlevel/registration.feat

# Copy the first functional that was run
# If only pseudoruns exist, look for a feat folder with 3 ???s

if [ "$(ls -A analysis/firstlevel/pseudorun)" ]
then
	functionals=( `ls -d analysis/firstlevel/functional???.feat/` )
else
	functionals=( `ls -d analysis/firstlevel/functional??.feat/` )
fi

cp -rf ${functionals[0]} analysis/secondlevel/registration.feat

# Clear out no longer accurate data
rm ${reg_dir}/example_func2highres.nii.gz
rm ${reg_dir}/highres2example_func.*
rm ${reg_dir}/standard2example_func.*
rm ${reg_dir}/example_func2standard.*
rm ${reg_dir}/*.png

# Create the example funcs
fslroi analysis/secondlevel/default/func2highres_unmasked.nii.gz ${reg_dir}/example_func.nii.gz 0 1
cp ${reg_dir}/example_func.nii.gz analysis/secondlevel/registration.feat/example_func.nii.gz

# Align the func to highres. Critically, the logic of this step is that it is already aligned so you only need to change voxel size. Do this by using an identity matrix
cp analysis/secondlevel/identity.mat ${reg_dir}/example_func2highres.mat
flirt -in ${reg_dir}/example_func.nii.gz -applyxfm -init ${reg_dir}/example_func2highres.mat -ref ${reg_dir}/highres.nii.gz -o ${reg_dir}/example_func2highres.nii.gz

# Do you want to refit the standard
if [ $refit_standard -eq 1 ] 
then
	# Update the standard 
	cp $new_standard ${reg_dir}/standard.nii.gz

	# Refit the highres to standard
	flirt -in ${reg_dir}/highres.nii.gz -ref ${reg_dir}/standard.nii.gz -o ${reg_dir}/highres2standard.nii.gz -omat ${reg_dir}/highres2standard.mat

	# Invert the transformation
	convert_xfm -omat ${reg_dir}/standard2highres.mat -inverse ${reg_dir}/highres2standard.mat
fi

# These are the same so duplicate them
cp ${reg_dir}/highres2standard.mat ${reg_dir}/example_func2standard.mat

# Transform the func to highres
flirt -in ${reg_dir}/example_func.nii.gz -applyxfm -init ${reg_dir}/example_func2standard.mat -ref ${reg_dir}/standard.nii.gz -o ${reg_dir}/example_func2standard.nii.gz

# Create the inverse
cp ${reg_dir}/standard2highres.mat ${reg_dir}/standard2example_func.mat

# Run the inversion
flirt -in ${reg_dir}/standard.nii.gz -applyxfm -init ${reg_dir}/standard2example_func.mat -ref ${reg_dir}/example_func.nii.gz -o ${reg_dir}/standard2example_func.nii.gz
