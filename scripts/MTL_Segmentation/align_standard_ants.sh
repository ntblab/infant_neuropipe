#!/bin/bash
# Align segmentations to standard space using ANTs
#SBATCH --output=./logs/segmentations_alignment_ANTs-%j.out
#SBATCH -p day
#SBATCH -t 1:00:00
#SBATCH --mem 25G

SUBJ=$1 # What participant do you want to use
coder=$2 # What coder do you want to use?

cd subjects/${SUBJ}

echo "Working in $SUBJ for coder $coder"

source globals.sh

# Set up some file names
dimensionality=3

fsl_data=`which fsl`
fsl_data=${fsl_data%bin*}
fsl_data=$fsl_data/data/standard/

ants_dir=analysis/secondlevel/registration_ANTs/
standard_vol=`scripts/age_to_standard.sh`

output_prefix=$ants_dir/highres2infant_standard_
adult_standard=$fsl_data/MNI152_T1_1mm.nii.gz

# Where will this data go
out_dir=$PROJ_DIR/data/MTL_Segmentations/

# Get the input and output names, which depends on the coder
if [[ $coder == CE ]]
then
input_seg=`ls data/MTL_Segmentations/segmentations_anatomical/${SUBJ}*-CE.nii.gz`
out_name=${input_seg#*masks/}
else
input_seg=`ls ../../data/MTL_Segmentations/segmentations_anatomical/${SUBJ}*-JF.nii.gz`
out_name=${input_seg#*Segmentations_JF/}
fi

out_name=${out_name%.nii.gz}
out_seg=${out_dir}/${out_name}_standard.nii.gz

echo Outputting $out_seg

# Cycle through the codes, 
rm -f temp.nii.gz
for code in `seq 3 6`
do

echo Pulling out voxels labelled as $code

# Divide into specific code
fslmaths $input_seg -thr $code -uthr $code temp_${code}.nii.gz

# Do non-linear transform
antsApplyTransforms -d $dimensionality -i temp_${code}.nii.gz -o temp_${code}_aligned.nii.gz -r $standard_vol -t ${output_prefix}1Warp.nii.gz -t ${output_prefix}0GenericAffine.mat

# Threshold and set the values of the volume
thr=`echo $code / 2 | bc -l`
fslmaths temp_${code}_aligned.nii.gz -thr $thr -bin -mul $code temp_${code}_aligned.nii.gz

# Append to the volume
if [ -e temp.nii.gz ]
then
fslmerge -t temp.nii.gz temp.nii.gz temp_${code}_aligned.nii.gz
else
cp temp_${code}_aligned.nii.gz temp.nii.gz
fi

done

# Collapse across volumes and then fix the range
fslmaths temp.nii.gz -Tmean -mul 4 temp.nii.gz

# Align from infant standard to adult standard
flirt -in temp.nii.gz -ref $adult_standard -init $ants_dir/infant_standard2standard.mat -applyxfm -o $out_seg -interp nearestneighbour

echo Finished
