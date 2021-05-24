#!/bin/bash
#
# Align a secondlevel functional to standard space. It takes as input the name of the functional to register which is aligned to highres although may be in native resolution, and optionally, an output filename and whether to use ANTs for registration. Assumed to run in the participant folder 
#
# e.g., sbatch ./scripts/align_functionals.sh analysis/secondlevel_MM/default/NIFTI/MM-Full_Pilot_NoAudio_Z.nii.gz data/Movies/Aeronaut/preprocessed_standard/nonlinear_alignment/${SUBJ}_Z_registered_standard.nii.gz 1
#
#
# This script defaults to use the ANTs registration to standard as a default. If it doesn't find it then it will crash. If you would like it to use the manual registration then set this input argument to 0. If you want it to use ANTs first but manual if not supplied then set this to -1
#
#
#SBATCH --output=logs/align_functionals-%j.out
#SBATCH -p psych_day
#SBATCH -t 3:00:00
#SBATCH --mem 5000
#SBATCH -n 1

input_func=$1 # input functional image
output_func=$2 # output name (optional)
use_ants=$3 # Do you want to use ANTs for registration to standard (1), manual (0) or either in that order (-1)

# Default to run ANTs
if [ $# -eq 2 ]
then
        use_ants=1
fi

# Source globals
source ./globals.sh


if [ $# -eq 1 ]
then
	#if they didn't specify, output the registered image to the same location as the input
	output_func=${input_func%%.*}_registered_standard.nii.gz 

	# Default to use ANTs
	use_ants=1 
fi

# Get the adult standard
fsl_data=`which fsl`
fsl_data=${fsl_data%bin*}
fsl_data=$fsl_data/data/standard/

adult_standard=$fsl_data/MNI152_T1_1mm_brain.nii.gz

# Register to standard space
ants_dir=analysis/secondlevel/registration_ANTs/
standard_vol=`./scripts/age_to_standard.sh` # Get the standard volume
highres_reg_folder=analysis/secondlevel/registration.feat/reg/

if [ -e $ants_dir/highres2standard.nii.gz ] && [ $use_ants -ne 0 ]
then


	echo "Using ANTs for alignment to standard"

	# If you want to use ANTs and can, do it here

	# First we need to set up a temp folder for all the temp files we will create ...
	tmp_dir=$(mktemp -d -p /tmp)
	
	echo "Temp directory for registration: $tmp_dir"

	if [[ -d $tmp_dir ]]
	then
		echo "Splitting files now"
	else
		echo "Aborting -- failed to make temp directory"
		exit 1
	fi

	# Split the 4D file to a bunch of 3d images
	# fslsplit $input_func $tmp_dir/
	# all_timepoints=`ls $tmp_dir`
	# for timepoint in ${all_timepoints[@]}
	
	# Find out how many time points there are 
	num_trs=`fslnvols $input_func`
	num_trs=$((num_trs - 1)) # zero index
        echo Splitting ${num_trs} TRs

        merge_str=""

	for timepoint in $(seq 0 $num_trs) 
	do
		echo "Adding $timepoint"
		
		# First get that time slice 
		fslroi $input_func $tmp_dir/$timepoint $timepoint 1 

		# First run ANTs on that time point file 
		antsApplyTransforms -d 3 -i $tmp_dir/$timepoint.nii.gz -o $tmp_dir/${timepoint}_tmp.nii.gz -r $standard_vol -t $ants_dir/highres2infant_standard_1Warp.nii.gz -t $ants_dir/highres2infant_standard_0GenericAffine.mat
		
		# We can then use flirt to go back to 3mm space
		flirt -in  $tmp_dir/${timepoint}_tmp.nii.gz -ref ${adult_standard} -applyisoxfm 3 -init $ants_dir/infant_standard2standard.mat -o  $tmp_dir/${timepoint}_reg.nii.gz
		
                merge_str="${merge_str} $tmp_dir/${timepoint}_reg.nii.gz"

	done
	
        # Merge the time points (also print a string so that it is inspectable)
        echo fslmerge -t $output_func $merge_str
        fslmerge -t $output_func $merge_str

	# Remove the temp directory
	rm -rf $tmp_dir


else

	if [ $use_ants -eq 1 ]
	then
		# Quit if you failed to find the file
		echo "Couldn''t find ANTs directory, quitting"
		exit
	else
		echo "Using manual registration for alignment to standard"
		flirt -in $input_func -applyisoxfm 3 -init ${highres_reg_folder}/example_func2standard.mat -out $output_func -ref ${highres_reg_folder}/standard.nii.gz
	fi

fi

echo "Registered to standard: $output_func"



echo Finished
