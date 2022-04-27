#!/usr/bin/env bash
# Input python command to be submitted as a job
# Runs the inner loop of the searchlight 
#SBATCH --output=logs/bootstrapping-%j.out
#SBATCH --job-name bootstrap
#SBATCH -p psych_day
#SBATCH -t 5:59:00       # time limit: how many minutes
#SBATCH --mem-per-cpu 25G        # memory limit

# Load the modules
source globals.sh

age=$1
analysis_type=$2

# Run the python script
python scripts/MM_EventSeg/HumanBounds_Bootstrapping.py $age $analysis_type
