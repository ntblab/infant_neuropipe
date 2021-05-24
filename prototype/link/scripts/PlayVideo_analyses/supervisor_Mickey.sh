#!/bin/bash
#
# Automate the analysis of PlayVideo 
# Assumes you are running from the subject base directory

# Step 1: Z-score data while ignoring NaNs (already done in earlier preprocessing)
# Step 2: Align the participant data to adult standard 
# Step 3: Extend the data if there are TRs missing at the end
# Step 4: figure out which TRs they had their eyes closed for 
# Transfers all of these files to the group folder
#
# Reworked so everything can be run in participant folder TY 052021
#
#SBATCH --output=./logs/supervisor_Mickey-%j.out
#SBATCH -p day
#SBATCH -t 1:00:00
#SBATCH --mem 16000

if [ $# -eq 0 ]
then
    analysis_type='default'
else
    analysis_type=$1
fi

preprocessing_type='linear_alignment' # could also be "nonlinear"

source globals.sh

# What is the name of movie you care about?
movie='PlayVideo_'
movie_out_name='Mickey_DONT_SHARE' # Mickey, temporarily named so we don't overwrite files 
nTRs=148 # two viewings


# Make the data directory
group_dir=$PROJ_DIR/data/Movies/${movie_out_name}/
mkdir -p $group_dir/preprocessed_native/$preprocessing_type/
mkdir -p $group_dir/preprocessed_standard/$preprocessing_type/
mkdir -p $group_dir/motion_confounds/
mkdir -p $group_dir/eye_confounds/

# What are the appropriate paths
subject_dir=$(pwd)
PlayVideo_path=${subject_dir}/analysis/secondlevel_PlayVideo/${analysis_type}/

# Get the nifti file 
nifti=${PlayVideo_path}/NIFTI/func2highres_PlayVideo_Z.nii.gz

#nifti_str="'${nifti}'"

# output file name
file_name=${SUBJ}_Z.nii.gz

#zscored_str="'${MM_path}/NIFTI/${file_name}'"

###### Step 1 - zscore while excluding NaNs

# find the motion confounds
MotionConfounds="${PlayVideo_path}/Confounds/MotionConfounds.txt"
 
# Which TRs are excluded?
ExcludedTRs=(`grep -n 1 $MotionConfounds | cut -d: -f1`)
exclusions="[${ExcludedTRs[@]}]"

echo $exclusions
echo "TRs are being excluded for Play Video using zscore_exclude"

# skip running the step, this was already technically run   
# matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('scripts/'); z_score_exclude($nifti_str, $zscored_str, $exclusions);"
cp ${nifti} ${PlayVideo_path}/NIFTI/${file_name}

# Copy the motion confounds
cp ${PlayVideo_path}/Confounds/MotionConfounds.txt $group_dir/motion_confounds/${SUBJ}.txt

# Copy over the z-scored nifti
cp ${PlayVideo_path}/NIFTI/${file_name} $group_dir/preprocessed_native/$preprocessing_type/

###### Step 2 align the data

input_func=$group_dir/preprocessed_native/$preprocessing_type/${file_name}
output_std=$group_dir/preprocessed_standard/$preprocessing_type/${file_name}
transformation_matrix=${subject_dir}/analysis/secondlevel/registration.feat/reg/example_func2standard.mat
standard=${subject_dir}/analysis/secondlevel/registration.feat/reg/standard.nii.gz

if [ $preprocessing_type == "linear_alignment" ]
then
    echo Aligning to standard with linear alignment and manual edits

    flirt -in $input_func -ref $standard -applyisoxfm 3 -init $transformation_matrix -o $output_std

elif [ $preprocessing_type == "nonlinear_alignment" ]
then
    echo Aligning to standard with nonlinear alignment

    sbatch ./scripts/align_functionals.sh ${input_func} $output_std 1

else
    echo $preprocessing_type not found, not making output
fi


# Check if alignment is done
waiting=1
while [[ $waiting -eq 1 ]] 
do 
    if  [[ -e ${output_std} ]]
    then
        waiting=0
    else
        sleep 10s
    fi
done
    
### Step 3 append any missing TRs 

echo Extending file if TRs are missing at the end 
    
./scripts/PlayVideo_analyses/extend_movie_data.sh ${output_std} ${movie_out_name} ${nTRs} ${preprocessing_type}


### Step 4 make the eye closure files 
echo Making the eye closure file
    
# need strings for matlab .. 
file_name="'${file_name}'"
movie="'${movie}'"
movie_out_name="'${movie_out_name}'"
preprocessing_type="'${preprocessing_type}'"
    
matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('scripts/PlayVideo_analyses/'); generate_eyetracker_confounds($file_name,$movie,$movie_out_name,74,$preprocessing_type,0); exit"


exit

