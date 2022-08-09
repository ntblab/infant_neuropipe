#!/usr/bin/env bash
# Input python command to be submitted as a job
# Runs the inner loop of the searchlight 
#SBATCH --output=logs/human_searchlight-%j.out
#SBATCH --job-name searchlight
#SBATCH -p day
#SBATCH -t 5:59:00       # time limit: how many minutes
#SBATCH --mem-per-cpu 25G        # memory limit
#SBATCH -n 5        # how many cores to use

# Set up the environment
source globals.sh

age=$1
sub=$2

# Run the python script
srun --mpi=pmi2 python scripts/MM_EventSeg/HumanBounds_Searchlight.py $age $sub 