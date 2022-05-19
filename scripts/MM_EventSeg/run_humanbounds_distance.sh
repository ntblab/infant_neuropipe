#!/usr/bin/env bash
# Input python command to be submitted as a job
# Runs the inner loop of the searchlight 
#SBATCH --output=logs/humanbounds_dist_searchlight-%j.out
#SBATCH --job-name searchlight
#SBATCH -p psych_day
#SBATCH -t 2:59:00       # time limit: how many minutes
#SBATCH --mem-per-cpu 10G        # memory limit
#SBATCH -n 1        # how many cores to use

# Set up the environment
source globals.sh

age=$1 # which age group?
sub=$2 # which subject?

# Run the python script
srun --mpi=pmi2 python scripts/MM_EventSeg/HumanBounds_Distance_Searchlight.py $age $sub 