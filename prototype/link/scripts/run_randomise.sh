#!/bin/bash
#
# Run an FSL randomise analysis with whatever inputs are specified
#
#SBATCH --output=./logs/randomise-%j.out
#SBATCH -p short
#SBATCH -t 360
#SBATCH --mem 5000

source globals.sh

# Get all of the inputs

for input in "$@"
do
	if [ ! -z "$input_str" ]
	then
		input_str=`echo ${input_str} ${input}`
	else
		input_str=${input}
	fi
done

# Run the command
echo randomise $input_str
randomise $input_str
