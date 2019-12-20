#!/bin/bash
#
# Create an ROI from an atlas 
#
# It is strongly encouraged that the resultant mask has the name of the original data it originates from

# Take the inputs
atlas=$1  # Full path to the probability map of the volumes 
atlas_idx=$2  # Takes this 'TR' and thresholds it
output_name=$3  # Where is the data saved. It is recommended to save the data in an ROI folder of the atlas directory

# Get globals
source globals.sh

# Take the ROI of this atlas
fslroi $atlas $output_name $atlas_idx 1

# Binarize the volume to ensure it is just zeros and ones
fslmaths $output_name -bin $output_name
