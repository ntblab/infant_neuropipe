#!/bin/bash
# After you have run preprocessing_exploration for all runs, take the sliced data, align and concatenate it
#
# C Ellis 100719. 
#
#SBATCH --output=./logs/preprocessing_exploration_concat-%j.out
#SBATCH -p short
#SBATCH -t 2:00:00
#SBATCH --mem 10000

# Get the condition you are running this on
condition=$1

# Set the min block
min_blocks=2

# Load in all the necessary information
source globals.sh

# Get the output name
subject_dir=$(pwd)
exploration_path="${subject_dir}/analysis/firstlevel/Exploration/"
output_dir=${exploration_path}/preprocessing_exploration/concat_${condition}

#If the file that you want to create exists then quit
if [ -e ${output_dir}_Z.feat/stats/zstat1_standard.nii.gz ]
then
	echo Already created ${output_dir}_Z.feat/stats/zstat1_standard.nii.gz
	echo Quitting
	exit
fi

# What is the root directory for the subject
subject_name=${subject_dir#*subjects/} # What is the participant name
subject_name=${subject_name%/*} # Remove the slash

# Make the output dir
concat_dir=${exploration_path}/preprocessing_exploration/concat/
mkdir -p $concat_dir

confound_dir=${exploration_path}/preprocessing_exploration/confound_files/

# Get the ev_dir
ev_dir=${exploration_path}/preprocessing_exploration/ev_files/

# Where is the anat file
anatomical_file="${subject_dir}/analysis/secondlevel/highres_original.nii.gz"

slice_dir=${exploration_path}/preprocessing_exploration/sliced/

# Remove any files that may have been created before
rm -f ${concat_dir}/concat*${condition}.nii.gz
rm -f ${concat_dir}/concat*${condition}_Z.nii.gz
rm -f ${ev_dir}/concat*${condition}.txt
rm -f ${confound_dir}/concat*${condition}.txt

#Get all of the runs, some of which won't be usable
run_names=`ls -d ${exploration_path}/preprocessing_exploration/functional*_${condition}_sliced.feat`

echo Starting now
for run_name in $run_names
do
	
	# Pull out the run ID
	run_name=`echo ${run_name#*/functional}`
	run_name=`echo ${run_name%%_*}`
	echo Using $run_name
	
	# Output name
	output_name=$concat_dir/concat_${condition}.nii.gz
	output_name_Z=$concat_dir/concat_${condition}_Z.nii.gz
	
	# Check that this run has the minimum number of blocks 
	input_ev=${ev_dir}/functional${run_name}_${condition}_sliced.txt
	block_num=`cat $input_ev | wc -l`
	if [ $block_num -lt $min_blocks ]
	then
		echo $run_name has insufficient blocks, skipping
		continue
	fi

	# Get the transformation matrix
	example_func2highres=${exploration_path}/preprocessing_exploration/example_func2highres_${run_name}.mat

	# Get the filtered_func data for alignment
	filtered_func=${exploration_path}/preprocessing_exploration/functional${run_name}_${condition}_sliced.feat/filtered_func_data.nii.gz
	mask=${exploration_path}/preprocessing_exploration/functional${run_name}_${condition}_sliced.feat/mask.nii.gz

	# Align the data to highres	
	temp_name=temp_${run_name}_${condition}.nii.gz
	flirt -in $filtered_func -ref $anatomical_file -applyisoxfm 3 -init $example_func2highres -o $temp_name
	
	temp_name_Z=temp_${run_name}_${condition}_Z.nii.gz

	motion_confound=${exploration_path}/preprocessing_exploration/confound_files/testing_${run_name}_${condition}_sliced.txt

	# Run Z scoring
	matlab -nodesktop -nosplash -jvm -nodisplay -r "addpath scripts; confounds=dlmread('$motion_confound'); Excluded_TRs=find(sum(confounds(:, sum(confounds,1)==1),2)==1); z_score_exclude('$temp_name', '$temp_name_Z', Excluded_TRs); exit" #  > /dev/null 2>&1 # Run z scoring but silence the output to make it easier for you to read
	
	# Either create or append to the concat file
	if [ -e $output_name ]
	then
		echo Appending to $output_name
		fslmerge -t $output_name $output_name $temp_name
		fslmerge -t $output_name_Z $output_name_Z $temp_name_Z
	else
		echo Creating $output_name
		cp $temp_name $output_name 
		cp $temp_name_Z $output_name_Z
	fi
	# This may have been created
	rm -f temp_${run_name}_${condition}.nii


	## Concatenate timing files

	# How many TRs are there for this run
	run_TRs=`fslnvols $temp_name`
	current_TRs=`fslnvols $output_name`
	TR=`fslval $temp_name pixdim4` 
	run_duration=`echo "$run_TRs * $TR" | bc -l`	
	current_duration=`echo "$current_TRs * $TR" | bc -l`
	previous_run_total=`echo "$current_duration - $run_duration" | bc -l`
	echo Adding $previous_run_total seconds to this timing file

	# Concatenate the timing file
	output_ev=${ev_dir}/concat_${condition}.txt
	temp_ev=temp_concat_${condition}.txt

	if [ -e $output_ev ]
	then
		echo Appending to $output_ev
		matlab -nodesktop -nosplash -nojvm -nodisplay -r "addpath scripts; change_timing_file_columns('$input_ev','$temp_ev','add_$previous_run_total',1); exit;"

		# Do the actual append
		cat $temp_ev >> $output_ev
	else
		# Just copy over
		echo Creating $output_ev
		cp $input_ev $output_ev
	fi
	

	# Align the mask if it was created
	output_mask=$concat_dir/mask_${condition}.nii.gz
	flirt -in $mask -ref $anatomical_file -applyisoxfm 3 -init $example_func2highres -o $temp_name -interp nearestneighbour
	if [ -e $output_mask ]
	then
		echo Appending to $output_mask
		fslmerge -t $output_mask $output_mask $temp_name
	else
		echo Creating $output_mask
		cp $temp_name $output_mask
	fi


	## Concatenate motion parameters
	
	# Set the relevant defaults
	fslmotion_threshold=3
	PCA_threshold=0
	run_confound=1
	motion_recovery=0

	# Get the filenames for confounds and motion parameter files
	motionparameter_file=${subject_dir}/analysis/firstlevel/Confounds/MotionParameters_standard_functional${run_name}.par
	if [[ $condition == "MotionParameters_None" ]]
	then
		run_confound=0
		motionparameter_file=""
	elif [[ $condition == "MotionParameters_Standard" ]]
	then

		motionparameter_file=${subject_dir}/analysis/firstlevel/Confounds/MotionParameters_standard_functional${run_name}.par
		fslmotion_threshold=0
		PCA_threshold=0

	elif [[ $condition == "MotionParameters_Extended" ]]
	then
		motionparameter_file=${subject_dir}/analysis/firstlevel/Confounds/MotionParameters_extended_functional${run_name}.par
		fslmotion_threshold=0
		PCA_threshold=0
	elif [[ $condition == "MotionParameters_Extended_confounds" ]]
	then

		motionparameter_file=${subject_dir}/analysis/firstlevel/Confounds/MotionParameters_extended_functional${run_name}.par

	elif [[ $condition == "MotionParameters_Extended_fslmotion_thr"* ]]
	then
		motionparameter_file=${subject_dir}/analysis/firstlevel/Confounds/MotionParameters_extended_functional${run_name}.par
		fslmotion_threshold=${condition#*thr}
		PCA_threshold=0
	elif [[ $condition == "MotionConfounds_fslmotion_thr"* ]]
	then

		fslmotion_threshold=${condition#*thr}

	elif [[ $condition == "MotionConfounds_PCA_thr"* ]]
	then

		PCA_threshold=${condition#*thr}
		PCA_threshold=${PCA_threshold%_fslmotion*}

		if [[ $condition == "MotionConfounds_PCA_thr${PCA_threshold}_fslmotion_thr"* ]]
		then
		        fslmotion_threshold=${condition#*_fslmotion_thr}
		fi

	elif [[ $condition == "Motion_recovery_"* ]]
	then
		# Pull out how many TRs you are going to use for the recovery
		motion_recovery=${condition#Motion_recovery_}
		motion_recovery=${motion_recovery%_fslmotion*}

		if [[ $condition == "Motion_recovery_${motion_recovery}_fslmotion_thr"* ]]
		then
		        fslmotion_threshold=${condition#*_fslmotion_thr}
		fi
	fi
        

        # Run the script to trim the fMRI data and the design matrix
        input_data=${filtered_func}
        output_data=None
        output_ev_file=None

	# Create the files for the motion parameters
        input_confound_mat=$motionparameter_file
        output_motion_parameter=$confound_dir/functional${run_name}_motion_parameter_${condition}.txt

        # Run the slicing of the data and the design matrices
	echo Using $input_confound_mat creating $output_motion_parameter
        matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('${subject_dir}/scripts/preprocessing_exploration/'); slice_data('${input_data}', '${output_data}', '${ev_dir}/functional${run_name}_${condition}.txt', '${output_ev_file}', '${input_confound_mat}', '${output_motion_parameter}', 0, 1); exit"

        # Make files based on the motion threshold
	fslmotion_confound_file=${subject_dir}/analysis/firstlevel/Confounds/MotionConfounds_fslmotion_${fslmotion_threshold}_functional${run_name}.txt
	input_confound_mat=$fslmotion_confound_file
	output_confound_motion=$confound_dir/functional${run_name}_confound_motion_${condition}.txt
	if [ -e $input_confound_mat ]
	then
		if [ $fslmotion_threshold != 0 ]
		then
		        
			# Run the slicing of the data and the design matrices
			echo Using $input_confound_mat creating $output_confound_motion
			matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('${subject_dir}/scripts/preprocessing_exploration/'); slice_data('${input_data}', '${output_data}', '${ev_dir}/functional${run_name}_${condition}.txt', '${output_ev_file}', '${input_confound_mat}', '${output_confound_motion}', 0, 1); exit"

			# Add the motion confounds if appropriate
			if [ $motion_recovery != 0 ]
			then
				matlab -nodesktop -nosplash -nodisplay -r "addpath $PROJ_DIR/prototype/link/scripts/; motion_recovery('$output_confound_motion', '$output_confound_motion', '$motion_recovery'); exit"
			fi
	
		fi

	else		

		# If this file does not exist then make a vector of zeros to use
		echo Making vector since $input_confound_mat does not exist
		run_TRs=`cat $output_motion_parameter | wc -l`

		#Make a list of 0s the same size as there are TRs
		matlab -nodesktop -nosplash -nodisplay -nojvm -r "vec=zeros($run_TRs,1); dlmwrite('$output_confound_motion', vec); exit"
	fi

	# Make files based on the PCA threshold
	input_confound_mat=$PCA_confound_file
	output_confound_PCA=$confound_dir/functional${run_name}_confound_PCA_${condition}.txt
	if [ $PCA_threshold != 0 ]
	then
		PCA_confound_file=${subject_dir}/analysis/firstlevel/Confounds/MotionConfounds_PCA_threshold_${PCA_threshold}_functional${run_name}.txt

		# Run the slicing of the data and the design matrices
		echo Using $input_confound_mat creating $output_confound_PCA
		matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('${subject_dir}/scripts/preprocessing_exploration/'); slice_data('${input_data}', '${output_data}', '${ev_dir}/functional${run_name}_${condition}.txt', '${output_ev_file}', '${input_confound_mat}', '${output_confound_PCA}', 0, 1); exit"
	
	fi

	# Specify the concatenated file names
	concat_motion_parameters=$confound_dir/concat_motion_parameter_${condition}.txt
	concat_confound_motion=$confound_dir/concat_confound_motion_${condition}.txt
	concat_confound_PCA=$confound_dir/concat_confound_PCA_${condition}.txt
	
	# Either create or append the files that you are making
	if [ -e $concat_motion_parameters ]
	then	
		echo Appending motion parameters
		matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('$SCRIPT_DIR'); append_regressor_file('$output_motion_parameter', '$concat_motion_parameters', '0');"

		if [ -e $output_confound_motion ]
		then
			matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('$SCRIPT_DIR'); append_regressor_file('$output_confound_motion', '$concat_confound_motion', '1');"
		fi

		if [ -e $output_confound_PCA ]
		then
			matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('$SCRIPT_DIR'); append_regressor_file('$output_confound_PCA', '$concat_confound_PCA', '1');"
		fi
	
	else
		cp $output_motion_parameter $concat_motion_parameters
		
		if [ -e $output_confound_motion ]
		then
			cp $output_confound_motion $concat_confound_motion
		fi

		if [ -e $output_confound_PCA ]
		then
			cp $output_confound_PCA $concat_confound_PCA
		fi
	fi

	# Clean up
	rm -f $temp_name $temp_name_Z $temp_ev

done

# Check that any files were created
if [ -e $output_name ]
then

# Append the width of the matrix
concat_overall=$confound_dir/concat_overall_${condition}.txt
temp_name=temp_${condition}.txt
cp $concat_motion_parameters $concat_overall
if [ -e $concat_confound_motion ]
then
	paste -d' ' $concat_overall $concat_confound_motion > $temp_name
	mv $temp_name $concat_overall
fi
if [ -e $concat_confound_PCA ]
then
	paste -d' ' $concat_overall $concat_confound_PCA > $temp_name
	mv $temp_name $concat_overall
fi

# Finally, decorrelate all of the confounds
echo Decorrelating the overall data
matlab -nodesktop -nosplash -nodisplay -r "addpath $PROJ_DIR/prototype/link/scripts/; motion_decorrelator('$concat_overall', '$concat_overall'); exit"

# Average the masks and mask the functional data
fslmaths $output_mask -abs -Tmean -thr 1 -bin $output_mask
fslmaths $concat_dir/concat_${condition}.nii.gz -mas $output_mask $concat_dir/concat_${condition}.nii.gz

## Run the feat

# what is the fsf template
fsf_template=${subject_dir}/fsf/preprocessing_exploration_concat.fsf.template
fsf_output=${exploration_path}/preprocessing_exploration/fsf/concat_${condition}.fsf

# Set the default values
interpolation=1
smoothing_parameter=5
sfnrmask=1
run_prewhitening=0
nifti_file=$concat_dir/concat_${condition}.nii.gz
run_standard_motion_parameters=0 # Don't use this because it changes the reference TR
motionparameter_file=$confound_dir/concat_motion_parameter_${condition}.txt
fslmotion_threshold=3
PCA_threshold=0
example_func_file=${subject_dir}/analysis/firstlevel/Confounds/example_func_functional${run_name}.nii.gz
run_confound=1
melodic=0
despiking=1
ica_corr_thresh=0.5
temporal_derivative=0
OverallConfound_file=${concat_overall}
motion_recovery=0
run_burn_in=0 # Automatically set to zero

#Get the run information
tr_number=`fslval $nifti_file dim4`
tr_duration=`fslval $nifti_file pixdim4`

# If this was started but not finished then delete it
if [ -e ${output_dir}.feat ]
then
        rm -rf ${output_dir}.feat
fi

echo Submitting ${condition}

# Change the parameters
if [[ $condition == "smoothing_"* ]]
then
        smoothing_parameter=${condition#*smoothing_}

elif [[ $condition == "MELODIC_thresh_"* ]]
then
        ica_corr_thresh=${condition#MELODIC_thresh_}
        ica_corr_thresh=${ica_corr_thresh%_fslmotion*}
        melodic=1 # Overwrite whatever is there

        if [[ $condition == "MELODIC_thresh_${threshold}_fslmotion_thr*" ]]
	then
		fslmotion_threshold=${condition#*_fslmotion_thr}
	fi
elif [[ $condition == "PreWhitening" ]]
then
        run_prewhitening=1

elif [[ $condition == "Temporal_derivative" ]]
then
        temporal_derivative=1
fi


# Run the feat analyses when necessary, copy them when they are identical
#Replace the <> text (excludes the back slash just before the text) with the other supplied text
# note: the following replacements put absolute paths into the fsf file. this
#       is necessary because FEAT changes directories internally
cat $fsf_template \
| sed "s:<?= \$OUTPUT_DIR ?>:$output_dir:g" \
| sed "s:<?= \$TR_NUMBER ?>:$tr_number:g" \
| sed "s:<?= \$TR_DURATION ?>:$tr_duration:g" \
| sed "s:<?= \$RUN_BURN_IN ?>:$run_burn_in:g" \
| sed "s:<?= \$SFNR_MASKING ?>:$sfnrmask:g" \
| sed "s:<?= \$SMOOTHING_PARAMETER ?>:$smoothing_parameter:g" \
| sed "s:<?= \$CONFOUND_INTERPOLATION ?>:$interpolation:g" \
| sed "s:<?= \$DESPIKING ?>:$despiking:g" \
| sed "s:<?= \$MELODIC ?>:$melodic:g" \
| sed "s:<?= \$ICA_CORR_THRESH ?>:$ica_corr_thresh:g" \
| sed "s:<?= \$RUN_PREWHITENING ?>:$run_prewhitening:g" \
| sed "s:<?= \$NIFTI_FILE ?>:$nifti_file:g" \
| sed "s:<?= \$EXAMPLE_FUNC_FILE ?>:$example_func_file:g" \
| sed "s:<?= \$RUN_CONFOUND ?>:$run_confound:g" \
| sed "s:<?= \$RUN_STANDARD_MOTION_PARAMETERS ?>:$run_standard_motion_parameters:g" \
| sed "s:<?= \$CONFOUND_FILE ?>:$OverallConfound_file:g" \
| sed "s:<?= \$ANATOMICAL_FILE ?>:$anatomical_file:g" \
| sed "s:<?= \$TEMPORAL_DERIVATIVE ?>:$temporal_derivative:g" \
| sed "s:<?= \$EV_FILE ?>:$output_ev:g" \
        > $fsf_output #Output to this file

echo Making $fsf_output

# Run the feat analyses
sbatch -p $SHORT_PARTITION ./scripts/run_feat.sh $fsf_output

# Wait for the feat to finish and then run it with the z scored data
waiting=1
while [[ $waiting -eq 1 ]]
do
        if  [[ -e ${output_dir}.feat/stats/zstat1.nii.gz ]]
        then
                waiting=0
        else
                sleep 10s
        fi
done

# Delete and rerun
rm -rf ${output_dir}_Z.feat
sbatch --output=./logs/Feat_stats-%j.out ${subject_dir}/scripts/FEAT_stats.sh ${output_dir}.feat/ ${output_dir}_Z.feat/ $concat_dir/concat_${condition}_Z.nii.gz

# Wait for the feat to finish and then run it with the z scored data
waiting=1
while [[ $waiting -eq 1 ]]
do
  if  [[ -e ${output_dir}_Z.feat/stats/zstat1.nii.gz ]]
        then
            waiting=0
        else
            sleep 10s
        fi
done

# Wait for the job to be run
sleep 5m

# Do this again in case the zstat file you saw was actually the old one, rather than the new one
waiting=1
while [[ $waiting -eq 1 ]]
do
        if  [[ -e ${output_dir}_Z.feat/stats/zstat1.nii.gz ]]
        then
                waiting=0
        else
                sleep 10s
        fi
done

## Align the zstat map in standard space

echo Aligning Zstat map ${output_dir}_Z.feat/stats/zstat1.nii.gz

# Get the transformation matrix
highres2standard=${subject_dir}/analysis/secondlevel/registration.feat/reg/highres2standard.mat

# Align the data to highres	
flirt -in ${output_dir}_Z.feat/stats/zstat1.nii.gz -ref ${subject_dir}/analysis/secondlevel/registration.feat/reg/standard.nii.gz -applyxfm -init $highres2standard -o ${output_dir}_Z.feat/stats/zstat1_standard.nii.gz

else

	echo No files were created, no runs usable. Quitting
fi

echo Finished

