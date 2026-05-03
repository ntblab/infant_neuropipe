#!/bin/bash
#
# Automate the transfer of CartoonLive videos to a standardised format/directory
# Assumes you are running from the subject base directory

# Step 1: Z-score data while ignoring NaNs
# Step 2: Extend the data if there are TRs missing at the end
# Step 3: Align the participant data to adult standard 
# Step 4: figure out which TRs they had their eyes closed for 
# Step 5: Move the raw timing and nifti files, as well as the transformation matrices
# Transfers all of these files to the group folder
#
# Example command:
# sbatch ./scripts/CartoonLive_analyses/supervisor_CartoonLive.sh default CartoonLive-LionKing_Cartoon_ LionKing_Cartoon s5256_1_1
#
# Based off of MM scripts
# 10/03/2022
# 
#
#SBATCH --output=./logs/supervisor_CartoonLive-%j.out
#SBATCH -p psych_day
#SBATCH -t 1:00:00
#SBATCH --mem 16000

source globals.sh

# What analysis type
if [ $# -lt 1 ]
then
    analysis_type='default'
else
    analysis_type=$1
fi

# Specify the movie that is being loaded in (use the underscore at the end). The name may be esoteric, which the next input can fix
if [ $# -lt 2 ]
then
    movie="CartoonLive-LionKing_Cartoon_" # default
else
    movie=$2
fi

# What is the folder name you want to output
if [ $# -lt 3 ]
then
    movie_out_name='LionKing_Cartoon' # default
else
    movie_out_name=$3
fi

# What is the output participant name you want to use (could be a hashed version for anonymity or just left blank by default to use the same as the participant name)
if [ $# -lt 4 ]
then
    ppt_out=$SUBJ # Get the participant name unless otherwise stated
else
    ppt_out=$4
fi

# Get the number of TRs that are expected (this is the length of the movie + an assumed 3 burn-in TRs)
nTRs=93

# Get the name of the experiment according to matlab
experiment_name='CartoonLive'

# Default burn in for the raw data
default_burnin=3

# Make the data directory (okay if already made)
group_dir=$PROJ_DIR/data/Movies/${movie_out_name}/
mkdir -p $group_dir/preprocessed_native/linear_alignment/
mkdir -p $group_dir/preprocessed_standard/linear_alignment/
mkdir -p $group_dir/preprocessed_standard/nonlinear_alignment/
mkdir -p $group_dir/motion_confounds/
mkdir -p $group_dir/eye_confounds/
mkdir -p $group_dir/anatomicals/
mkdir -p $group_dir/transformation_mats/
mkdir -p $group_dir/transformation_ants/
mkdir -p $group_dir/raw_nifti/
mkdir -p $group_dir/raw_timing/

# What are the appropriate paths
subject_dir=$(pwd)
CartoonLive_path=${subject_dir}/analysis/secondlevel_${experiment_name}/${analysis_type}/

# Find all of the niftis that include this movie
movie_niftis=`ls ${CartoonLive_path}/NIFTI/func2highres_${movie}*`

# Sometimes there will be multiple usable viewings of the same movie -- we are going to use the first one by default
# But we will update this decision for certain subjects -- like this one where the first viewing of the cartoon had a lot of aliasing in the functional
if [ $ppt_out == 's4258_1_1' ] && [ $movie_out_name == 'LionKing_Cartoon' ]
then
    nifti=`echo ${movie_niftis} | awk '{ print $2 }'`
else
    nifti=`echo ${movie_niftis} | awk '{ print $1 }'`
fi

nifti_str="'${nifti}'"

zscored_str=$group_dir/preprocessed_native/linear_alignment/${ppt_out}_Z.nii.gz

###### Step 1 - zscore while excluding NaNs
# Find out what functional and block number the movie was run in
temp=${nifti##*$movie}
FuncBlock=${temp%.nii.gz}

# find the motion confounds
MotionConfounds="${CartoonLive_path}/Confounds/MotionConfounds_${FuncBlock}.txt"

# Which TRs are excluded? (from z-scoring; they are still kept in the nifti file)
ExcludedTRs=(`grep -n 1 $MotionConfounds | cut -d: -f1`)
exclusions="[${ExcludedTRs[@]}]"

echo "$exclusions TRs are being excluded for ${FuncBlock} using zscore_exclude"
	
# run the script for z-scoring        
matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('scripts/'); z_score_exclude($nifti_str, '$zscored_str', $exclusions);"


# Check if finished
waiting=1
echo Waiting for file
while [[ $waiting -eq 1 ]] 
do 
	if  [[ -e $zscored_str ]]
	then
		waiting=0
	else
		sleep 10s
	fi
done
 
# Copy the motion confounds
ConfoundFile=$group_dir/motion_confounds/${ppt_out}.txt
cp $CartoonLive_path/Confounds/MotionConfounds_$FuncBlock.txt $ConfoundFile

### Step 2 append any missing TRs so that all subjects have the same length files
echo Extending file if TRs are missing at the end 

./scripts/CartoonLive_analyses/extend_movie_data.sh ${zscored_str} ${ConfoundFile} ${nTRs}


###### Step 3 align the data
# Loop through the alignment methods (now, we only use nonlinear alignment)

input_func=$zscored_str
transformation_matrix=${subject_dir}/analysis/secondlevel/registration.feat/reg/example_func2standard.mat
standard=${subject_dir}/analysis/secondlevel/registration.feat/reg/standard.nii.gz

for preprocessing_type in nonlinear_alignment
do

	output_std=$group_dir/preprocessed_standard/$preprocessing_type/${ppt_out}_Z.nii.gz
# 	if [ ! -e $output_std ]
# 	then
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
# 	fi

done


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

### Step 4 make the eye closure files
echo Making the eye closure file

# need strings for matlab ...
output_name="'$group_dir/eye_confounds/${ppt_out}.txt'"

matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('scripts/CartoonLive_analyses/'); generate_eyetracker_confounds($output_name,'$movie',$nTRs,'$experiment_name',0);"

### Step 5 Transfer raw data and transformation matrices

echo Preparing the transfer of raw data, timing, and transformation matrices

# Copy the raw timing files as well as the associated functionals and func2highres alignments
func_run=${FuncBlock%%_*}
file=analysis/firstlevel/Timing/${func_run}_${movie::-1}.txt

# Copy over the timing file
cp $file $group_dir/raw_timing/${ppt_out}_${func_run}.txt

# Use the default burn in if not specified
if [ -z $(grep $func_run analysis/firstlevel/run_burn_in.txt) ]
then 
    burnin_val=$default_burnin
    
else
    # Figure out what the burn in was and copy that over
    run_burn_in=`grep $func_run analysis/firstlevel/run_burn_in.txt`
    burnin_val=${run_burn_in##* }
fi

echo "Burn in found: $ppt_out $func_run $burnin_val"

# Copy over the burn in value to a text file with rows for each subject
echo "$ppt_out $func_run $burnin_val" >> $group_dir/raw_timing/run_burn_in.txt

# Copy over the raw data run or pseudorun
func_file=data/nifti/${SUBJ}_${func_run}.nii.gz
if [ ! -e ${func_file} ]
then
	func_file=analysis/firstlevel/pseudorun/${SUBJ}_${func_run}.nii.gz
fi

cp $func_file $group_dir/raw_nifti/${ppt_out}_${func_run}.nii.gz

# Copy over the func2highres alignment
cp analysis/firstlevel/${func_run}.feat/reg/example_func2highres.mat $group_dir/transformation_mats/${ppt_out}_${func_run}_highres.mat

# For each participant copy over the linear and ANTs directories
cp analysis/secondlevel/registration.feat/reg/highres2standard.mat $group_dir/transformation_mats/${ppt_out}_highres2standard.mat

cp -R analysis/secondlevel/registration_ANTs $group_dir/transformation_ants/${ppt_out}/

# Copy over the anatomical but name it so that you know it needs to be skull stripped
cp analysis/secondlevel/highres_original.nii.gz $group_dir/anatomicals/${ppt_out}_DO_NOT_SHARE.nii.gz

echo Finished

exit

