#!/bin/bash
#
# Run the recon all script for freesurfer

#SBATCH --output=./logs/freesurfer-%j.out
#SBATCH -p long
#SBATCH -t 1-12
#SBATCH --mem 20000

source globals.sh
. /apps/hpc/Apps/FREESURFER/6.0.0/FreeSurferEnv.sh 

# Take in the inputs
anat_file=$1  # THe full path to the anatomical file being used for recon
output_root=$2  # What is the root name of the folder to be created
output_dir=$3  # Where is the data to be saved.

# Run the analysis
recon-all -i ${anat_file} -subjid ${output_root} -sd ${output_dir} -all -cw256
