#!/usr/bin/env bash
# Run ashs model for hippocampal segmentation of infant data
#
#SBATCH --output=logs/supervisor_ashs-%j.out
#SBATCH -p psych_day
#SBATCH -t 350
#SBATCH --mem 5000

participants=$1 # list of the participants' names (to pass an array in bash: use "${participants[@]}" as input)

# source globals
source globals.sh

########
# Define where ASHS is and what model you want to use
# First, download the ASHS code base at: https://www.nitrc.org/projects/ashs (we used v1.0.0)
# We used an infant-trained ASHS model described in: Fel, J. T., Ellis, C. T., & Turk-Browne, N. B. (2023). Automated and manual segmentation of the hippocampus in human infants. Developmental Cognitive Neuroscience, 60, 101203.
# Download the infant-trained ASHS model here: https://datadryad.org/stash/dataset/doi:10.5061/dryad.05qfttf6z
ASHS_ROOT=$ASHS_ROOT 
ASHS_MODEL=${PROJ_DIR}/data/MTL_Segmentations/infant_trained_ASHS/ashs_infant_trained/final
########

# cycle through the participants 
for sub in $participants
do 
    echo $sub
    
    # set some paths 
    hpc_dir=${PROJ_DIR}/subjects/${sub}/analysis/secondlevel/${sub}_hippocampus_standard/final
    ants_reg_dir=${PROJ_DIR}/subjects/${sub}/analysis/secondlevel/registration_ANTs/
    
    # Check if we have already run ASHS for this subject
    if [ -d $hpc_dir ]
    then
        echo 'already ran ASHS - copying over the segmentations to data folder'
        
        # first separate all of the hpc and mtl ROIs from the outputs 
        fslmaths ${PROJ_DIR}/${sub}_right_lfseg_corr_nogray.nii.gz -thr 6 -uthr 6 -bin ${hpc_dir}/${sub}_right_hpc.nii.gz
        fslmaths ${PROJ_DIR}/${sub}_right_lfseg_corr_nogray.nii.gz -thr 4 -uthr 4 -bin ${hpc_dir}/${sub}_right_mtl.nii.gz
        fslmaths ${PROJ_DIR}/${sub}_left_lfseg_corr_nogray.nii.gz -thr 5 -uthr 5 -bin ${hpc_dir}/${sub}_left_hpc.nii.gz
        fslmaths ${PROJ_DIR}/${sub}_left_lfseg_corr_nogray.nii.gz -thr 3 -uthr 3 -bin ${hpc_dir}/${sub}_left_mtl.nii.gz
        
        # Then copy them into the shared data folder
        scp ${hpc_dir}/${sub}_right* ${PROJ_DIR}/data/SubMem/segmentations
        scp ${hpc_dir}/${sub}_left* ${PROJ_DIR}/data/SubMem/segmentations
        
    # If not, we will run it! 
    else
        echo 'running ashs on the highres_original file (in standard space)'

        # run ASHS on this participant, supplying the highres2standard image as both the T1 and T2
        sbatch ${ASHS_ROOT}/run_ashs.sh -I ${sub} -a ${ASHS_MODEL} -g ${ants_reg_dir}/highres2standard.nii.gz -f ${ants_reg_dir}/highres2standard.nii.gz -w ${PROJ_DIR}/subjects/${sub}/analysis/secondlevel/${sub}_hippocampus_standard -T

    fi

done
