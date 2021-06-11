#!/usr/bin/env bash
# Input python command to be submitted as a job

#SBATCH --output=logs/Events_Across_Group-%j.out
#SBATCH -p day
#SBATCH -t 3:59:00
#SBATCH --mem 5G

# Load the modules
source globals.sh

#Script inputs
movie=$1
train_age=$2
test_age=$3

python scripts/MM_EventSeg/Across_Groups_Analysis.py $movie $train_age $test_age