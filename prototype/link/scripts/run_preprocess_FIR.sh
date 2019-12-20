#!/bin/bash
#
# Run preprocess_FIR.m

#SBATCH --output=./logs/preprocess_FIR-%j.out
#SBATCH -p short
#SBATCH -t 4:00:00
#SBATCH --mem 20000

source globals.sh

matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('scripts/'); preprocess_FIR;"
