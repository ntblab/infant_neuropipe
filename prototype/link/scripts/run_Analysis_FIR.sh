#!/bin/bash
#
# Run Analysis_FIR.m

#SBATCH --output=./logs/Analysis_FIR-%j.out
#SBATCH -p short
#SBATCH -t 4:00:00
#SBATCH --mem 30000

source globals.sh

masktype="'${1}'"
functional_run="'${2}'"

matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('scripts/'); Analysis_FIR($masktype, $functional_run);"
