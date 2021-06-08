#!/bin/bash
#
# Automate the analysis of MM videos 
# Assumes you are running from the subject base directory

# Step 1: Z-score data while ignoring NaNs
# Step 2: Align the participant data to adult standard 
# Step 3: Extend the data if there are TRs missing at the end
# Step 4: figure out which TRs they had their eyes closed for 
# Transfers all of these files to the group folder
#
# Note that several movie clips could have been shown using the MM experiment presentation method, but we specify here to use the movie that was collected in the most number of subjects, in a no-sound condition, and with the visual input intact ("MM-Full_Pilot_NoAudio_") This name is a mouthful, and could be confusing given other connotations of the word "pilot" so we chose to call the movie "Aeronaut" in our manuscripts
# There is therefore some discrepancy between movie names used in earlier preprocessing steps and in this script, but we use the name Aeronaut in group analyses because it is more informative 
#
#
# TY 07112019 
# Pilot updates TY 09132019
# Reworked so everything can be run in participant folder TY 052021
#
#SBATCH --output=./logs/supervisor_MM_Pilot-%j.out
#SBATCH -p day
#SBATCH -t 1:00:00
#SBATCH --mem 16000

if [ $# -eq 0 ]
then
    analysis_type='default'
    preprocessing_type='nonlinear_alignment'
else
    analysis_type=$1
fi

if [ $# -eq 1 ]
then
    preprocessing_type='nonlinear_alignment' # could also be "linear"
else
    preprocessing_type=$1
    
fi



source globals.sh

# What is the name of movie you care about?
movie="MM-Full_Pilot_NoAudio_" # name of the movie in the subject folders, following outputs of the experiment menu and analysis timing
movie_out_name='Aeronaut' # Aeronaut is a simpler name we use in manuscripts to avoid confusion over the word pilot
nTRs=93


# Make the data directory
group_dir=$PROJ_DIR/data/Movies/${movie_out_name}/
mkdir -p $group_dir/preprocessed_native/$preprocessing_type/
mkdir -p $group_dir/preprocessed_standard/$preprocessing_type/
mkdir -p $group_dir/motion_confounds/
mkdir -p $group_dir/eye_confounds/

# What are the appropriate paths
subject_dir=$(pwd)
MM_path=${subject_dir}/analysis/secondlevel_MM/${analysis_type}/


# Find all of the niftis that include this movie
pilot_niftis=`ls ${MM_path}/NIFTI/func2highres_${movie}*`

#preset the counter to be 0 (most of the time this movie will only be played once)
counter=1;

for nifti in $pilot_niftis
do 

	nifti_str="'${nifti}'"

	if [ $counter -eq 1 ] 
	then		
        	file_name=${SUBJ}_Z.nii.gz
	else
        	file_name=${SUBJ}_viewing_${counter}_Z.nii.gz
	fi
    
    	zscored_str="'${MM_path}/NIFTI/${file_name}'"

    	###### Step 1 - zscore while excluding NaNs
	# This was done for all movies played within the same functional run in an earlier preprocessing step, but here we want to make sure to only z-score within the movie of interest

	# Find out what functional and block number the movie was run in
	temp=${nifti##*$movie}
	FuncBlock=${temp%.nii.gz}

	# find the motion confounds
	MotionConfounds="${MM_path}/Confounds/MotionConfounds_${FuncBlock}.txt"
 
	# Which TRs are excluded?
	ExcludedTRs=(`grep -n 1 $MotionConfounds | cut -d: -f1`)
	exclusions="[${ExcludedTRs[@]}]"

	echo $exclusions
	echo "TRs are being excluded for ${FuncBlock} using zscore_exclude"
		
	# run the script        
	matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('scripts/'); z_score_exclude($nifti_str, $zscored_str, $exclusions);"
	
    
        # Check if finished
	waiting=1
	while [[ $waiting -eq 1 ]] 
	do 
		if  [[ -e ${MM_path}/NIFTI/${file_name} ]]
		then
			waiting=0
		else
			sleep 10s
		fi
	done
    
    
     # Copy the motion confounds
    if [ $counter -eq 1 ] 
	then
        cp $MM_path/Confounds/MotionConfounds_$FuncBlock.txt $group_dir/motion_confounds/${SUBJ}.txt
    else
        cp $MM_path/Confounds/MotionConfounds_$FuncBlock.txt $group_dir/motion_confounds/${SUBJ}_viewing_${counter}.txt
    fi
    
    
    # Copy over the z-scored nifti
    cp ${MM_path}/NIFTI/${file_name} $group_dir/preprocessed_native/$preprocessing_type/

    
    ###### Step 2 align the data
    # use alignment created earlier in preprocessing
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
    
    ###### Step 3 append any missing TRs 
    # Sometimes we may stop a movie before it finishes for various reasons. If more than half of the movie was usable, though, we will still want to analyse it and need to add buffer TRs at the end to avoid errors later on

    echo Extending file if TRs are missing at the end 
    
    ./scripts/MM_analyses/extend_movie_data.sh ${output_std} ${counter} ${movie_out_name} ${nTRs} ${preprocessing_type}


    ###### Step 4 make the eye closure files 
    # Figure out which TRs are not usable based on eye closure

    echo Making the eye closure file
    
    # need strings for matlab .. 
    file_name="'${file_name}'"
    movie="'${movie}'"
    movie_out_name="'${movie_out_name}'"
    nTRs="'${nTRs}'"
    preprocessing_type="'${preprocessing_type}'"
    
    matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('scripts/MM_analyses/'); generate_eyetracker_confounds($file_name,$movie,$movie_out_name,93,$preprocessing_type,0); exit"


    #add to the counter
    counter=$((counter+1))
    
    
done



exit
