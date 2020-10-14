#!/bin/bash
#
# Automate the analysis of Posner cuing
#
# This script first sets up all of the fsf files for analysis
# Then the script runs the feat analyses for Posner Cuing validity and side analyses
# Do the z scoring of the data
# Finally, wait and then do the alignment of the statistics to the highres and standard.
#
# Assumes you are running from the subject base directory
#
# C Ellis 070318 

#SBATCH --output=./logs/PosnerCuing_Supervisor-%j.out
#SBATCH -p short
#SBATCH -t 30
#SBATCH --mem 1000

# Source the globals
source ./globals.sh
	
# What is the root directory for the subject
subject_dir=$(pwd)

# What is the path to RepetitionNarrowing
PosnerCuing_path='analysis/secondlevel_PosnerCuing/default/'

# What is the nifti file being used
nifti_Z='NIFTI/func2highres_PosnerCuing_Z.nii.gz'

# Run the script to make saccade timing files
matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath scripts/PosnerCuing_analyses/; generate_saccade_timing_files; exit"

## Run the feats
TR_Number=`fslval ${PosnerCuing_path}${nifti_Z} dim4`
fsl_data=`which fsl`
fsl_data=${fsl_data%bin*}
fsl_data=$fsl_data/data/standard/

# Run the feat analysis for each condition
Conditions="Validity Saccades"
for Condition in $Conditions
do
	if [ ! -e ${PosnerCuing_path}/PosnerCuing_${Condition}.feat/stats/zstat1.nii.gz ]
	then
		echo Running $Condition
		rm -rf ${PosnerCuing_path}/PosnerCuing_${Condition}.feat/
	
		fsf_template=fsf/PosnerCuing_${Condition}.fsf.template
		fsf_output=${PosnerCuing_path}/PosnerCuing_${Condition}.fsf
		high_pass_cutoff=100 # Use a temporary value that you will overwrite
	
		#Replace the <> text (excludes the back slash just before the text) with the other supplied text

		# note: the following replacements put absolute paths into the fsf file. this
		#       is necessary because FEAT changes directories internally
		cat $fsf_template \
		| sed "s:<?= \$SUBJECT_PATH ?>:$subject_dir:g" \
		| sed "s:<?= \$STANDARD_DIR ?>:$fsl_data:g" \
		| sed "s:<?= \$TR_DURATION ?>:$TR:g" \
		| sed "s:<?= \$TR_NUMBER ?>:$TR_Number:g" \
		| sed "s:<?= \$HIGH_PASS_CUTOFF ?>:$high_pass_cutoff:g" \
			> ${subject_dir}/temp_PosnerCuing_${Condition}.fsf #Output to this file

		# Determine the high pass cut off and make the proper fsf file
		# Make the relevant design files
		feat_model ${subject_dir}/temp_PosnerCuing_${Condition}

		# Input the design matrix into the feat
		high_pass_cutoff=`cutoffcalc --tr=$TR -i ${subject_dir}/temp_PosnerCuing_${Condition}.mat`
		
		# If there is an issue with the calculation, only take the last word
		high_pass_cutoff=`echo $high_pass_cutoff | awk '{print $NF}'`

		cat $fsf_template \
		| sed "s:<?= \$SUBJECT_PATH ?>:$subject_dir:g" \
		| sed "s:<?= \$STANDARD_DIR ?>:$fsl_data:g" \
		| sed "s:<?= \$TR_DURATION ?>:$TR:g" \
		| sed "s:<?= \$TR_NUMBER ?>:$TR_Number:g" \
		| sed "s:<?= \$HIGH_PASS_CUTOFF ?>:$high_pass_cutoff:g" \
			> ${fsf_output} #Output to this file

		sbatch scripts/run_feat.sh $fsf_output	
                sleep 1m # Force a wait
	
		# Remove all the temp files associated with the design matrix
		rm -f temp_PosnerCuing_${Condition}.*
	fi
done

## Wait until FEATs have finished and then run the z scored versions

for Condition in $Conditions
do
	# Check if it is done
	waiting=1
	while [[ $waiting -eq 1 ]] 
	do 
		if  [[ -e ${subject_dir}/${PosnerCuing_path}/PosnerCuing_${Condition}.feat/stats/zstat1.nii.gz ]]
		then
			waiting=0
		else
			sleep 10s
		fi
	done	

	# Run the z scoring
	if [ ! -e ${PosnerCuing_path}/PosnerCuing_${Condition}_Z.feat/stats/zstat1.nii.gz ]
	then
		echo Running ${Condition}_Z

		rm -rf ${PosnerCuing_path}/PosnerCuing_${Condition}_Z.feat/
		sbatch --output=./logs/Feat_stats-%j.out ${subject_dir}/scripts/FEAT_stats.sh ${subject_dir}/${PosnerCuing_path}/PosnerCuing_${Condition}.feat ${subject_dir}/${PosnerCuing_path}/PosnerCuing_${Condition}_Z.feat ${subject_dir}/${PosnerCuing_path}/${nifti_Z}
		sleep 1m # Force a wait
	fi	
done

# Check if it is done
for Condition in $Conditions
do
	waiting=1
	while [[ $waiting -eq 1 ]]  
	do
		if  [[ -e ${subject_dir}/${PosnerCuing_path}/PosnerCuing_${Condition}_Z.feat/stats/zstat1.nii.gz ]]
		then
			waiting=0
		else
			sleep 10s
		fi	
	done
		
	## Now that all the analyses are done, make images out of the data
	feat_dir=${subject_dir}/${PosnerCuing_path}/PosnerCuing_${Condition}_Z.feat/
	
	zstat_file_num=`ls $feat_dir/stats/zstat?.nii.gz | wc -l`
	zstat_std_file_num=`ls $feat_dir/stats/zstat?_registered_standard.nii.gz | wc -l`
	
	if [ $zstat_file_num -ne $zstat_std_file_num ]
	then

		# Remove files that might have been created earlier by align_stats
		rm -f ${feat_dir}/stats/zstat?_*
		rm -f ${feat_dir}/stats/*png

		# Set the parameters
		zstat_files=`ls ${feat_dir}/stats/zstat*`
		zmin=2.3
		zmax=3

		echo Running align_stats for ${Condition}_Z

		# Iterate through the zstat maps that were created
		for stat_maps in $zstat_files
		do
			sbatch ${subject_dir}/scripts/align_stats.sh $stat_maps $zmin $zmax
		done

	fi
done
