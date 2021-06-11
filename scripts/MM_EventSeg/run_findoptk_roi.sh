#!/usr/bin/env bash
# Input python command to be submitted as a job

#SBATCH --output=logs/FindOptK-ROI-%j.out
#SBATCH -p day
#SBATCH -t 30:00
#SBATCH --mem 15G

# Load the modules
source globals.sh

#Script inputs
movie=$1
age=$2
roi=$3
num_events=$4
leftout=$5 # if undefined, all subjects will be used


python scripts/MM_EventSeg/FindOptK_ROI.py $movie $age $roi $num_events $leftout