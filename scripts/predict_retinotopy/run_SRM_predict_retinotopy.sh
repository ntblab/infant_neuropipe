#!/bin/bash
#
# Script to launch SRM_predict_retinotopy.py 
#
# Example command: 
# sbatch scripts/predict_retinotopy/run_SRM_predict_retinotopy.sh s1607_1_4 10 1 occipital 1
#
#SBATCH -p psych_day
#SBATCH -n 1
#SBATCH -t 120:00
#SBATCH --mem-per-cpu 20G
#SBATCH --job-name pred_ret
#SBATCH --output logs/predict_retinotopy-%J.txt

# Load the modules
source globals.sh

# What participant do you want to run this on?
ID=$1

#  How many features do you want to use in the SRM   
features=$2

# Do you want to use infants or adults as the reference for this
is_infant_ref=$3

# What mask do you want to use? Can be occipital or Wang
mask_type=$4

# Is this a control analysis?
is_control=$5

# Run the python file
python ./scripts/predict_retinotopy/SRM_predict_retinotopy.py $ID $features $is_infant_ref $mask_type $is_control
