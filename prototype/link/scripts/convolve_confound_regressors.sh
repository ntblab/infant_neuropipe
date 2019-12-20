#!/bin/bash
#
# Create the confound regressors for any confound file with the name
# Epochs (motion and eye data exclusions). This first pulls out the
# timing files for these events, then convolves it with the HRF. These
# new regressors are then appended to the end of the newly recreated
# OverallConfounds file. Finally these regressors are decorrelated.

func_run=$1
ConfoundPath=$2

source globals.sh

epoch_files=(${ConfoundPath}/*Epochs_functional${func_run}.txt)
for epoch_file in "${epoch_files[@]}"
do	
	if [ -e ${epoch_file} ]; then
	
		# Create the timing file
		regressor_file=`echo ${epoch_file} | rev | cut -c 5- | rev`
		regressor_file=${regressor_file}.mat
		./scripts/convolve_timing_file.sh ${ConfoundPath}/Epochs_design.fsf $epoch_file $regressor_file
	
		# Trim the number of time points (since it is over estimated)
		trs=`cat ${ConfoundPath}/OverallConfounds_functional${func_run}_original.txt | wc -l` # How many lines in the overall confounds file
	
		# Take the first $regressor_file lines of the file
		head -$trs $regressor_file > temp
		yes | mv temp $regressor_file
	fi
done

# Combine the regressors with motion parameters and confounds
# Assign names
OverallFile=${ConfoundPath}/OverallConfounds_functional${func_run}_original.txt	
regressor_files=(${ConfoundPath}/*Epochs_functional${func_run}.mat)

# Recreate the original overall confound file, in order to prevent these changes accumulating
rm -f $OverallFile
echo "Rewriting the confound file"
if [ -e ${ConfoundPath}/MotionConfounds_functional${func_run}.txt ]; then
	paste -d' ' ${ConfoundPath}/MotionParameters_functional${func_run}.par ${ConfoundPath}/MotionConfounds_functional${func_run}.txt > $OverallFile
else
	paste -d' ' ${ConfoundPath}/MotionParameters_functional${func_run}.par > $OverallFile
fi

# Add the confound regressors to the overall confound file
if [ -e ${epoch_file} ]; then

	# Iterate through the regression files
	rm -f temp.txt # This temp file can't exist
	for regressor_file in "${regressor_files[@]}"
	do	
		# If this file exists then append it onto the Overall confound file
		if [ -e ${regressor_file} ]; then

			paste -d' ' $OverallFile $regressor_file > temp.txt
			yes | mv temp.txt $OverallFile
		fi
	done
fi

# Re run decorrelator
if [[ ${SCHEDULER} == slurm ]]
then
	matlab -nodisplay -nodesktop -jvm -r "addpath('scripts'); motion_decorrelator('$OverallFile','${ConfoundPath}/OverallConfounds_functional${func_run}.txt'); exit;"
elif [[ ${SCHEDULER} == qsub ]]
then
	submit ./scripts/motion_decorrelator.m $OverallFile ${ConfoundPath}/OverallConfounds_functional${func_run}.txt
fi

