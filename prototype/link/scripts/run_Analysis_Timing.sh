#!/bin/bash
#
# Run the prep raw data script in matlab
#
#SBATCH --output=./logs/Analysis_Timing-%j.out
#SBATCH -p short
#SBATCH -t 4:00:00
#SBATCH --mem 20000

source globals.sh

matlab -nodesktop -nosplash -jvm -r "addpath('scripts/'); Analysis_Timing;"
