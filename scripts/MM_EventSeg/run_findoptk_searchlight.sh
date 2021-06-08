#!/usr/bin/env bash
# Input python command to be submitted as a job
# Runs the inner loop of the searchlight 
#SBATCH --output=searchlight-findoptk-%j.out
#SBATCH --job-name searchlight
#SBATCH -p week
#SBATCH -t 1-11:59:00       # time limit: how many minutes
#SBATCH --mem-per-cpu 25G        # memory limit
#SBATCH -n 20         # how many cores to use

# Set up the environment
module load Python/Anaconda3
module load brainiak/0.8-Python-Anaconda3
module load nilearn/0.5.0-Python-Anaconda3
module load OpenMPI/2.1.2-GCC-6.4.0-2.28

movie=$1
age=$2
num=$3

# Run the python script
srun --mpi=pmi2 python scripts/MM_EventSeg/FindOptK_Searchlight.py $movie $age $num
