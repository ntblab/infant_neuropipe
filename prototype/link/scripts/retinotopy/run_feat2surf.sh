#!/bin/bash
#
# Run the feat2surf script for freesurfer

#SBATCH --output=logs/feat2surf-%j.out
#SBATCH -p short
#SBATCH -t 1:00:00
#SBATCH --mem 100G

source globals.sh

SUBJECTS_DIR=analysis/freesurfer/; 
export SUBJECTS_DIR;

# Take in the inputs
featDir=$1  # Where is the feat folder

# Run the analysis
feat2surf --feat ${featDir}
