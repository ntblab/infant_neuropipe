#!/bin/bash
#
# Aggregate all of the FIR data for a given mask and data type
#
# Example command: 
# "sbatch ./scripts/run_Aggregate_FIR.sh V1_mask StatLearning 6"
# Which means use the V1_mask, take only FIR from StatLearning blocks and 6 means ignore any runs with fewer than 6 blocks in a run

#SBATCH --output=./logs/Aggregate_FIR-%j.out
#SBATCH -p short
#SBATCH -t 4:00:00
#SBATCH --mem 20000

# Set up the environment
source globals.sh

# Get all of the inputs
for input in "$@"
do	
	if [ ! -z "$input_str" ]
	then 
		input_str=`echo ${input_str}, "'${input}'"`
	else
		input_str="'${input}'"
	fi
done

# Add arguments to prep_raw_data only if you were given them
if [ "$#" -lt 1 ]
then
	matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('scripts/'); Aggregate_FIR;"
else
	matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('scripts/'); Aggregate_FIR($input_str);"
fi
