#!/bin/bash
#
# Run the reg-feat2anat script for freesurfer
#
#SBATCH --output=logs/reg-feat2anat-%j.out
#SBATCH -p short
#SBATCH -t 1:00:00
#SBATCH --mem 20000

source globals.sh

SUBJECTS_DIR=analysis/freesurfer/; 
export SUBJECTS_DIR;

# Take in the inputs
featDir=$1  # Where is the feat folder
FreesurferFolder=$2  # What recon folder do you use

# Run the analysis
reg-feat2anat --feat ${featDir} --subject ${FreesurferFolder}
