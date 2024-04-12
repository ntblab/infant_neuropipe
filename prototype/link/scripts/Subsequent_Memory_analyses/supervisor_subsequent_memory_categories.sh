#!/bin/bash
#
# Automate the analysis of Subsequent memory categories
#
# Then it runs the feat analyses for each of these different types of analysis
# Finally, wait and then do the alignment of the statistics to the highres and standard.
#
# Assumes you are running from the subject base directory
#
# based on C Ellis 102417. 
# Edits for the categories version TY 02072020

#SBATCH --output=logs/SubMem_Categories_supervisor-%j.out
#SBATCH -p psych_day
#SBATCH -t 7:00:00
#SBATCH --mem 24000
	
# Source the globals
source ./globals.sh

# take as input whether you want to start over and remove previous versions of the analysis
remove_anyway=$1
	
# What is the root directory for the subject
subject_dir=$(pwd)

# What is the path to SubMem? 
path=${subject_dir}/analysis/secondlevel_SubMem_Categories/default/

# What is the nifti file being used? (Make it the Z-scored one!)
nifti_Z='NIFTI/func2highres_SubMem_Categories_Z.nii.gz'

# Figure out the TR number
TR_Number=`fslval ${path}${nifti_Z} dim4`

# Where does the standard image come from? 
fsl_data=`which fsl`
fsl_data=${fsl_data%bin*}
fsl_data=$fsl_data/data/standard/

# What analyses are you running? 
analysis_types=("Task" "Binary" "Parametric" "Binary_Categories" "Binary_DelayLength" "Control")

# If this analysis is of the parametric looking to familiar, make sure you have the cleaned up version of the timing file
# This script also makes additional timing files for Binary_Categories and Binary_DelayLength 
if [ ! -e ${path}/Timing/SubMem_Categories-Condition_Parametric.txt || ! -e ${path}/Timing/SubMem_Categories-Condition_Parametric_MainEffect.txt ]
then	
    echo 'creating cleaned up parametric timing file and additional timing files'
    # quickly run the script (doesn't need resources)
    python scripts/Subsequent_Memory_analyses/update_parametric_timing.py $subject_dir 'default'
    
fi

# Iterate through the different analyses types, create fsf files, and then run the feat
for analysis_type in ${analysis_types[@]}
do
	# Do you want to remove the files and start over anyways?
	if [[ $remove_anyway == 'remove' ]]
	then
		echo 'removing previous versions of feat files for ' $analysis_type
		rm -rf ${path}/SubMem_Categories_${analysis_type}.feat/
		rm -rf ${path}/SubMem_Categories_${analysis_type}_Z.feat/
	fi

    # If the initial FEAT hasn't been run (or didn't finish), then create it!
	if [ ! -e ${path}/SubMem_Categories_${analysis_type}.feat/stats/zstat1.nii.gz ]
	then
	
        # remove any partial version of the analysis
		rm -rf ${path}/SubMem_Categories_${analysis_type}.feat/
        
        # Find the template and set the output name 
		fsf_template=${subject_dir}/fsf/SubMem_Categories_${analysis_type}.fsf.template
		fsf_output=${path}/SubMem_Categories_${analysis_type}.fsf # what is the final output name
        
        # Use a temporary high pass value that you will overwrite
		high_pass_cutoff=100 
		
		#Replace the <> text (excludes the back slash just before the text) with the other supplied text
		# note: the following replacements put absolute paths into the fsf file. this
		#       is necessary because FEAT changes directories internally
		cat $fsf_template \
		| sed "s:<?= \$SUBJECT_PATH ?>:$subject_dir:g" \
		| sed "s:<?= \$TR_NUMBER ?>:$TR_Number:g" \
		| sed "s:<?= \$STANDARD_DIR ?>:$fsl_data:g" \
		| sed "s:<?= \$TR_DURATION ?>:$TR:g" \
		| sed "s:<?= \$HIGH_PASS_CUTOFF ?>:$high_pass_cutoff:g" \
			> ${subject_dir}/temp_SubMem_Categories.fsf 
		
		# Determine the high pass cut off based on the design matrix 
		feat_model ${subject_dir}/temp_SubMem_Categories
		high_pass_cutoff=`cutoffcalc --tr=2 -i ${subject_dir}/temp_SubMem_Categories.mat`
		
        # Make the relevant design files for the final template
		cat $fsf_template \
		| sed "s:<?= \$SUBJECT_PATH ?>:$subject_dir:g" \
		| sed "s:<?= \$TR_NUMBER ?>:$TR_Number:g" \
		| sed "s:<?= \$STANDARD_DIR ?>:$fsl_data:g" \
		| sed "s:<?= \$TR_DURATION ?>:$TR:g" \
		| sed "s:<?= \$HIGH_PASS_CUTOFF ?>:$high_pass_cutoff:g" \
			> ${fsf_output} #Output to this file
		
        # Actually run the analysis! 
		echo Running $fsf_output
		sbatch ./scripts/run_feat.sh $fsf_output	
		
		# Remove all the temp files associated with the design matrix
		rm -f temp_SubMem_Categories.*
	fi
    
    ## Wait until FEATs have finished and then run the z scored versions
    # Check if it is done
	waiting=1
	while [[ $waiting -eq 1 ]] 
	do 
		if  [[ -e ${path}/SubMem_Categories_${analysis_type}.feat/stats/zstat1.nii.gz ]]
		then
			waiting=0
		else
			sleep 10s
		fi
	done	
    
    # Run the z scoring if it hasn't been run yet
	if [ ! -e ${path}/SubMem_Categories_${analysis_type}_Z.feat/stats/zstat1.nii.gz ]
	then
		rm -rf ${path}/SubMem_Categories_${analysis_type}_Z.feat/
		sbatch --output=logs/feat_stats-%j.out ${subject_dir}/scripts/FEAT_stats.sh ${path}/SubMem_Categories_${analysis_type}.feat ${path}/SubMem_Categories_${analysis_type}_Z.feat ${path}/${nifti_Z}
	fi
    
done

# Wait for the z stat analyses to finish running
echo "Waiting to let the other analyses finish"
sleep 1m

# Now that all the analyses are done, make images out of the data and align to highres and standard
for processing_type in _Z.feat #.feat
do
	for analysis_type in ${analysis_types[@]}
	do
		echo Running $analysis_type
        
        # Check if z-scored version is done (it should be close to done!)
        waiting=1
        while [[ $waiting -eq 1 ]] 
        do 
            if  [[ -e ${path}/SubMem_Categories_${analysis_type}_Z.feat/stats/zstat1.nii.gz ]]
            then
                waiting=0
            else
                sleep 10s
            fi
        done

        # Set the feat directory and min and max z values
		feat_dir=${path}/SubMem_Categories_${analysis_type}${processing_type}/
		zmin=2.3
		zmax=3
		
		# Remove files that might have been created by this
		rm -rf ${feat_dir}/stats/zstat*_*
		rm -f ${feat_dir}/stats/*png

		zstat_files=`ls ${feat_dir}/stats/zstat*.nii.gz`

		# Iterate through the zstat maps that were created, making images, and aligning the images
		for stat_maps in $zstat_files
		do
			${subject_dir}/scripts/align_stats.sh $stat_maps $zmin $zmax 1
		done
	
	done
done

echo Finished
