#!/usr/bin/env bash
# Input python command to be submitted as a job
#
# Example command to run across layers with no PCA, yes RSA output, convolved HRF, 24 fps, and no trimming of border
# for layer in b1p b2p b3p b4p b5p fc1 fc2; do echo sbatch scripts/CartoonLive/run_analyse_VGG_weights.sh data/CartoonLive/vgg_raw_weights/LionKing_Cartoon_vgg_${layer}.npy 2 data/CartoonLive/vgg_outputs/LionKing_Cartoon_vgg_${layer}.npy 0 1 1 24 0; done

#SBATCH --output=logs/analyse_vgg_weights-%j.out
#SBATCH -p psych_day
#SBATCH -t 60
#SBATCH --mem 80000

# Set up the environment
source globals.sh

regressor_file=$1 # What is the path to the regressor file 
tr_duration=$2 # What is the TR duration (2)
output_name=$3 # What is the name of the file you want to save the data
pca_components=$4 # Do you want to downsample with PCA and store the component weights over time? If so, set this to above zero to specify the weights (0 = no PCA)
output_rsa=$5 # Do you want to output an RSA matrix or a regression for the vgg layers? (1 = RSA)
convolve_regressor=$6 # Do you want to convolve the unit activity with the HRF (1 = yes,0 = average within the windows)
fps=$7 # What is the frame rate (24 fps)
trim_prct=$8 # How much of the filters borders do you want to zero out so that it doesn't contribute (mentioned in the supplement for Long et al 2019) (0 = no border)

# Run the script
python scripts/CNN_analyses/analyse_VGG_weights.py $regressor_file $tr_duration $output_name $pca_components $output_rsa $convolve_regressor $fps $trim_prct

