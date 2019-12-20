#!/bin/bash
#
# Run Analysis_DesignMotion.m

#SBATCH --output=./logs/Analysis_DesignMotion-%j.out
#SBATCH -p short
#SBATCH -t 4:00:00
#SBATCH --mem 20000

source globals.sh

matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('scripts/'); Analysis_DesignMotion;"
