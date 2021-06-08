#!/usr/bin/env bash
# Input python command to be submitted as a job

#SBATCH --output=logs/FindOptK-Outer-%j.out
#SBATCH -p day
#SBATCH -t 30:00
#SBATCH --mem 5G

module load Python/Anaconda3
module load brainiak/0.8-Python-Anaconda3
module load nilearn/0.5.0-Python-Anaconda3
module load OpenMPI/2.1.2-GCC-6.4.0-2.28

#Script inputs
movie=$1
age=$2
roi=$3
max_num_events=$4
rel_sub=$5

python scripts/MM_EventSeg/FindOptK_Outer.py $movie $age $roi $max_num_events $rel_sub