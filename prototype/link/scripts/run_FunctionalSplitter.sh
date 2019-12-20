#!/bin/bash
#
# Run the FunctionalSplitter script in matlab

#SBATCH --output=./logs/functional_splitter-%j.out
#SBATCH -p short
#SBATCH -t 1:00:00
#SBATCH --mem 25G

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
	matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('scripts/'); FunctionalSplitter;"
else
	matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('scripts/'); FunctionalSplitter($input_str);"
fi
