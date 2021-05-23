#!/bin/bash
#
# Align and overlay a given set of functionals with anatomicial and standard space. 
# This function takes in an activity map and registers it to anatomical and standard
# space. It then applies the mask to the specified original anatomical
# volume. Finally, overlay the z stat_maps on the anatomicals at the given threshold
# Set the min and max of the zstats being overlayed
#
# Don't quit at any error since there is often a copy error with the highres
# set -ue
#
# This script defaults to use the ANTs registration to standard as a default. If it doesn't find it then it will crash. If you would like it to use the manual registration then set this input argument to 0. If you want it to use ANTs first but manual if not supplied then set this to -1
#
#SBATCH --output=logs/align_stats-%j.out
#SBATCH -p short
#SBATCH -t 30
#SBATCH --mem 5000
#SBATCH -n 1

stat_maps=$1
zmin=$2
zmax=$3
use_ants=$4 # Do you want to use ANTs for registration to standard (1), manual (0) or either in that order (-1)

# Source globals
source ./globals.sh

if [ $# -eq 1 ]
then
	zmin=2.3
	zmax=3
	use_ants=1 
fi

# What experiment does this stat map belong to?
Experiment=`echo ${stat_maps#*secondlevel_} | sed 's/\/.*//'`

# Preset files
highres_reg_folder=analysis/secondlevel/registration.feat/reg/
mask=analysis/secondlevel/default/mask_${Experiment}.nii.gz

# Get path to FSL standard directory
fsl_data=`which fsl`
fsl_data=${fsl_data%bin*}
fsl_data=$fsl_data/data/standard/
adult_standard=$fsl_data/MNI152_T1_1mm.nii.gz

if [ ! -e $mask ]
then
	echo "${mask} doesn't exist. Check that the first input value contains secondlevel_XXXX in the path."
	exit
fi

# Check if the highres file exists
original_highres=analysis/secondlevel/highres_original.nii.gz
if [ ! -e $original_highres ]
then
	echo "${original_highres} doesn't exist. Make it by copying the base anatomical image"
	exit
fi

# Loop through the inputs, adding them to the command line
for word in $stat_maps
do	
	
	# Set up all the names
	functional=$word
	participant=`pwd`; participant=`echo ${participant#*subjects/}`
	savepath=`echo "${functional%/*.nii.gz}"`
	
	registered_highres=`echo "${functional%.nii.gz}_registered_highres.nii.gz"`
	overlay_highres=`echo "${functional%.nii.gz}_Z_${zmin}_overlay_highres.nii.gz"`
	conditions=`echo "${overlay_highres#*secondlevel_}"`; conditions=`echo "${conditions%.nii.gz}"`; conditions=`echo "${conditions////_}"`
	image_highres=${savepath}/${participant}_${conditions}.png
	
	registered_standard=`echo "${functional%.nii.gz}_registered_standard.nii.gz"`
	overlay_standard=`echo "${functional%.nii.gz}_Z_${zmin}_overlay_standard.nii.gz"`
	conditions=`echo "${overlay_standard#*secondlevel_}"`; conditions=`echo "${conditions%.nii.gz}"`; conditions=`echo "${conditions////_}"`
	image_standard=${savepath}/${participant}_${conditions}.png
	
	# Register the maps
	flirt -in $functional -applyxfm -init $highres_reg_folder/example_func2highres.mat -out $registered_highres -ref $highres_reg_folder/highres.nii.gz
	
	sleep 30s # Sometimes necessary
	echo "Registered $registered_highres"
	
	# Align the second level mask to anatomical space
	if [ ! -e ${highres_reg_folder}/mask_${Experiment}.nii.gz ]
	then
		flirt -in $mask -applyxfm -init ${highres_reg_folder}/example_func2highres.mat -out ${highres_reg_folder}/mask_${Experiment}.nii.gz -ref ${highres_reg_folder}/highres.nii.gz 
	fi
	
	# Mask the anatomical
	if [ ! -e ${highres_reg_folder}/highres_masked_${Experiment}.nii.gz ]
	then
		fslmaths $original_highres -mas ${highres_reg_folder}/mask_${Experiment}.nii.gz ${highres_reg_folder}/highres_masked_${Experiment}.nii.gz
	
		sleep 30s # Sometimes necessary
		echo "Masking $original_highres"
	fi
	
	#Overlay the maps
	./scripts/overlay_stats.sh $registered_highres ${highres_reg_folder}/highres_masked_${Experiment}.nii.gz $overlay_highres $zmin $zmax
	
	sleep 30s # Sometimes necessary
	echo "Overlayed $overlay_highres"
	
	slicer $overlay_highres -a $image_highres
	
	echo "Created $image_highres"
	
	# Register to standard space
	ants_dir=analysis/secondlevel/registration_ANTs/
	standard_vol=`./scripts/age_to_standard.sh` # Get the standard volime
	if [ -e $ants_dir/highres2standard.nii.gz ] && [ $use_ants -ne 0 ]
	then
		echo Using ANTs for alignment to standard

		# If you want to use ANTs and can, do it here
		antsApplyTransforms -d 3 -i $registered_highres -o ${functional%.nii.gz}_tmp.nii.gz -r $standard_vol -t $ants_dir/highres2infant_standard_1Warp.nii.gz -t $ants_dir/highres2infant_standard_0GenericAffine.mat

		flirt -in ${functional%.nii.gz}_tmp.nii.gz -ref $adult_standard -init $ants_dir/infant_standard2standard.mat -applyxfm -o $registered_standard

		# Remove file for alignment to infant standard
		rm -f ${functional%.nii.gz}_tmp.nii.gz
	else

		if [ $use_ants -eq 1 ]
		then
			# Quit if you failed to find the file
			echo "Couldn''t find ANTs directory, quitting"
			exit
		else
			echo Using manual registration for alignment to standard
			flirt -in $functional -applyxfm -init ${highres_reg_folder}/example_func2standard.mat -out $registered_standard -ref ${highres_reg_folder}/standard.nii.gz
		fi
	fi
	echo "Registered $registered_standard"
	
	#Overlay the maps
	./scripts/overlay_stats.sh $registered_standard ${highres_reg_folder}/standard.nii.gz $overlay_standard $zmin $zmax
	
	sleep 30s # Sometimes necessary
	echo "Overlayed $overlay_standard"
	
	slicer $overlay_standard -a $image_standard
	
done

echo Finished
