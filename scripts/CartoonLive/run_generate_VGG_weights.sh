#!/usr/bin/env bash
# Input python command to be submitted as a job
#
# Example command with 2 TR length using max pooling outputs of VGG-19
# sbatch scripts/CartoonLive/run_generate_VGG_weights.sh LionKing_Cartoon.mp4 2 data/CartoonLive/vgg_raw_weights/ 1 1
#
#SBATCH --output=logs/generate_vgg_weights-%j.out
#SBATCH -p psych_day
#SBATCH -t 300
#SBATCH --mem 200000

# Set up environment 
module load Python/Anaconda3
source activate keras

input_data=$1  # Load in the movie (.mp4 file)
tr_duration=$2 # How long is the TR (2)
output_dir=$3 # Where is this data going
is_max_pooling=$4 # Are you making the max pooling version (1)
is_vgg19=$5 # Are you running VGG19 or inceptionV3 (1)
regressor_seed=$6 # What is the seed you wish to use for the random weights (if you don't want random weights then specify nothing here

# Generate the weights
python scripts/CNN_analyses/generate_VGG_weights.py $input_data $tr_duration $output_dir $is_max_pooling $is_vgg19 $regressor_seed

