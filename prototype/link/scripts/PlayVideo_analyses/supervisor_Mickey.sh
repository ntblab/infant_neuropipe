#!/bin/bash
#
# Automate the analysis of PlayVideo (AKA movies like Mickey) 
# Assumes you are running from the subject base directory

# Step 1: Z-score data while ignoring NaNs (already done in earlier preprocessing)
# Step 2: Align the participant data to adult standard 
# Step 3: Extend the data if there are TRs missing at the end
# Step 4: figure out which TRs they had their eyes closed for 
# Transfers all of these files to the group folder
#
# Reworked so everything can be run in participant folder TY 052021
# Updated to align with MM script (though only roughly)
#
#SBATCH --output=./logs/supervisor_Mickey-%j.out
#SBATCH -p day
#SBATCH -t 1:00:00
#SBATCH --mem 16000

source globals.sh

if [ $# -lt 1 ]
then
    analysis_type='default'
else
    analysis_type=$1
fi

# Specify the movie that is being loaded in (use the underscore at the end). The name may be esoteric, which the next input can fix
if [ $# -lt 2 ]
then
    movie='PlayVideo_'
else
    movie=$2
fi

# What is the folder name you want to output
if [ $# -lt 3 ]
then
    movie_out_name='Mickey' # temporarily named so we don't overwrite files 
else
    movie_out_name=$3
fi

# What is the output participant name you want to use (could be a hashed version for anonymity or just left black for the default)
if [ $# -lt 4 ]
then
    ppt_out=$SUBJ # Get the participant name unless otherwise stated
else
    ppt_out=$4
fi

# Get the number of TRs that are expected
nTRs=148 # two viewings
nTRs_halved=74 #one viewing
default_burnin=3

# Get the name according to matlab
experiment_name='PlayVideo'

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
PlayVideo_path=${subject_dir}/analysis/secondlevel_${experiment_name}/${analysis_type}/

# Get the nifti file (here we will take all viewings, that are already zscored)
nifti=${PlayVideo_path}/NIFTI/func2highres_PlayVideo_Z.nii.gz

nifti_str="'${nifti}'"

zscored_str=$group_dir/preprocessed_native/linear_alignment/${ppt_out}_Z.nii.gz

###### Step 1 - zscore while excluding NaNs due to motion
# find the motion confounds
MotionConfounds="${PlayVideo_path}/Confounds/MotionConfounds.txt"
 
# Which TRs are excluded?
ExcludedTRs=(`grep -n 1 $MotionConfounds | cut -d: -f1`)
exclusions="[${ExcludedTRs[@]}]"

echo "$exclusions TRs are being excluded for Play Video"

# skip running the step, this was already technically run   
# matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('scripts/'); z_score_exclude($nifti_str, $zscored_str, $exclusions);"
cp ${nifti} ${zscored_str}

# Copy the motion confounds
ConfoundFile=$group_dir/motion_confounds/${ppt_out}.txt
cp $PlayVideo_path/Confounds/MotionConfounds.txt $ConfoundFile

### Step 2 append any missing TRs 
echo Extending file if TRs are missing at the end 
    
./scripts/PlayVideo_analyses/extend_movie_data.sh ${zscored_str} ${ConfoundFile} ${nTRs}


###### Step 3 align the data
# Loop through the two alignment methods

input_func=$zscored_str
transformation_matrix=${subject_dir}/analysis/secondlevel/registration.feat/reg/example_func2standard.mat
standard=${subject_dir}/analysis/secondlevel/registration.feat/reg/standard.nii.gz

for preprocessing_type in linear_alignment nonlinear_alignment
do

	output_std=$group_dir/preprocessed_standard/$preprocessing_type/${ppt_out}_Z.nii.gz
	if [ ! -e $output_std ]
	then
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
	fi

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
    
# need strings for matlab .. 
movie_str="'${movie}'"
experiment_name_str="'${experiment_name}'"

# need strings for matlab .. 
output_name="'$group_dir/eye_confounds/${ppt_out}.txt'"

    
matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('scripts/PlayVideo_analyses/'); generate_eyetracker_confounds($output_name,$movie_str,$nTRs_halved,$experiment_name_str,0); exit"

### Step 5 Transfer raw data and transformation matrices

func_files=`ls analysis/secondlevel_PlayVideo/default/NIFTI/*functional*block*` # get the names of the files for the multiple blocks

func_list="" # initialize 
for file in $func_files
do

    # Copy the raw timing files as well as the associated functionals and func2highres alignments
    FuncBlock=${file##*-}
    block=${FuncBlock%%_functional*} # get the block name 
    
    temp=${FuncBlock#*$block*_} # get the functional name
    func_run=${temp%%_block*}
    
    # Because of the way PlayVideo is coded, the block name is used instead of the movie here 
    file=analysis/firstlevel/Timing/${func_run}_${movie::-1}-${block}.txt 

    # Copy over the timing file
    cp $file $group_dir/raw_timing/${ppt_out}_${func_run}_${block}.txt

    # Did you already transfer the nifti and figure out the burn in? Check the func_list
    if [[ "$func_list" == *"$func_run"* ]]
    then
        echo "already added $func_run raw data"

    else
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

        # Copy over the burn in value
        echo "$ppt_out $func_run $burnin_val" >> $group_dir/raw_timing/run_burn_in.txt

        # Copy over the run or pseudorun
        func_file=data/nifti/${SUBJ}_${func_run}.nii.gz
        if [ ! -e ${func_file} ]
        then
            func_file=analysis/firstlevel/pseudorun/${SUBJ}_${func_run}.nii.gz
        fi

        cp $func_file $group_dir/raw_nifti/${ppt_out}_${func_run}.nii.gz

        # Copy over the func2highres alignment
        cp analysis/firstlevel/${func_run}.feat/reg/example_func2highres.mat $group_dir/transformation_mats/${ppt_out}_${func_run}_highres.mat

    fi
    
    func_list="${func_list} ${func_run}"

done

# For each participant copy over the linear and ANTs directories
cp analysis/secondlevel/registration.feat/reg/highres2standard.mat $group_dir/transformation_mats/${ppt_out}_highres2standard.mat

cp -R analysis/secondlevel/registration_ANTs $group_dir/transformation_ants/${ppt_out}/

# Copy over the anatomical but name it so that you know it needs to be skull stripped
cp analysis/secondlevel/highres_original.nii.gz $group_dir/anatomicals/${ppt_out}_DO_NOT_SHARE.nii.gz

echo Finished

exit
