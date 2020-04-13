#!/bin/bash
#
# Explore the preprocessing parameters for analysis
#
#SBATCH --output=./logs/prep_raw_data_explore-%j.out
#SBATCH -p short
#SBATCH -t 5:00:00
#SBATCH --mem 20000

source globals.sh

# Pull the functional data
functional_run=$1
# Second input can be anything and it will run the default analyses only

# Preset
jid=0

# If this is a pseudorun of data then specify the repo to be used for finding the file
functional_run_number=${functional_run#functional}
if [[ ${#functional_run_number} -gt 2 ]]
then
	pseudorun_data="data_dir analysis/firstlevel/pseudorun/"
	functional_run_number=1:100
else
	pseudorun_data=''
fi

# If there is a match to a string in the run burn in then specify that number here
Burn_in_TRs=3 # Default number
if [ -e analysis/firstlevel/run_burn_in.txt ]
then
	burn_in_txt=`cat analysis/firstlevel/run_burn_in.txt`
	next_word=0
	for word in $burn_in_txt
	do	

		# If this word was marked as the burn in word
		if [[ $next_word -eq 1 ]]
		then
			next_word=0
			Burn_in_TRs=$word
		fi
		
		# Is this word for a burn in
		if [[ $word == $functional_run ]]
		then
			next_word=1
		fi
	done
fi

# Set the parameters to be explored
PCA_Thresholds="0" # Can accept a p value or the string IQR
fslmotion_thresholds="0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0 3.2 3.4 3.6 3.8 4.0 4.2 4.4 4.6 4.8 5.0 99 6 9 12"


# Run the preprocessing so that you have the appropriate files, use different PCA thresholds
for PCA_Threshold in $PCA_Thresholds
do
	for fslmotion_threshold in $fslmotion_thresholds
	do	

		# Check if these parameters have already been generated
		file=analysis/firstlevel/Confounds/example_func_functional${functional_run}_TR_*_mahal_threshold_${PCA_Threshold}_fslmotion_threshold_${fslmotion_threshold}.nii.gz
		if [ ! -e $file ]
		then
			if [ $jid == 0 ]
			then
				hold_text=''
			else
				hold_text="--dependency=afterok:${jid} "
			fi
		
			echo Creating $file

			#These analyses bump into one another so wait for the other to be finished
			if [[ ${SCHEDULER} == slurm ]]
			then
				SubmitName=`sbatch ${hold_text}./scripts/run_prep_raw_data.sh [7] ${functional_run_number} $Burn_in_TRs mahal_threshold $PCA_Threshold fslmotion_threshold $fslmotion_threshold $pseudorun_data`
			else
				SubmitName=`submit -hold_jid ${jid} scripts/prep_raw_data.m [7] ${functional_run_number} $Burn_in_TRs mahal_threshold $PCA_Threshold fslmotion_threshold $fslmotion_threshold $pseudorun_data`
			fi
			jid=`echo $SubmitName | awk '{print $NF}'`
		else
			echo $file has been created, skipping
		fi
	done
done
