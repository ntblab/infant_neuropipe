#!/usr/bin/env bash
# Input python command to be submitted as a job
# Runs the inner loop of the searchlight 
#SBATCH --output=logs/human_searchlight-%j.out
#SBATCH --job-name searchlight
#SBATCH -p psych_day
#SBATCH -t 5:59:00       # time limit: how many minutes
#SBATCH --mem-per-cpu 25G        # memory limit
#SBATCH -n 5        # how many cores to use

# Set up the environment
module load Python/Anaconda3
module load brainiak/0.8-Python-Anaconda3
module load nilearn/0.5.0-Python-Anaconda3
module load OpenMPI/2.1.2-GCC-6.4.0-2.28

age=$1

# Run the python script
python scripts/MM_EventSeg/HumanBounds_Bootstrapping.py $age
