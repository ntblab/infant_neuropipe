#!/bin/bash
#
# Re-run prep_raw_data, render-fsf-templates, and FEAT_firstlevel with different motion parameters to create new confound files at the first level. This code does something similar to the files in the preprocessing_exploration folder, but specifically looks at motion parameters. Additionally, instead of running a GLM for task vs. rest, this script will use the default first level fsf template just to perform preprocessing.
#
# The primary use of this script was to explore how motion parameters influence movie and resting state functional connectivity, but can be applied to other types of tasks as well
#
# Before running this script, you are assumed to have already completed the normal infant_neuropipe pipeline up to at least manually aligning all of the functional runs to the subjects' highres (up to Post-Prestats)
#
# example call: sbatch ./scripts/explore_motion_firstlevel functional01 petra01_brain
#
#SBATCH --output=logs/explore_motion_firstlevel-%j.out
#SBATCH -p psych_day
#SBATCH -t 3:00:00
#SBATCH --mem 20G 
#SBATCH -n 1

# Source globals and set the subject directory
source globals.sh
subject_dir=`pwd`

# Get the inputs
functional_run=$1 # which functional run are you exploring? e.g., functional_01
anatomical=$2 # which anatomical image are you using from data/nifti folder? e.g., petra01_brain

# These are the motion thresholds we will explore
fslmotion_thresholds="0.2"

PCA_Threshold="0" # just set this to be 0
interpolation=nearestneighbour # interpolation method we use

# If this is a pseudorun of data then specify the repo to be used for finding the file
functional_run_number=${functional_run#functional}
if [[ ${#functional_run_number} -gt 2 ]]
then
	pseudorun_data="data_dir analysis/firstlevel/pseudorun/"
	prep_run_numbers=1:100
else
	pseudorun_data=''
    prep_run_numbers=$functional_run_number
fi

# If there is a match to a string in the run burn in then specify that number here
Burn_in_TRs=3 # Default number
if [ -e analysis/firstlevel/run_burn_in.txt ]
then
	burn_in_txt=`cat analysis/firstlevel/run_burn_in.txt`
	next_word=0
	for word in $burn_in_txt
	do	

		# If this word was marked as the burn in word
		if [[ $next_word -eq 1 ]]
		then
			next_word=0
			Burn_in_TRs=$word
		fi
		
		# Is this word for a burn in
		if [[ $word == $functional_run ]]
		then
			next_word=1
		fi
	done
fi

for fslmotion_threshold in $fslmotion_thresholds
do
    # set the suffix for the files that will get created
    suffix=_fslmotion_thr${fslmotion_threshold}
    
    # If this is a pseudorun of data you need a special suffix for render-fsf-templates
    if [[ ${#functional_run_number} -gt 2 ]]
    then
        pseudorun_suffix="pseudorun_${suffix}"
    else
        pseudorun_suffix=$suffix
    fi

    ################################################
    ###### Step 1: Run prep_raw_data with the given motion parameter

    # Check if these parameters have already been generated
    file=analysis/firstlevel/Confounds/OverallConfounds_${functional_run}_fslmotion_thr${fslmotion_threshold}.txt

	if [ ! -e $file ]
	then
		echo Creating $file by running prep_raw_data
        
        sbatch ./scripts/run_prep_raw_data.sh [7,8] ${prep_run_numbers} $Burn_in_TRs mahal_threshold $PCA_Threshold fslmotion_threshold $fslmotion_threshold $pseudorun_data suffix _fslmotion_thr${fslmotion_threshold}

	else
		echo $file has been created, skipping prep_raw_data step
	fi
    
    ################################################
    ###### Step 2: Render the fsf-template
    
    # Check if file has been created
    waiting=1
    while [[ $waiting -eq 1 ]] 
    do 
        if  [ ! -e ${file} ]
        then
            sleep 10s
        else
            waiting=0
        fi
    done
    
    if [ ! -e ${subject_dir}/analysis/firstlevel/${functional_run}${suffix}.fsf ]
	then

        # figure out what the reference anatomical is 
        standard_brain=`scripts/age_to_standard.sh`

        # can be run without submitting as a job
        ./scripts/render-fsf-templates.sh ${subject_dir}/data/nifti/${SUBJ}_${anatomical}.nii.gz $standard_brain $pseudorun_suffix
        
         # But actually, we want to do motion correction based on the original example_func, since this is what we have registered to the highres volume. So we will edit that line real quick 
         
         # find the line we want to edit 
         line=`sed -n "/# What is the example_func to be used/=" ${subject_dir}/analysis/firstlevel/${functional_run}${suffix}.fsf`
         line=$((line+1))
         
         # remove what was there before...
         sed -i "${line}d" ${subject_dir}/analysis/firstlevel/${functional_run}${suffix}.fsf
 
         # we have to add quotation marks to the name of the example func we are using 
         original_example_func='"'${subject_dir}/analysis/firstlevel/Confounds/example_func_${functional_run}.nii.gz'"'
         
         # then add the default example_func to that line
         sed -i "${line}i set example_func_files(1) ${original_example_func}" ${subject_dir}/analysis/firstlevel/${functional_run}${suffix}.fsf

    else
        echo ${subject_dir}/analysis/firstlevel/${functional_run}${suffix}.fsf has been created, skipping render-fsf-templates step
    fi

    
    ################################################
    ###### Step 3: Run FEAT_firstlevel
    featFolder=${subject_dir}/analysis/firstlevel/${functional_run}${suffix}.feat
     
    if [ ! -e $featFolder/filtered_func_data.nii.gz ]
	then
        # delete the half-made feat folder
        rm -rf $featFolder/
        
        # run the script! 
        sbatch ./scripts/FEAT_firstlevel.sh  ${subject_dir}/analysis/firstlevel/${functional_run}${suffix}.fsf
    else
        echo feat folder exits, skipping
    fi
    
    ################################################
    ###### Step 4: Create the aligned_highres using registrations from the default feat folder (code from Post-PreStats)
    
    # Check if file has been created
    waiting=1
    while [[ $waiting -eq 1 ]] 
    do 
        if  [ ! -e $featFolder/filtered_func_data.nii.gz ]
        then
            sleep 10s
        else 
            waiting=0
        fi
    done
    
    if [ ! -e $featFolder/aligned_highres/func2highres.nii.gz ]
    then
    
        echo Copying over the registration from the default for this functional and applying it to the filtered func data. This will only work if manual registration has already been run. Please check that it worked!! 
	echo NOTE: this also means that the registration is using the centroid TR for the default motion parameter for registration -- regardless of whether it is usable at this motion threshold

        # Now copy over the registration files from the default 
        rm -rf ${featFolder}/reg/
        cp -r ${subject_dir}/analysis/firstlevel/${functional_run}.feat/reg/ ${featFolder}/
        mkdir -p ${featFolder}/aligned_highres

        TotalTRs=`fslval $featFolder/filtered_func_data.nii.gz dim4`
        voxel_size=`fslval $featFolder/filtered_func_data.nii.gz pixdim1`

        #Realign the functionals
        flirt -in $featFolder/filtered_func_data.nii.gz -applyisoxfm $voxel_size -init $featFolder/reg/example_func2highres.mat -out $featFolder/aligned_highres/func2highres_unmasked.nii.gz -ref $featFolder/reg/highres.nii.gz -interp $interpolation

        #Create a new mask based on this newly registered volume
        flirt -in $featFolder/mask.nii.gz -applyisoxfm $voxel_size -init $featFolder/reg/example_func2highres.mat -out $featFolder/aligned_highres/mask2highres.nii.gz -ref $featFolder/reg/highres.nii.gz -interp $interpolation

        # mask the functional 
        fslmaths $featFolder/aligned_highres/func2highres_unmasked.nii.gz -mas $featFolder/aligned_highres/mask2highres.nii.gz $featFolder/aligned_highres/func2highres.nii.gz
        
    else
        echo already created aligned functional
        
    fi
    echo
    
done
