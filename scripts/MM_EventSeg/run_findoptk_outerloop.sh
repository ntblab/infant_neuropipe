#!/usr/bin/env bash
# Input python command to be submitted as a job

#SBATCH --output=logs/FindOptK-Outer-%j.out
#SBATCH -p day
#SBATCH -t 30:00
#SBATCH --mem 5G

# Load the modules
source globals.sh

#Script inputs
movie=$1
age=$2
roi=$3
max_num_events=$4
rel_sub=$5

python scripts/MM_EventSeg/FindOptK_Outer.py $movie $age $roi $max_num_events $rel_sub