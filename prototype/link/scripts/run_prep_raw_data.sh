#!/bin/bash
#
# Run the prep raw data script in matlab
#
#SBATCH --output=./logs/prep_raw_data-%j.out
#SBATCH -p short
#SBATCH -t 4:00:00
#SBATCH --mem 20000

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
	matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('scripts/'); prep_raw_data; exit;"
else
	matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('scripts/'); prep_raw_data($input_str); exit;"
fi
