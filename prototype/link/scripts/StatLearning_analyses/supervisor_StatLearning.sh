#!/bin/bash
#
# Automate the analysis of StatLearning
#
# This script first sets up all of the timing files using the './scripts/change_timing_file_columns.m' script
# Then the script runs the feat analyses for each of these different types of comparison
# Do the z scoring of the data
# Finally, wait and then do the alignment of the statistics to the highres and standard.
#
# Assumes you are running from the subject base directory.
#
# Can provide a second level name to do it in a place other than the default folder
#
# Example command:
# sbatch scripts/StatLearning/supervisor_StatLearning.sh seen_count 1
#
# C Ellis 080317. 

#SBATCH --output=logs/StatLearning_Supervisor-%j.out
#SBATCH -p short
#SBATCH -t 240
#SBATCH --mem 16000

# Source the globals
source ./globals.sh

# Determine where to run these analyses	
if [ "$#" -ge 1 ]
then
secondlevelname=$1
else
secondlevelname=default
fi

# Do you want to base the block counterbalancing on the original chronological order or the seen order?
if [ "$#" -ge 2 ]
then
    is_seen_order=$2
else
    is_seen_order=1
fi

# What is the root directory for the subject
subject_dir=$(pwd)

# What is the path to StatLearning
statlearning_path="analysis/secondlevel_StatLearning/${secondlevelname}/"

# What is the nifti file being used
nifti_Z='NIFTI/func2highres_StatLearning_Z.nii.gz'

# Update the name for this if appropriate
if [[ $is_seen_order == 1 ]]
then
    name_suffix="-seen"
else
    name_suffix=""
fi

# Make the metric and confound files for a more strict motion threshold for reference
threshold=1
./scripts/motion_parameter2confound_file.sh analysis/secondlevel_StatLearning/${secondlevelname}/Confounds/MotionParameters.txt ${threshold} analysis/secondlevel_StatLearning/${secondlevelname}/Confounds/Motion_thr${threshold}

# Do it for each block
blocks=`ls analysis/secondlevel_StatLearning/${secondlevelname}/Confounds/MotionParameters_*`
for block in $blocks
do
    run_name=${block#*functional}
    run_name=${run_name%.txt}

    # Run for each block
    ./scripts/motion_parameter2confound_file.sh $block $threshold analysis/secondlevel_StatLearning/${secondlevelname}/Confounds/Motion_thr${threshold}_${run_name}
done



echo Using $name_suffix as our suffix

# What feat analyses are you running
analysis_types="Interaction${name_suffix} Block_regressor${name_suffix}"

## Make all the timing files

# Cycle through the analysis types
for analysis_type in half1 half2 Block_regressor
do

    # Cycle through the conditions
    for Condition in Structured Random 
    do

        input=${statlearning_path}/Timing/StatLearning-${Condition}_Only.txt
        output=${statlearning_path}/Timing/StatLearning-${Condition}_${analysis_type}${name_suffix}.txt

        if [[ $is_seen_order == 0 ]]
        then

            # Set up the values and columns to be changes
            blocks=`cat $input | wc -l`
            if [[ ${analysis_type} == Slope ]]
            then
                column=3
                value=slope		

            elif [[ ${analysis_type} == FIR ]]
            then
                column=2
                value=1

            elif [[ ${analysis_type} == half1 ]]
            then

                column=3

                # Take either first two or three lines
                end_block=`echo $blocks / 2 | bc`

                value='['
                for block_counter in `seq 1 $blocks`
                do
                    if [[ $block_counter -le $end_block ]]
                    then
                        value="${value}1,"
                    else
                        value="${value}0,"
                    fi	
                done	
                value="${value}]"	
            elif [[ ${analysis_type} == half2 ]]
            then

                column=3

                end_block=`echo $blocks / 2 | bc`
                start_block=`echo $end_block + 1 | bc`

                value='['
                for block_counter in `seq 1 $blocks`
                do

                    if [[ $block_counter -ge $start_block ]]
                    then
                        value="${value}1,"
                    else
                        value="${value}0,"
                    fi
                done
                value="${value}]"	

            elif [[ ${analysis_type} == Intercept-exclude ]]
            then

                column=3

                value='[0,' # Exclude the first block
                for block_counter in `seq 2 $blocks`
                do
                    value="${value}1,"
                done
                value="${value}]"
            fi

            # Run the matlab function
            matlab -nodesktop -nosplash -nojvm -nodisplay -r "addpath scripts; change_timing_file_columns('$input','$output','$value',$column); exit;"
        else

            # Make the timing files based on the seen order (as described in the block_order.txt file
            matlab -nodesktop -nosplash -nojvm -nodisplay -r "addpath scripts/StatLearning_analyses/; generate_seen_counterbalancing_timing_files('$input','$output'); exit"

        fi
    done
done

# Make the first half and second half files by combining across condition
cat ${statlearning_path}/Timing/StatLearning-*_half1${name_suffix}.txt > ${statlearning_path}/Timing/StatLearning_half1${name_suffix}.txt
cat ${statlearning_path}/Timing/StatLearning-*_half2${name_suffix}.txt > ${statlearning_path}/Timing/StatLearning_half2${name_suffix}.txt

## Run the feats
TR_Number=`fslval ${statlearning_path}${nifti_Z} dim4`
fsl_data=`which fsl`
fsl_data=${fsl_data%bin*}
fsl_data=$fsl_data/data/standard/

# Iterate through the fsf files, create them and then run the feat
for analysis_type in $analysis_types
do

    fsf_template=fsf/StatLearning_${analysis_type}.fsf.template

    if [ ! -e ${statlearning_path}/StatLearning_${analysis_type}${name_suffix}.feat/stats/zstat1.nii.gz ]
    then
        rm -rf ${statlearning_path}/StatLearning_${analysis_type}${name_suffix}.feat/
        fsf_output=${statlearning_path}/StatLearning_${analysis_type}${name_suffix}.fsf
        high_pass_cutoff=100 # Use a temporary value that you will overwrite

        #Replace the <> text (excludes the back slash just before the text) with the other supplied text

        # note: the following replacements put absolute paths into the fsf file. this
        #       is necessary because FEAT changes directories internally
        cat $fsf_template \
        | sed "s:<?= \$SUBJECT_PATH ?>:$subject_dir:g" \
        | sed "s:<?= \$NAME_SUFFIX ?>:$name_suffix:g" \
        | sed "s:<?= \$SECONDLEVEL_NAME ?>:$secondlevelname:g" \
        | sed "s:<?= \$STANDARD_DIR ?>:$fsl_data:g" \
        | sed "s:<?= \$TR_DURATION ?>:$TR:g" \
        | sed "s:<?= \$TR_NUMBER ?>:$TR_Number:g" \
        | sed "s:<?= \$HIGH_PASS_CUTOFF ?>:$high_pass_cutoff:g" \
            > ${subject_dir}/temp_StatLearning.fsf #Output to this file

        # Determine the high pass cut off and make the proper fsf file
        # Make the relevant design files
        feat_model ${subject_dir}/temp_StatLearning

        # Input the design matrix into the feat
        high_pass_cutoff=`cutoffcalc --tr=2 -i ${subject_dir}/temp_StatLearning.mat`

        # In case there are any errors, only take the last word
        high_pass_cutoff=`echo $high_pass_cutoff | awk '{print $NF}'`

        cat $fsf_template \
        | sed "s:<?= \$SUBJECT_PATH ?>:$subject_dir:g" \
        | sed "s:<?= \$NAME_SUFFIX ?>:$name_suffix:g" \
        | sed "s:<?= \$SECONDLEVEL_NAME ?>:$secondlevelname:g" \
        | sed "s:<?= \$STANDARD_DIR ?>:$fsl_data:g" \
        | sed "s:<?= \$TR_DURATION ?>:$TR:g" \
        | sed "s:<?= \$TR_NUMBER ?>:$TR_Number:g" \
        | sed "s:<?= \$HIGH_PASS_CUTOFF ?>:$high_pass_cutoff:g" \
            > ${fsf_output} #Output to this file


        sbatch scripts/run_feat.sh $fsf_output	

        # Remove all the temp files associated with the design matrix
        rm -f temp_StatLearning.*
    fi
done

# Perform registration of the standard masks to the example_func. Necessary for FIR
masks=`ls $ATLAS_DIR/masks`
for mask in $masks
do
	flirt -in $ATLAS_DIR/masks/${mask} -ref ${subject_dir}/analysis/secondlevel/registration.feat/reg/example_func.nii.gz -applyxfm -init ${subject_dir}/analysis/secondlevel/registration.feat/reg/standard2example_func.mat -out ${subject_dir}/analysis/secondlevel/registration.feat/reg/${mask%_MNI_1mm.nii.gz}_example_func_mask.nii.gz
done

# Perform registration of the manually segmented mask to the example_func.
# The values of this mask are as follows:
# Left MTL: 3
# Right MTL: 4
# Left HPC: 5
# Right HPC: 6

mask_vals="3 4 5 6"
masks=`ls $subject_dir/data/masks/*-*.nii.gz` # Looking only for masks with a hyphen since that defines the name
for mask in $masks
do

    # Get the coder na,e
    Coder=`echo ${mask##*-}`
    Coder=`echo ${Coder%.nii.gz}`

    # Loop through the different mask values and get the mask name
    for mask_val in $mask_vals
    do

        # Get the name for this label
        if [ $mask_val -eq 3 ]
        then
            mask_val_name="l_MTL"
        elif [ $mask_val -eq 4 ]
        then
            mask_val_name="r_MTL"
        elif [ $mask_val -eq 5 ]
        then
            mask_val_name="l_HPC"
        elif [ $mask_val -eq 6 ]
        then
            mask_val_name="r_HPC"
        fi

        # What will the output be called
        output_name=${subject_dir}/analysis/secondlevel/registration.feat/reg/${Coder}_${mask_val_name}_example_func_mask.nii.gz

        # Make a temporary mask
        fslmaths $mask -thr $mask_val -uthr $mask_val -bin ${subject_dir}/temp_mask.nii.gz

        # Flip the transformation matrix
        convert_xfm -omat ${subject_dir}/analysis/secondlevel/registration.feat/reg/highres2example_func.mat -inverse ${subject_dir}/analysis/secondlevel/registration.feat/reg/example_func2highres.mat

        # Align this mask
        flirt -in $subject_dir/temp_mask.nii.gz -ref ${subject_dir}/analysis/secondlevel/registration.feat/reg/example_func.nii.gz -applyxfm -init ${subject_dir}/analysis/secondlevel/registration.feat/reg/highres2example_func.mat -out $output_name -interp nearestneighbour	

        # Binarize mask again after the shift
        fslmaths $output_name -bin $output_name

        echo "Making $output_name"

        # Remove the temp file
        rm -f ${subject_dir}/temp_mask.nii.gz
    done

    # Transform the whole mask into the example func space

    mask_name=`echo ${mask##*/}`
    mask_name=`echo ${mask_name%.nii.gz}`
    output_name=${subject_dir}/analysis/secondlevel/registration.feat/reg/${mask_name}_example_func.nii.gz
    flirt -in $mask -ref ${subject_dir}/analysis/secondlevel/registration.feat/reg/example_func.nii.gz -applyxfm -init ${subject_dir}/analysis/secondlevel/registration.feat/reg/highres2example_func.mat -out $output_name -interp nearestneighbour

done


## Wait until FEATs have finished and then run the z scored versions

# Specify which functions are running
echo "Wait for all the jobs to run"
all_running=1

# Introduced in bash 4, doesnt work on rondo
declare -A analysis_running
for analysis_type in $analysis_types
do
    analysis_running+=(["$analysis_type"]=1)
done

while [[ $all_running == 1 ]]
do

    # cycle through analyses
    for analysis_type in $analysis_types
    do

        # Is this analysis still running? If not then run the z score function
        if [[ ${analysis_running[$analysis_type]} == 1 ]] && [[ -e ${subject_dir}/${statlearning_path}/StatLearning_${analysis_type}.feat/stats/zstat1.nii.gz ]]
        then

            # Make sure this analysis is not re run
            unset analysis_running[$analysis_type] # Delete the key
            analysis_running[$analysis_type]=0 # Set key value

            # Run the z scoring
            if [ ! -e ${statlearning_path}/StatLearning_${analysis_type}_Z.feat/stats/zstat1.nii.gz ]
            then
                rm -rf ${statlearning_path}/StatLearning_${analysis_type}_Z.feat/
                echo "Starting ${statlearning_path}/StatLearning_${analysis_type}_Z.feat/"
                sbatch --output=logs/feat_stats-%j.out ${subject_dir}/scripts/FEAT_stats.sh ${subject_dir}/${statlearning_path}/StatLearning_${analysis_type}.feat ${subject_dir}/${statlearning_path}/StatLearning_${analysis_type}_Z.feat ${subject_dir}/${statlearning_path}/${nifti_Z}
            fi	
        fi
    done

    # Check if all are done by first setting the all_running to zero and then update it to 1 if any are still running
    all_running=0
    for analysis_type in $analysis_types
    do
        if [[ ${analysis_running[$analysis_type]} == 1 ]]
        then
            all_running=1
        fi
    done

    # Wait a little
    sleep 10s

done

# Wait for the Feat_stats to delete the stats folder
sleep 5m

echo "Finished waiting"

## Now that all the analyses are done, make images out of the data
echo "Aligning data to highres and standard"
for analysis_type in $analysis_types
do
    
    analysis_type=analysis_type${name_suffix}_Z
    
    echo "Aligning ${analysis_type}"

    feat_dir=${subject_dir}/${statlearning_path}/StatLearning_${analysis_type}.feat/

    # Until this variable hasn't been created, wait
    while [ ! -e ${feat_dir}/stats/zstat1.nii.gz ]
    do
        sleep 10s
    done

    # Remove files that might have been created by this
    rm -f ${feat_dir}/stats/zstat*_*
    rm -f ${feat_dir}/stats/*png

    zstat_files=`ls ${feat_dir}/stats/zstat*`
    zmin=2.3
    zmax=3

    # Iterate through the zstat maps that were created
    for stat_maps in $zstat_files
    do
        sbatch ${subject_dir}/scripts/align_stats.sh $stat_maps $zmin $zmax
    done

done

echo "Finished"
exit
