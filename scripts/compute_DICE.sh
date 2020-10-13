#!/bin/bash
#
# Compute the DICE similarity for two volumes. If a single number is provided as a third argument it will only consider that subfield for computing the similarity. If you provide a number as a fourth argument then the third and fourth arguments will be used as a range of values to consider.
# Example command:
# ./scripts/compute_DICE.sh group/MTL_practice/sub-02_t2_avg_brain-CE.nii.gz group/MTL_practice/sub-02_t2_avg_brain-BS.nii.gz 2

# Get the inputs
vol_1=$1
vol_2=$2

# Is there one label that you want to consider and ignore the rest?
if [ "$#" -lt 3 ]
then
lower_thr=1
upper_thr=100000 # Just pick a large number
else
if [ "$#" -eq 3 ]
then
lower_thr=$3
upper_thr=$3
else
lower_thr=$3
upper_thr=$4
fi
fi

# Create file names
vol_1_mask=vol_mask_1_$RANDOM.nii.gz
vol_2_mask=vol_mask_2_$RANDOM.nii.gz
match_vol=match_vol_$RANDOM.nii.gz

# Find only the labelled voxels
fslmaths $vol_1 -thr $lower_thr -uthr $upper_thr -bin $vol_1_mask
fslmaths $vol_2 -thr $lower_thr -uthr $upper_thr -bin $vol_2_mask

# Find the difference between the two volumes, make it into an absolute value, then turn all values negative and add 1, making everything that was equal in the two volumes have a value of 1 and everything else is zero or below. Threshold then binarize, then multiply by the voxels that are included for this participant and then you have the matches
fslmaths $vol_1 -sub $vol_2 -abs -mul -1 -add 1 -thr 1 -bin -mul $vol_1_mask $match_vol

# Take the average of the matches. In each volume you have the same number of voxels, hence the denominator can be ignored
matches_count=`fslstats $match_vol -m`
vol_1_count=`fslstats $vol_1_mask -m`
vol_2_count=`fslstats $vol_2_mask -m`

# Double it to account for the fact that you are considering both codings
matches_count=`echo "$matches_count*2" | bc`

# Compute dice with 3 DF
DICE=`echo "scale=3; $matches_count/($vol_1_count+$vol_2_count)" | bc`

echo "DICE similarity between is $DICE"

# Delete the temp files you made
rm $vol_1_mask $vol_2_mask $match_vol
