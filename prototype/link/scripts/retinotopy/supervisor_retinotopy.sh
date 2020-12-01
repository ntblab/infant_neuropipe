#!/bin/bash
#
# Automate the analysis of retinotopy with the block design of SF and meridian mapping
# Assumes you are running from the subject base directory
# 
# Create the FSF file for running the analyses
# Run the feats
# Run the script for eccentricity mapping in retinotopy sf
# Map the outputs into the volume space for surface mapping so that they are ready for SUMA
#
# Example command:
# sbatch ./scripts/retinotopy/supervisor_retinotopy.sh default
#
# C Ellis 082019. 
#
#SBATCH --output=logs/Retinotopy_Supervisor-%j.out
#SBATCH -p short
#SBATCH -t 360
#SBATCH --mem 16000

# Set up the environment

source globals.sh
SUBJECTS_DIR=analysis/freesurfer/; export SUBJECTS_DIR;

if [ $# -ge 1 ]
then
	echo Using $1 folder
	retinotopy_condition=$1
else
	echo Using default folder
	retinotopy_condition=default
fi


# What is the root directory for the subject
subject_dir=$(pwd)

## Do the second level analysis

# What is the path to the experiment folder
experiment_path=${subject_dir}/analysis/secondlevel_Retinotopy/${retinotopy_condition}/

# What is the nifti file being used
nifti='NIFTI/func2highres_Retinotopy_Z.nii.gz'

## Run the feats

TR_Duration=`fslval ${experiment_path}${nifti} pixdim4`
TR_Number=`fslval ${experiment_path}${nifti} dim4`

#Is the TR duration in seconds or milliseconds?
inSeconds=`echo $TR_Duration '<' 100 | bc -l`
if [ $inSeconds -eq 0 ]
then
	#Divide this number by 1000 to get it in seconds, remove some of the decimal places
	TR_Duration=`echo "$TR_Duration / 1000" | bc -l`
fi
TR_Duration=${TR_Duration:0:4}

# Make the task timing file
cat ${experiment_path}/Timing/Retinotopy-*Only.txt > ${experiment_path}/Timing/Retinotopy-Task.txt
#cat ${experiment_path}/Timing/Retinotopy-*Events.txt > ${experiment_path}/Timing/Retinotopy-Task.txt

# Cycle through the analysis types, making the fsf files and submitting the jobs
analysis_types="sf meridian both"

for analysis_type in $analysis_types
do

	# Does this already exist?
	if [ ! -e ${experiment_path}/Retinotopy_${analysis_type}.feat/stats/zstat1.nii.gz ]
	then
		rm -rf ${experiment_path}/Retinotopy_${analysis_type}.feat/

		fsf_template=fsf/retinotopy_${analysis_type}.fsf.template
		fsf_output=${experiment_path}/retinotopy_${analysis_type}.fsf
		high_pass_cutoff=100 # Preset the number
		horizontal_file=Retinotopy-Condition_horizontal  # Must end in txt
		vertical_file=Retinotopy-Condition_vertical  # Must end in txt
		high_file=Retinotopy-Condition_high  # Must end in txt
		low_file=Retinotopy-Condition_low  # Must end in txt
		task_file=Retinotopy-Task  # Must end in txt

		#Replace the <> text (excludes the back slash just before the text) with the other supplied text

		# note: the following replacements put absolute paths into the fsf file. this
		#       is necessary because FEAT changes directories internally
		cat $fsf_template \
		| sed "s:<?= \$SUBJECT_PATH ?>:$experiment_path:g" \
		| sed "s:<?= \$TR_NUMBER ?>:$TR_Number:g" \
		| sed "s:<?= \$TR_DURATION ?>:$TR_Duration:g" \
		| sed "s:<?= \$HORIZONTAL_FILE ?>:$horizontal_file:g" \
		| sed "s:<?= \$VERTICAL_FILE ?>:$vertical_file:g" \
		| sed "s:<?= \$HIGH_FILE ?>:$high_file:g" \
		| sed "s:<?= \$LOW_FILE ?>:$low_file:g" \
		| sed "s:<?= \$TASK_FILE ?>:$task_file:g" \
		| sed "s:<?= \$HIGH_PASS_CUTOFF ?>:$high_pass_cutoff:g" \
			> ${subject_dir}/temp_retinotopy.fsf #Output to this file

		# Determine the high pass cut off and make the proper fsf file
		# Make the relevant design files
		feat_model ${subject_dir}/temp_retinotopy

		# Input the design matrix into the feat
		high_pass_cutoff=`cutoffcalc --tr=$TR_Duration -i ${subject_dir}/temp_retinotopy.mat`

		cat $fsf_template \
		| sed "s:<?= \$SUBJECT_PATH ?>:$experiment_path:g" \
		| sed "s:<?= \$TR_NUMBER ?>:$TR_Number:g" \
		| sed "s:<?= \$TR_DURATION ?>:$TR_Duration:g" \
		| sed "s:<?= \$HORIZONTAL_FILE ?>:$horizontal_file:g" \
		| sed "s:<?= \$VERTICAL_FILE ?>:$vertical_file:g" \
		| sed "s:<?= \$HIGH_FILE ?>:$high_file:g" \
		| sed "s:<?= \$LOW_FILE ?>:$low_file:g" \
		| sed "s:<?= \$TASK_FILE ?>:$task_file:g" \
		| sed "s:<?= \$HIGH_PASS_CUTOFF ?>:$high_pass_cutoff:g" \
			> ${fsf_output} #Output to this file

		# Run the feat
		echo Running $fsf_output
		sbatch scripts/run_feat.sh $fsf_output	

		# Remove all the temp files associated with the design matrix
		rm -f temp_retinotopy.*
	fi	

done

## Make the z scored version of the above analysis 

# Wait for the phase job to finish

for analysis_type in $analysis_types
do

	while [ ! -e ${experiment_path}/Retinotopy_${analysis_type}.feat/stats/zstat1.nii.gz ]
	do
		sleep 30s
	done
	

	if [ ! -e ${experiment_path}/Retinotopy_${analysis_type}_Z.feat/stats/zstat1.nii.gz ]
	then
		# Run the Z stat version
		sbatch --output=logs/feat_stats-%j.out ./scripts/FEAT_stats.sh ${experiment_path}/Retinotopy_${analysis_type}.feat ${experiment_path}/Retinotopy_${analysis_type}_Z.feat ${experiment_path}/NIFTI/func2highres_Retinotopy_Z.nii.gz
		echo "Making Z stat for ${analysis_type}"
	fi

done

while [ ! -e ${experiment_path}/Retinotopy_${analysis_type}_Z.feat/stats/zstat1.nii.gz ]
do
	sleep 30s
done

# Make the zstat maps
for analysis_type in $analysis_types
do
	
	# Get all the zstats
	
	zstats=`ls ${experiment_path}/Retinotopy_${analysis_type}_Z.feat/stats/zstat*.nii.gz ${experiment_path}/Retinotopy_${analysis_type}_Z.feat/stats/zfstat*.nii.gz ${experiment_path}/Retinotopy_${analysis_type}_Z.feat/stats/fstat*.nii.gz`
	
	# Cycle through the z stats
	for file in $zstats
	do	

		if [[ ! -e ${file::-7}_registered_standard.nii.gz ]]
		then
			if [[ ${file##*/} != *"_"* ]]
			then
				echo Aligning $file
				sbatch scripts/align_stats.sh $file 1.9 8
			fi
		else
			echo Found ${file::-7}_registered_standard.nii.gz, skipping
		fi
	done
	
done

## Perform ICA on the retinotopy data

# For Retinotopy only data
if [ ! -e ${experiment_path}/func2highres_Retinotopy_Z.ica ]
then
	melodic -i ${experiment_path}/NIFTI/func2highres_Retinotopy_Z.nii.gz -o ${experiment_path}/func2highres_Retinotopy_Z.ica -v --nobet --bgthreshold=1 --tr=2 -d 0 --mmthresh=0.5 --report --guireport=${experiment_path}/func2highres_Retinotopy_Z.ica/report.html
else
	echo Skipping ICA
fi

echo Finished

exit
