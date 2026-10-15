#!/usr/bin/env bash
# Input python command to be submitted as a job
# Runs the inner loop of the searchlight 
#SBATCH --output=logs/searchlight-saycam-%j.out
#SBATCH --job-name searchlight
#SBATCH -p psych_day
#SBATCH -t 4:59:00       # time limit: how many minutes
#SBATCH --mem-per-cpu 25G        # memory limit
#SBATCH -n 5         # how many cores to use

# Load the modules
source globals.sh

ppt=$1
condition=$2

# Run the python script
srun --mpi=pmi2 python scripts/Saycam/Bootstrap_Searchlight_Visual.py $ppt $condition