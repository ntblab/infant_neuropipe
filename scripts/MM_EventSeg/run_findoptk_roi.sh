#!/usr/bin/env bash
# Input python command to be submitted as a job

#SBATCH --output=logs/FindOptK-ROI-%j.out
#SBATCH -p day
#SBATCH -t 30:00
#SBATCH --mem 15G

module load Python/Anaconda3
module load brainiak/0.8-Python-Anaconda3
module load nilearn/0.5.0-Python-Anaconda3
module load OpenMPI/2.1.2-GCC-6.4.0-2.28

#Script inputs
movie=$1
age=$2
roi=$3
num_events=$4
leftout=$5 # if undefined, all subjects will be used


python scripts/MM_EventSeg/FindOptK_ROI.py $movie $age $roi $num_events $leftout