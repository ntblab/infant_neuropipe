#!/bin/bash
#
# Automate the Preprocessing Exploration analyses 
# Similar in spirit to render-fsf-templates but set up to run many
# different combinations of preprocessing decisions in order to observe
# the contrast between task and rest. The basic format is that a fsf
# copied over and edited when necessary. The FEAT is then run but using
# the components in FEAT_firstlevel, thus allowing code to be changed in
# a number of different ways. 
#
# C Ellis 081017. 
#
#SBATCH --output=./logs/preprocessing_exploration-%j.out
#SBATCH -p short
#SBATCH -t 5:00:00
#SBATCH --mem 20000

# What is the name of the functional being selected
functional_run=$1

# Load in all the necessary information
source globals.sh

# Pull out the fsl path (assumes that FSL has been loaded)
fslpath=`which feat`
fslpath=${fslpath%feat}

# Are you using slurm or not?
if [[ ${SCHEDULER} == slurm ]]
then
	slurm=1
else
	slurm=0
fi

# What is the root directory for the subject
subject_dir=$(pwd)
subject_name=${subject_dir#*subjects/} # What is the participant name
subject_name=${subject_name%/*} # Remove the slash

# What is the path to the folder where these analyses will be run?
exploration_path="${subject_dir}/analysis/firstlevel/Exploration/"

# Make the directory where these analyses will be output
mkdir -p ${exploration_path}/preprocessing_exploration/
mkdir -p ${exploration_path}/preprocessing_exploration/ev_files/
mkdir -p ${exploration_path}/preprocessing_exploration/confound_files/
mkdir -p ${exploration_path}/preprocessing_exploration/fsf/

# Identify variables that are constant across analyses
anatomical_file="${subject_dir}/analysis/firstlevel/functional${functional_run}.feat/reg/highres.nii.gz"

# Determine where the data dir is
if [ ${#functional_run} -eq 2 ]
then
	data_dir=data/nifti/
elif [ ${#functional_run} -eq 3 ]
then
	echo functional${functional_run} is assumed to be a pseudorun, using different data dir
	data_dir=analysis/firstlevel/pseudorun/
else
	echo functional${functional_run} does not match a pseudorun or default format, quitting
	exit
fi

## Run the feats
tr_number=`fslval ${data_dir}/${subject_name}_functional${functional_run}.nii.gz dim4`
tr_duration=`fslval ${data_dir}/${subject_name}_functional${functional_run}.nii.gz pixdim4`

# Change duration to seconds if it is large
is_milliseconds=`echo ${tr_duration}'>'100 | bc -l`
if [[ $is_milliseconds == 1 ]] 
then
	tr_duration=`echo ${tr_duration}/1000 | bc -l`
fi

# Identify the file containing the run files
if [ -e analysis/firstlevel/run_burn_in.txt ]
then
	run_burn_in_file=`cat analysis/firstlevel/run_burn_in.txt`
else
	run_burn_in_file=''
fi

# Concatenate the timing files to make a baseline one
echo Cycling through analyses


# Take in the second input if there is one and use that to determine the analysis types
if [ $# -eq 1 ]
then
analysis_types="default smoothing_0 smoothing_3 smoothing_5 smoothing_8 MELODIC_thresh_0.25_fslmotion_thr3 MELODIC_thresh_0.5_fslmotion_thr3 MELODIC_thresh_1.00_fslmotion_thr3 MotionParameters_Extended MotionParameters_Extended_confounds MotionConfounds_fslmotion_thr0.5 MotionConfounds_fslmotion_thr1 MotionConfounds_fslmotion_thr3 MotionConfounds_fslmotion_thr6 MotionConfounds_fslmotion_thr9 MotionConfounds_fslmotion_thr12 MotionConfounds_PCA_thr0_fslmotion_thr3 MotionConfounds_PCA_thr0.05_fslmotion_thr3 MotionConfounds_PCA_thrIQR_fslmotion_thr3 Despiking_None Temporal_derivative Motion_recovery_1 Motion_recovery_2 Regress_out_excluded"
else
analysis_types=$2
fi


for analysis_type in $analysis_types
do
	fsf_template=$PROJ_DIR/prototype/link/fsf/preprocessing_exploration.fsf.template
	
	for sliced_type in "" # "_raw-sliced"
	do
		
		# Set the paths
		fsf_output=${exploration_path}/preprocessing_exploration/fsf/functional${functional_run}_${analysis_type}${sliced_type}.fsf
		output_dir=${exploration_path}/preprocessing_exploration/functional${functional_run}_${analysis_type}${sliced_type}
	
		# Set the default values
		interpolation=1
		smoothing_parameter=5
		sfnrmask=1
		run_prewhitening=0
		nifti_file=${subject_dir}/${data_dir}/${subject_name}_functional${functional_run}.nii.gz
		run_standard_motion_parameters=0 # Don't use this because it changes the reference TR
		motionparameter_file=${subject_dir}/analysis/firstlevel/Confounds/MotionParameters_standard_functional${functional_run}.par
		fslmotion_threshold=3
		PCA_threshold=0
		example_func_file=${subject_dir}/analysis/firstlevel/Confounds/example_func_functional${functional_run}.nii.gz
		run_confound=1
		melodic=0
		despiking=1
		ica_corr_thresh=0.5
		temporal_derivative=0
		OverallConfound_file=${exploration_path}/preprocessing_exploration/confound_files/testing_${functional_run}_${analysis_type}.txt
		motion_recovery=0
		regress_out_excluded=0
		
		# How many burn in TRs are there
		run_burn_in=3  # Default to 3
		for word in $run_burn_in_file
		do
			if [[ $Correct_word -eq 1 ]] 
			then
				# What is the run burn in 
				run_burn_in=$word
			
				echo Using $run_burn_in TRs as the burn in for run $RunName

				# Reset
				Correct_word=0
			fi
		
			if [[ $word == functional${functional_run} ]]
			then
				Correct_word=1
			fi
		done

		if [ ! -e ${output_dir}.feat/stats/zstat1.nii.gz ]
		then
		
			# If this was started but not finished then delete it
			if [ -e ${output_dir}.feat ]
			then
				rm -rf ${output_dir}.feat
			fi
		
			echo Submitting ${analysis_type}
	
			# Change the parameters
			if [[ $analysis_type == "smoothing_"* ]]
			then
				smoothing_parameter=${analysis_type#*smoothing_}

			elif [[ $analysis_type == "MELODIC_thresh_"* ]]
			then
				ica_corr_thresh=${analysis_type#MELODIC_thresh_}
				ica_corr_thresh=${ica_corr_thresh%_fslmotion*}
				melodic=1 # Overwrite whatever is there

				if [[ $analysis_type == "MELODIC_thresh_${threshold}_fslmotion_thr*" ]]
				then
					fslmotion_threshold=${analysis_type#*_fslmotion_thr}
				fi
			elif [[ $analysis_type == "PreWhitening" ]]
			then
				run_prewhitening=1
			elif [[ $analysis_type == "MotionParameters_None" ]]
			then
				run_confound=0
				motionparameter_file=""
			elif [[ $analysis_type == "MotionParameters_Standard" ]]
			then
			
				motionparameter_file=${subject_dir}/analysis/firstlevel/Confounds/MotionParameters_standard_functional${functional_run}.par
				fslmotion_threshold=0
				PCA_threshold=0
			
			elif [[ $analysis_type == "MotionParameters_Extended" ]]
			then
				motionparameter_file=${subject_dir}/analysis/firstlevel/Confounds/MotionParameters_extended_functional${functional_run}.par
				fslmotion_threshold=0
				PCA_threshold=0
			
			elif [[ $analysis_type == "MotionParameters_Extended_confounds" ]]
			then
			
				motionparameter_file=${subject_dir}/analysis/firstlevel/Confounds/MotionParameters_extended_functional${functional_run}.par
			
			elif [[ $analysis_type == "MotionParameters_Extended_fslmotion_thr"* ]]
			then
				motionparameter_file=${subject_dir}/analysis/firstlevel/Confounds/MotionParameters_extended_functional${functional_run}.par
				fslmotion_threshold=${analysis_type#*thr}
				PCA_threshold=0		
			elif [[ $analysis_type == "MotionConfounds_fslmotion_thr"* ]]
			then
			
				fslmotion_threshold=${analysis_type#*thr}
			
			elif [[ $analysis_type == "MotionConfounds_PCA_thr"* ]]
			then
			
				PCA_threshold=${analysis_type#*thr}
				PCA_threshold=${PCA_threshold%_fslmotion*}
			
				if [[ $analysis_type == "MotionConfounds_PCA_thr${threshold}_fslmotion_thr"* ]]
				then
					fslmotion_threshold=${analysis_type#*_fslmotion_thr}
				fi
			
			elif [[ $analysis_type == "Motion_recovery_"* ]]
			then
				# Pull out how many TRs you are going to use for the recovery
				motion_recovery=${analysis_type#Motion_recovery_}
				motion_recovery=${motion_recovery%_fslmotion*}
			
				if [[ $analysis_type == "Motion_recovery_${motion_recovery}_fslmotion_thr"* ]]
				then
					fslmotion_threshold=${analysis_type#*_fslmotion_thr}
				fi
									
			elif [[ $analysis_type == "Despiking_Raw" ]]
			then
				nifti_file=${subject_dir}/analysis/firstlevel/${subject_name}_functional${functional_run}_despiked.nii.gz
			
			elif [[ $analysis_type == "Despiking_None" ]]
			then
				despiking=0

			elif [[ $analysis_type == "MELODIC_None" ]]
			then
				melodic=0				
			elif [[ $analysis_type == "Temporal_derivative" ]]
			then
				temporal_derivative=1	
			elif [[ $analysis_type == "Regress_out_excluded" ]]
			then
				regress_out_excluded=1		
			fi
		
			# Confirm what the confound files are
			if [ $fslmotion_threshold != 0 ]
			then
				fslmotion_confound_file=${subject_dir}/analysis/firstlevel/Confounds/MotionConfounds_fslmotion_${fslmotion_threshold}_functional${functional_run}.txt
			else
				fslmotion_confound_file=""
			fi
		
			if [ $PCA_threshold != 0 ]
			then
				PCA_confound_file=${subject_dir}/analysis/firstlevel/Confounds/MotionConfounds_PCA_threshold_${PCA_threshold}_functional${functional_run}.txt
			else
				PCA_confound_file=""
			fi
		
			# Change the functional file if you are using any of these parameters
			if [ $fslmotion_threshold != 0 ]
			then
				example_func_file=`ls ${subject_dir}/analysis/firstlevel/Confounds/example_func_functional${functional_run}_TR_*_mahal_threshold_${PCA_threshold}_fslmotion_threshold_${fslmotion_threshold}.nii.gz`

				# Check whether there are multiple functionals
				num_funcs=( $example_func_file )
				num_funcs=${#num_funcs[@]}
	
				if [ $num_funcs -gt 1 ]
				then
					echo Found multiple example funcs, quiting
					exit
				fi
			fi
		
			# Create the baseline file
			yes | cp $motionparameter_file $OverallConfound_file
		
			if [ -e $fslmotion_confound_file ]
			then
				tmp=$(mktemp)
				paste -d' ' $OverallConfound_file $fslmotion_confound_file > $tmp
				yes | mv $tmp $OverallConfound_file
			fi
		
			if [ -e $PCA_confound_file ]
			then
				tmp=$(mktemp)
				paste -d' ' $OverallConfound_file $PCA_confound_file > $tmp
				yes | mv $tmp $OverallConfound_file
			fi
			
			if [ $motion_recovery != 0 ]
			then
				matlab -nodesktop -nosplash -nodisplay -r "addpath $PROJ_DIR/prototype/link/scripts/; motion_recovery('$OverallConfound_file', '$OverallConfound_file', '$motion_recovery'); exit"
			fi
			
			# Decorrelate the design matrix. 
			echo Decorrelating design matrix
			matlab -nodesktop -nosplash -nodisplay -r "addpath $PROJ_DIR/prototype/link/scripts/; motion_decorrelator('$OverallConfound_file', '$OverallConfound_file'); exit"
		
			# Create the ev file, paying attention to exclusions (set the weight to zero on these to make it easier for accounting later)
			ev_file="${subject_dir}/analysis/firstlevel/Exploration/functional${functional_run}.txt"
			output_ev_file="${exploration_path}/preprocessing_exploration/ev_files/functional${functional_run}_${analysis_type}.txt"
			Eye_Exclude_Epoch_file="${subject_dir}/analysis/firstlevel/Confounds/EyeData_Exclude_Epochs_functional${functional_run}.txt"  # Where is the eye data epoch file stored (the 3 column version)
		
			matlab -nodesktop -nosplash -nodisplay -r "addpath $PROJ_DIR/prototype/link/scripts/preprocessing_exploration/; motion_block_exclude('$ev_file', '$OverallConfound_file', '$Eye_Exclude_Epoch_file', '$output_ev_file', '$regress_out_excluded'); exit"
		
			# If it is the sliced version of the analysis, jump in here and use all of the files/names created so far and then make the sliced version		
			if [[ $sliced_type == "_raw-sliced" ]]
			then
				
				mkdir -p ${exploration_path}/preprocessing_exploration/${sliced_type:1}/
				input_data=${exploration_path}/preprocessing_exploration/${sliced_type:1}/functional${functional_run}_${analysis_type}_all.nii.gz
			
				# Trim the raw data to deal with the burn in and make the output useable for the upcoming analysis
				fslroi $nifti_file $input_data $run_burn_in 10000
				
				# Run the script to trim the fMRI data and the design matrix
				output_data=${exploration_path}/preprocessing_exploration/${sliced_type:1}/functional${functional_run}_${analysis_type}.nii.gz
				sliced_ev_file=${exploration_path}/preprocessing_exploration/ev_files/functional${functional_run}_${analysis_type}${sliced_type}.txt
				output_confound_mat=${exploration_path}/preprocessing_exploration/confound_files/testing_${functional_run}_${analysis_type}${sliced_type}.txt
		
				# Remove the outputs because it might already be created
				rm -f $output_data $sliced_ev_file $output_confound_mat
		
				# Run the slicing of the data and the design matrices
				echo Running: 
				echo matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('${subject_dir}/scripts/preprocessing_exploration/'); slice_data('${input_data}', '${output_data}', '${output_ev_file}', '${sliced_ev_file}', '${OverallConfound_file}', '${output_confound_mat}');"
				
				matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('${subject_dir}/scripts/preprocessing_exploration/'); slice_data('${input_data}', '${output_data}', '${output_ev_file}', '${sliced_ev_file}', '${OverallConfound_file}', '${output_confound_mat}'); exit"
				
				# Update the names now that you use the sliced versions in the feat
				
				nifti_file=${output_data}
				OverallConfound_file=${output_confound_mat}
				output_ev_file=${sliced_ev_file}
				tr_number=`fslval ${nifti_file} dim4`
				
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
			| sed "s:<?= \$EV_FILE ?>:$output_ev_file:g" \
				> $fsf_output #Output to this file
	
			echo Making $fsf_output
	
			# Run the feat analyses
			if [ $slurm == 1 ]
			then
				sbatch -p $SHORT_PARTITION ./scripts/FEAT_firstlevel.sh $fsf_output	
			else
				submit_long ./scripts/FEAT_firstlevel.sh $fsf_output
			fi
			
		else
			echo You have already created ${output_dir}. Not re running	
		fi
	done
	
done

# Once these feat folders have finished, slice the data to only include the used blocks plus rest
curr_dir=`pwd`

mkdir -p ${exploration_path}/preprocessing_exploration/fsf/
for analysis_type in $analysis_types
do
	
	# Specify the output directory (of the non_slice directory)
	output_dir=${exploration_path}/preprocessing_exploration/functional${functional_run}_${analysis_type}
	
	input_ev_file=${exploration_path}/preprocessing_exploration/ev_files/functional${functional_run}_${analysis_type}.txt
	
	# How many blocks will be included in this run (if it is zero then skip)
	included_blocks=`cat $input_ev_file | cut -f 3  | paste -sd+ | bc`
	
	# What kind of slicing are you doing? On the raw data or on the preprocessed data?
	for slice_type in sliced
	do
		
		mkdir -p ${exploration_path}/preprocessing_exploration/${slice_type}/
	
		if [ ! -e ${output_dir}_${slice_type}.feat/stats/zstat1.nii.gz ] && [ $included_blocks -gt 0 ]
		then
		
			# Delete the feat folder in case it was half complete
			rm -rf ${output_dir}_${slice_type}.feat/

			# While the output directory doesn't exist, sleep
			while [ ! -e ${output_dir}.feat/stats/zstat1.nii.gz ]
			do
				sleep 5s
			done
		
			# Now that it exists create the trimmed files for reference
		
			echo "Running stats for ${output_dir}_${slice_type}"
		
			# Run the script to trim the fMRI data and the design matrix
			input_data=${output_dir}.feat/filtered_func_data.nii.gz
			output_data=${exploration_path}/preprocessing_exploration/${slice_type}/functional${functional_run}_${analysis_type}.nii.gz
			output_ev_file=${exploration_path}/preprocessing_exploration/ev_files/functional${functional_run}_${analysis_type}_${slice_type}.txt
			input_confound_mat=${exploration_path}/preprocessing_exploration/confound_files/testing_${functional_run}_${analysis_type}.txt
			output_confound_mat=${exploration_path}/preprocessing_exploration/confound_files/testing_${functional_run}_${analysis_type}_${slice_type}.txt
		
			# Remove the outputs because it might already be created
			rm -f $output_data $output_ev_file $output_confound_mat
		
			# Run the slicing of the data and the design matrices
			matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('${subject_dir}/scripts/preprocessing_exploration/'); slice_data('${input_data}', '${output_data}', '${input_ev_file}', '${output_ev_file}', '${input_confound_mat}', '${output_confound_mat}'); exit"
		
			# Set up the fsf file with this new information
			fsf_template=${subject_dir}/fsf/preprocessing_exploration_${slice_type}.fsf.template
			fsf_output=${exploration_path}/preprocessing_exploration/fsf/functional${functional_run}_${analysis_type}_${slice_type}.fsf
			sliced_tr_number=`fslval $output_data dim4`

			temporal_derivative=0
			if [ $analysis_type == "Temporal_derivative" ]
			then
				temporal_derivative=1
			fi
			
			high_pass_cutoff=100 # Use a temporary value that you will overwrite
	
			#Replace the <> text (excludes the back slash just before the text) with the other supplied text

			# note: the following replacements put absolute paths into the fsf file. this
			#       is necessary because FEAT changes directories internally
			cat $fsf_template \
			| sed "s:<?= \$SUBJECT_PATH ?>:$subject_dir:g" \
			| sed "s:<?= \$OUTPUT_DIR ?>:${output_dir}_${slice_type}.feat:g" \
			| sed "s:<?= \$TR_DURATION ?>:$tr_duration:g" \
			| sed "s:<?= \$TR_NUMBER ?>:$sliced_tr_number:g" \
			| sed "s:<?= \$FUNCTIONAL ?>:$output_data:g" \
			| sed "s:<?= \$EV_FILE ?>:$output_ev_file:g" \
			| sed "s:<?= \$CONFOUND_MAT ?>:$output_confound_mat:g" \
			| sed "s:<?= \$HIGH_PASS_CUTOFF ?>:$high_pass_cutoff:g" \
			| sed "s:<?= \$TEMPORAL_DERIVATIVE ?>:$temporal_derivative:g" \
				> ${subject_dir}/temp_preprocessing_exploration_functional${functional_run}_${analysis_type}.fsf #Output to this file

			# Determine the high pass cut off and make the proper fsf file
			# Make the relevant design files
			feat_model ${subject_dir}/temp_preprocessing_exploration_functional${functional_run}_${analysis_type}

			# Input the design matrix into the feat
			high_pass_cutoff=`cutoffcalc --tr=$tr_number -i ${subject_dir}/temp_preprocessing_exploration_functional${functional_run}_${analysis_type}.mat`
			high_pass_cutoff=`echo $high_pass_cutoff | awk '{print $NF}'`
	
			# Remove 
			rm -rf ${subject_dir}/temp_preprocessing_exploration_functional${functional_run}_${analysis_type}*
	
			# Make the final file
			cat $fsf_template \
			| sed "s:<?= \$SUBJECT_PATH ?>:$subject_dir:g" \
			| sed "s:<?= \$OUTPUT_DIR ?>:${output_dir}_${slice_type}.feat:g" \
			| sed "s:<?= \$TR_DURATION ?>:$tr_duration:g" \
			| sed "s:<?= \$TR_NUMBER ?>:$sliced_tr_number:g" \
			| sed "s:<?= \$FUNCTIONAL ?>:$output_data:g" \
			| sed "s:<?= \$EV_FILE ?>:$output_ev_file:g" \
			| sed "s:<?= \$CONFOUND_MAT ?>:$output_confound_mat:g" \
			| sed "s:<?= \$HIGH_PASS_CUTOFF ?>:$high_pass_cutoff:g" \
			| sed "s:<?= \$TEMPORAL_DERIVATIVE ?>:$temporal_derivative:g" \
				> ${fsf_output} #Output to this file
	
			# Run the feat analyses
			if [ $slurm == 1 ]
			then
				sbatch -p $SHORT_PARTITION scripts/run_feat.sh $fsf_output	
			else
				submit_long scripts/run_feat.sh $fsf_output	
			fi	
		
		
		else
			echo Skipping ${output_dir}_${slice_type}.feat
		fi
	done
done

