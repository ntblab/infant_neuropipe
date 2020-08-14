#!/usr/bin/env bash
# Run randomise with the stat learning data. Run command from infant_neuropipe base directory. This will align the data to standard if that hasn't been done already
#
# An example command is: sbatch scripts/StatLearning/run_randomise.sh zstat3 seen_count
#
#SBATCH --output=logs/randomise-%j.out
#SBATCH -p short
#SBATCH -t 350
#SBATCH --mem 20G

# Setup the environment.
source ./globals.sh

contrast_name=$1 # For instance "1". If -1 then assumes this is a multivariate analysis
secondlevelname=$2 # For instance "seen_count"

# Assume data directory is where it should be
data_dir=data/StatLearning/

# Get the standard brain to be aligned to
fsl_dir=`which fsl`
fsl_dir=${fsl_dir%bin/fsl}
standard_vol=${fsl_dir}/data/standard/MNI152_T1_1mm_brain.nii.gz

# Do you want to add variance smoothing, if so make it here (5 is a default for N<20)
variance_smoothing="" # " -v 5"

# Specify the output root names
merged_file=${data_dir}/randomise_maps-${secondlevelname}/${contrast_name}_merged.nii.gz
randomise_file=${data_dir}/randomise_maps-${secondlevelname}/${contrast_name}
mask_file=${data_dir}/mask_${secondlevelname}.nii.gz

# Cycle through the fnames and check if the highres to standard file exists
highres_fnames=`ls ${data_dir}/contrast_maps-${secondlevelname}/*_${contrast_name}.nii.gz`
for fname in $highres_fnames
do

session_id=${fname#*seen_count/}
session_id=${session_id%_zstat*}

# How to transform from highres to standard
transformation_mat=${data_dir}/transformation_mats/${session_id}_standard.mat

# What is the output name
output=${data_dir}/contrast_maps-${secondlevelname}/${session_id}_${contrast_name}_standard.nii.gz

# Check the output doesn't exist
if [ ! -e $output ] 
then

echo Making $output
flirt -in $fname -ref $standard_vol -init $transformation_mat -applyxfm -o $output

fi

done

fnames=`ls ${data_dir}/contrast_maps-${secondlevelname}/*_${contrast_name}_standard.nii.gz`

# Remove in case it exists
rm -f $merged_file

echo Making $merged_file
echo Outputing $randomise_file
echo Using $mask_file

# Merge the participant data
fslmerge -t $merged_file $fnames

# Create the mask if it doesn't exist
if [ ! -e $mask_file ]
then
        fslmaths $merged_file -abs -bin -Tmean -thr 1 $mask_file
fi

# Mask the merged file again so that all of the background values are zero
fslmaths $merged_file -mas $mask_file $merged_file

# Run randomise 
echo randomise -i $merged_file -o $randomise_file -1 -n 1000 -x -T -t scripts/StatLearning/contrast.con $variance_smoothing

echo Finished
