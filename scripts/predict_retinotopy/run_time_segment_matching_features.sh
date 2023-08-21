#!/bin/bash
#
# Script to launch time_segment_matching_features.py
#
# Example command:
# sbatch ./scripts/predict_retinotopy/run_time_segment_matching_features.sh s1607_1_4 10 1 occipital
#
#SBATCH -p psych_day
#SBATCH -n 1
#SBATCH -t 4:00:00
#SBATCH --mem-per-cpu 20G
#SBATCH --job-name TSM
#SBATCH --output logs/tsm-%J.txt

# Load the modules
source globals.sh

# What participant do you want to run this on?
ID=$1

#  How many features do you want to use in the SRM   
features=$2

# Are the infants participants being used as the reference (1) or the adults (0)?
is_infant_ref=$3

# What is the mask being used for this analysis (occipital and Wang are recognized).
mask_type=$4

# Run the python file
python ./scripts/predict_retinotopy/time_segment_matching_features.py $ID $features $is_infant_ref $mask_type
