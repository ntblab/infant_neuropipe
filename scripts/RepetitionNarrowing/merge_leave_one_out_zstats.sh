#!/bin/bash
#
# Merge z-stat files across participants for later use in a leave-one-out analysis 
#

participants=$1 # list of the participants' names (to pass an array in bash: use "${participants[@]}" as input)
analysis_type=$2 # which folder will you use for creating these files? Most likely, 'scene_face'
zstat_num=$3 # which zstat number? Most likely, '1', for the contrast of scenes vs. faces (note: it shows scenes > faces)

source ./globals.sh 

# where are these files going ? 
output_dir=$PROJ_DIR/data/FaceProcessing/LOO_contrast_maps/

# cycle through participants 
for loo_ppt in $participants
do
    echo 'holding out' $loo_ppt
    
    # name the file based on the left out ppt
    merged_name=${output_dir}/${loo_ppt}_merged_${analysis_type}_zstat${zstat_num}.nii.gz 
    
    # Who remains?
    remaining_ppts=${participants[@]/$loo_ppt}
    echo 'making merged file with' $remaining_ppts
    
    file_list=""
    for ppt in $remaining_ppts
    do
    
        # where is the zstat located?
        analysis_dir=${PROJ_DIR}/subjects/${ppt}/analysis/secondlevel_RepetitionNarrowing/${analysis_type}/
        filename=${analysis_dir}/RepetitionNarrowing_Z.feat/stats/zstat${zstat_num}_registered_standard.nii.gz
        
        file_list="${file_list} $filename"
    
    done
    
    # Merge them together
    echo fslmerge -t $merged_name $file_list
    fslmerge -t $merged_name $file_list

done