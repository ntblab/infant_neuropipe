#!/bin/bash
#
# Estimate the age of the participant based on the subject ID and its
# reference in Participant_Data. Then use it to select the appropriate
# standard brain This takes as an input the specification of the atlas
# type to use. At the moment, 'nihpd' and 'UNC' atlases are supported
#
# This script assumes you have masked the data to create _brain versions of the nihpd data. For instance, `fslmaths nihpd_asym_05-08_t1w.nii.gz -mas nihpd_asym_05-08_mask.nii.gz nihpd_asym_05-08_t1w_brain.nii.gz`
# Created by C Ellis 0318.
# Extended for other atlases

# Read in globals
source globals.sh &>/dev/null

# Specify the type of atlas you want to load, either 'nihpd' or 'UNC'
if [ $# -eq 0 ]
then
	atlas_type=nihpd
else
	atlas_type=$1	
fi

# Read in the text file for the participant information (which has the age)
Participant_Data=`cat $PROJ_DIR/scripts/Participant_Data.txt`

# Find the participant name and then the age
CorrectLine=0
for word in $Participant_Data
do
	# This word is the age
	if [[ $CorrectLine == 2 ]]; then
		Age=$word
		CorrectLine=0
	fi
		
	# Don't take the word immediately after the subject name, take the one after
	if [[ $CorrectLine == 1 ]]; then
		CorrectLine=2
	fi

	# Are you on the correct line
	if [[ $word == ${SUBJ} ]] && [[ $CorrectLine == 0 ]]; then
		CorrectLine=1
	fi

done

# Round the age to the nearest integer (although it doesn't do swedish rounding)
Age=`echo $Age | xargs printf "%.*f\n" 0`

# Pull out all of the time bands for the atlas type you selected and list them as an array that you can then count over. Then for each lower/upper bound pair, also have an array for the corresponding standard brain you would use
# Find all the potential standard brains
if [[ $atlas_type == nihpd ]]
then

	# Find all the potential standard brains
	if [ $Age -lt 60 ]
	then
		standards=`ls $ATLAS_DIR/nihpd_obj2_asym_nifti/nihpd_asym_??-??_t1w_brain.nii.gz`
	elif [ $Age -ge 60 ]
	then	
		standards=`ls $ATLAS_DIR/nihpd_asym_all_nifti/nihpd_asym_*-*_t1w_brain.nii.gz`
	fi
	
	# Cycle through the standards and determine if the age is within the bounds
	lower_bounds=()
	upper_bounds=()
	standards_array=()
	for standard in $standards
	do
		
		# Find the bounds for this standard brain
		age_range=${standard%_t1w*}
		age_range=${age_range#*nifti/nihpd_asym_}
		lower_bound=${age_range%-*}
		upper_bound=${age_range#*-}
		
		# Leading zeros need to be removed
		if [[ ${lower_bound:0:1} -eq 0 ]]
		then
			lower_bound=${lower_bound:1:1}
		fi
		
		if [[ ${upper_bound:0:1} -eq 0 ]]
		then
			upper_bound=${upper_bound:1:1}
		fi

		if [ $Age -ge 60 ]
		then
			# Multiply these bounds by 12 to convert them to if the other atlas is being used
		
			lower_bound=`echo $lower_bound*12 | bc`
			upper_bound=`echo $upper_bound*12 | bc`
			lower_bound=${lower_bound%.*}
			upper_bound=${upper_bound%.*}	
		fi
		
		# Store the bounds (but ignore the potentially large bounds)
		if [[ ! $lower_bound -eq 54 ]] || [[ ! $upper_bound -eq 222 ]]
		then 
			
			lower_bounds+=($lower_bound)
			upper_bounds+=($upper_bound)
		
			# Store the standards as an array
			standards_array+=($standard)
		fi
	done

elif [[ $atlas_type == UNC ]]
then
	# Specify the lower and upper bound of each age
	lower_bounds=(0 2 4 7 10 15 21 30 42 54 66)
	upper_bounds=(2 4 7 10 15 21 30 42 54 66 72)
	
	# Cycle through the participant atlases and store the appropriate folders
	standard_ages=(01 03 06 09 12 18 24 36 48 60 72)  # infant atlas folders (ages)
	standards_array=()
	for standard_age in "${standard_ages[@]}"
	do
		standards_array+=($ATLAS_DIR/UNC_4D_Infant_Cortical_Atlas/$standard_age/)	
	done

fi

# Count through the bounds in these
for bound_counter in `seq 0 ${#standards_array[@]}`
do
	# Is the age within these bounds then store it, otherwise continue
	if [[ $Age -gt ${lower_bounds[$bound_counter]} ]] && [[ $Age -le ${upper_bounds[$bound_counter]} ]]
	then
		standard_brain=${standards_array[$bound_counter]}
	fi
done

# If the appropriate brain hasn't been found then it will default to use an MNI brain in the FSL folder
if [ -z $standard_brain ]
then
	
	# Get the fsl path to the standard brains
	fsl_data=`which fsl`
	fsl_data=${fsl_data%bin*}
	fsl_data=$fsl_data/data/standard/
	
	standard_brain=$fsl_data/MNI152_T1_1mm_brain.nii.gz
fi

# Return the standard brain
echo $standard_brain
