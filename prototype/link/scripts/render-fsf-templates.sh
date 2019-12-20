#!/bin/bash
#
# render-fsf-templates.sh fills in templated fsf files so FEAT can use them
# This just looks for matches of certain keys, if only some of them are found in the template file then only those ones will be changed.
#
# First input the highres path and the second input is the standard. By default these will figure out an appropriate value but not perfect
# Third input is the suffix to save the fsf file with (can also alter the default parameters, such as smoothing or srm)
# Fourth input is the path to the fsf file you want to use as a template. Hence you could alter the template to match your demands (e.g. adding field map correction) and then use these find replace steps to do the rest
# 
# To edit the defaults find the section within the 'run' loop called 'SET DEFAULTS HERE' 
#
# Edited by C Ellis 0616. Added the functionality to make a template for each functional. Inputs are the paths to the standards


set -e

source globals.sh

#What is the root directory for the subject
subject_dir=$(pwd)

#What high res file are you loading
if [ $# -eq 0 ] || [ $1 == None ]
then
	highres_file=$subject_dir/$NIFTI_DIR/${SUBJ}_petra01_brain.nii.gz
	echo "No argument supplied. Assuming highres is ${highres_file}"
else
	highres_file=$1
fi

# What is the standard brain you will use?
if [ $# -lt 2 ] || [ $2 == None ]
  then
	
	standard_brain=`scripts/age_to_standard.sh`
	echo "No argument supplied. Assuming standard is ${standard_brain}"
else
	standard_brain=$2 #Set as the input
fi

# Take in a suffix name for the fsf files to be created

if [ $# -lt 3 ] || [ $3 == None ]
then
	suffix=''
else
	suffix=$3
	echo Using $suffix to name feats
fi

# What template fsf file will you use?
if [ $# -lt 4 ] || [ $4 == None ]
then
	fsf_template=$FSF_DIR/firstlevel.fsf.template
else
	fsf_template=$4
	echo Using $fsf_template as the template fsf file
fi

# If a suffix is that you are doing this on pseudorun files then refer to a different folder for the nifti files
if [[ $suffix == "pseudorun" ]]
then
	NIFTI_DIR=analysis/firstlevel/pseudorun/
	suffix="" # Delete evidence of this suffix now
fi

#What are the file names?
Files=`ls -d $NIFTI_DIR/${SUBJ}_functional*.nii.gz` 

#Iterate through the functionals
RunNames=''
for word in $Files
do
	 # Pull out the run name
	 RunName=${word#*${SUBJ}_}
	 RunName=${RunName%.nii.gz}
	 
	 # Append it to the list
	 RunNames="$RunNames $RunName"
done

# Identify the file containing the run files
if [ -e analysis/firstlevel/run_burn_in.txt ]
then
	run_burn_in_file=`cat analysis/firstlevel/run_burn_in.txt`
else
	run_burn_in_file=''
fi

for RunName in $RunNames
do
	
	######### SET DEFAULTS HERE ##########
	# Set here in order to reset for each run	
	# Apart from burn in, these can all be edited by adding a suffix as an input

	run_burn_in=3  # How many TRs before the block begins
	interpolation=1  # Do you want to interpolate TRs that contain confounds so that they don't skew the detrending
	sfnrmask=1  # Do you want to use the sfnr values as the threshold to decide brain from nonbrain voxels
	smoothing=5  # What is the FWHM of the smoothing kernel to be used
	despiking=1  # Should 3dDespike be used on the data
	melodic=0  # Should melodic be run on the data
	ica_corr_thresh=0.5  # If melodic is run on the data, what threshold should you use for excluding components that are correlated with motion
	
	######################################

	### Overwrite the default parameters based on the 

	# How many burn in TRs are there
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
		
		if [[ $word == $RunName ]]
		then
			Correct_word=1
		fi
	done

	# If it has this suffix then update
	if [[ $suffix == *"_smoothing"* ]]
	then
		smoothing=${suffix#*_smoothing}
		smoothing=${smoothing%%_*}
		echo Setting smoothing to $smoothing
	fi
	if [[ $suffix == *"_despiking"* ]]
	then
		despiking=${suffix#*_despiking}
		despiking=${despiking%%_*}
		echo Setting despiking to $despiking
	fi
	if [[ $suffix == *"_melodic"* ]]
	then
		melodic=${suffix#*_melodic}
		melodic=${melodic%%_*}
		echo Setting melodic to $melodic
	fi
	if [[ $suffix == *"_ica_corr_thresh"* ]]
	then
		ica_corr_thresh=${suffix#*_ica_corr_thresh}
		ica_corr_thresh=${ica_corr_thresh%%_*}
		echo Setting ica_corr_thresh to $ica_corr_thresh
	fi
	if [[ $suffix == *"_sfnrmask"* ]]
	then
		sfnrmask=${suffix#*_sfnrmask}
		sfnrmask=${sfnrmask%%_*}
		echo Setting sfnrmask to $sfnrmask
	fi
	if [[ $suffix == *"_interpolation"* ]]
	then
		interpolation=${suffix#*_interpolation}
		interpolation=${interpolation%%_*}
		echo Setting interpolation to $interpolation
	fi
	
	### Get run specific information
	
	#Find the TR length and the number of TRs
	TR_Duration=`fslval $NIFTI_DIR/${SUBJ}_${RunName}.nii.gz pixdim4`
	TR_Number=`fslval $NIFTI_DIR/${SUBJ}_${RunName}.nii.gz dim4`
	
	#Is the TR duration in seconds or milliseconds?
	inSeconds=`echo $TR_Duration '<' 100 | bc -l`
	if [ $inSeconds -eq 0 ]
	then
		#Divide this number by 1000 to get it in seconds, remove some of the decimal places
		TR_Duration=`echo "$TR_Duration / 1000" | bc -l`
	fi
	TR_Duration=${TR_Duration:0:4}
	
	output_dir=$PRESTATS_DIR/${RunName}${suffix}.feat
	data_file_prefix=$NIFTI_DIR/${SUBJ}_${RunName}
	output_fsf=$PRESTATS_DIR/${RunName}${suffix}.fsf
	
	# Create the fsf file, unless it has already been excluded
	if [ ! -e $PRESTATS_DIR/${RunName}${suffix}_excluded_run.fsf ]
	then
		#Replace the <> text (excludes the back slash just before the text) with the other supplied text
		# note: It is necessary to use absolute paths because FEAT changes directories internally
		cat $fsf_template \
		| sed "s:<?= \$SUBJ_DIR ?>:$subject_dir:g" \
		| sed "s:<?= \$SUBJ ?>:$SUBJ:g" \
		| sed "s:<?= \$RUN_NAME ?>:$RunName:g" \
		| sed "s:<?= \$OUTPUT_DIR ?>:$subject_dir/$output_dir:g" \
		| sed "s:<?= \$TR_NUMBER ?>:$TR_Number:g" \
		| sed "s:<?= \$TR_DURATION ?>:$TR_Duration:g" \
		| sed "s:<?= \$RUN_BURN_IN ?>:$run_burn_in:g" \
		| sed "s:<?= \$SFNR_MASKING ?>:$sfnrmask:g" \
		| sed "s:<?= \$SMOOTHING_PARAMETER ?>:$smoothing:g" \
		| sed "s:<?= \$CONFOUND_INTERPOLATION ?>:$interpolation:g" \
		| sed "s:<?= \$DESPIKING ?>:$despiking:g" \
		| sed "s:<?= \$MELODIC ?>:$melodic:g" \
		| sed "s:<?= \$ICA_CORR_THRESH ?>:$ica_corr_thresh:g" \
		| sed "s:<?= \$STANDARD_BRAIN ?>:$standard_brain:g" \
		| sed "s:<?= \$DATA_FILE_PREFIX ?>:$subject_dir/$data_file_prefix:g" \
		| sed "s:<?= \$EXAMPLE_FUNC_FILE ?>:$subject_dir/$PRESTATS_DIR/Confounds/example_func_${RunName}.nii.gz:g" \
		| sed "s:<?= \$CONFOUND_FILE ?>:$subject_dir/$PRESTATS_DIR/Confounds/OverallConfounds_${RunName}.txt:g" \
		| sed "s:<?= \$HIGHRES_FILE ?>:$highres_file:g" \
			> $output_fsf #Output to this file
	else
		echo "$PRESTATS_DIR/${RunName}${suffix}_excluded_run.fsf exists so not creating a new fsf file"
	fi
done

# Make a copy of the original (albeit masked) highres in secondlevel for use later
highres_original=${highres_file%_*}_masked.nii.gz
if [ -e $highres_original ]
then
 cp $highres_original $REGCONCAT_DIR/highres_original.nii.gz
else
 echo "Could not find $highres_original. Not saving as $REGCONCAT_DIR/highres_original.nii.gz"
fi
