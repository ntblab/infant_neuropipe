#!/usr/bin/env bash
# Input python command to be submitted as a job
# Runs the inner loop of the searchlight 
#SBATCH --output=searchlight-findoptk-%j.out
#SBATCH --job-name searchlight
#SBATCH -p week
#SBATCH -t 1-11:59:00       # time limit: how many minutes
#SBATCH --mem-per-cpu 25G        # memory limit
#SBATCH -n 20         # how many cores to use

# Load the modules
source globals.sh

movie=$1
age=$2
num=$3

# Run the python script
srun --mpi=pmi2 python scripts/MM_EventSeg/FindOptK_Searchlight.py $movie $age $num
