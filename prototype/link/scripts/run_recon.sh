#!/bin/bash
#
# Run a recon-all analysis with whatever inputs are specified
#
#SBATCH --output=./logs/recon-%j.out
#SBATCH -p verylong
#SBATCH -t 5-12
#SBATCH --mem 20000

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
echo recon-all $input_str
recon-all $input_str
