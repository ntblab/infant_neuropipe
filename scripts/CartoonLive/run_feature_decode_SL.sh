#!/usr/bin/env bash
# Input python command to be submitted as a job
# Runs the inner loop of the searchlight 
#SBATCH --output=logs/mvpa_decode_-%j.out
#SBATCH --job-name decode_searchlight
#SBATCH -p psych_day
#SBATCH -t 3:59:00       # time limit: how many minutes
#SBATCH --mem-per-cpu 15G        # memory limit
#SBATCH -n 5        # how many cores to use

# Set up the environment
#source globals.sh
module load miniconda
conda activate /gpfs/milgram/project/turk-browne/users/${USER}/conda_envs/dev_brainiak

# take in the inputs
age=$1 # what age? adults or infants 
test_ppt=$2 # which participant as the test subject?
movie=$3 # which movie ?? (Cartoon or Live)
feature=$4 # which feature? 

# Run the python script
srun --mpi=pmi2 python scripts/CartoonLive/Feature_Decoding_Searchlight.py $age $test_ppt $movie $feature