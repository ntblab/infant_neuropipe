#!/bin/bash
#
# Generate the intersect mask for sub mem categories subjects
participants=$1 # list of the participants' names (to pass an array in bash: use "${participants[@]}" as input)
analysis_type=$2  # which analysis will you use for creating the intersect? it will not matter -- so just use 'Task' by default
suffix=$3 # if you want a suffix for the intersect mask (e.g., if you only used the intersect of a subset of participants) -- if not desired, supply ''

# source the globals
source globals.sh

# What are we naming the mask?
mask_name=$PROJ_DIR/data/SubMem/intersect_mask_standard${suffix}.nii.gz

# how many participants? 
ppt_num=`echo $participants | wc -w`
echo Making $mask_name with $ppt_num participants

# Remove the intersect that already exists 
rm -f $mask_name

# cycle through the participants
for ppt in $participants
do
    echo $ppt
    
    # what zstat will be used for creating the intersect?
    zstat_file=SubMem_Categories_${analysis_type}_Z.feat/stats/zstat1_registered_standard.nii.gz
   
    # data file for this subject
    data=${PROJ_DIR}/subjects/${ppt}/analysis/secondlevel_SubMem_Categories/default/${zstat_file}

    # Take only a single TR
    fslroi $data temp.nii.gz 0 1

    # Merge or create the mask
    if [ -e $mask_name ]
    then
        fslmerge -t $mask_name $mask_name temp.nii.gz
    else
        cp temp.nii.gz $mask_name
    fi

done

# Remove intermediate file
rm -f temp.nii.gz

# Average the data across time
fslmaths $mask_name -abs -thr 0 -bin -Tmean -thr 1 -bin $mask_name

exit


