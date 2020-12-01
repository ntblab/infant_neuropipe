#!/bin/bash
#
# Flatten the cut patch generated from tksurfer for making a flatmap
# This takes in ?h.full.patch.3d and returns the flattened ?h.full.flat.patch.3d
#
#SBATCH --output=logs/flatten-%j.out
#SBATCH -p long
#SBATCH -t 36:00:00
#SBATCH --mem 20000

source globals.sh

SUBJECTS_DIR=analysis/freesurfer/; 
export SUBJECTS_DIR;

# Take in the inputs
hemisphere=$1  # What is the hemisphere(e.g. lh)
recon_folder=$2  # What recon folder do you use

cd $SUBJECTS_DIR/${recon_folder}/surf/

input_patch=${hemisphere}.full.patch.3d
output_patch=${hemisphere}.full.flat.patch.3d

iteration_number=1000

# Run the analysis
mris_flatten -w $iteration_number $input_patch $output_patch
