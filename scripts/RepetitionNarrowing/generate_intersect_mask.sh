#!/bin/bash
#
# Generate the intersect mask for repetition narrowing subjects

participants=$1 # list of the participants' names (to pass an array in bash: use "${participants[@]}" as input)
analysis_type=$2 # which folder will you use for creating the intersect? Most likely, 'human_pairs'
suffix=$3 # if you want a suffix for the intersect mask (e.g., if you only used the intersect of a subset of participants) -- if not desired, supply ''

# source the globals
source globals.sh

mkdir -p $PROJ_DIR/data/FaceProcessing/ROIs/
mask_name=$PROJ_DIR/data/FaceProcessing/ROIs/intersect_mask_standard${suffix}.nii.gz

ppt_num=`echo $participants | wc -w`
echo Making $mask_name with $ppt_num participants

# Remove the intersect that already exists 
rm -f $mask_name

for ppt in $participants
do
    echo $ppt
    
    # what zstat will be used for creating the intersect?
    zstat_file=RepetitionNarrowing_Z.feat/stats/zstat1_registered_standard.nii.gz
   
    # data file for this subject
    data=${PROJ_DIR}/subjects/${ppt}/analysis/secondlevel_RepetitionNarrowing/${analysis_type}/${zstat_file}

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

# Then make the masks for the different ROIs that we care about 
rois=('bilateral_Amyg' 'bilateral_FFA' 'bilateral_OFA' 'bilateral_STS' 'rIFG_mask_1mm' 'V1_sphere_1mm' 'bilateral_A1')

for roi in ${rois[@]}
do
    roi_data=$PROJ_DIR/data/FaceProcessing/ROIs/${roi}.nii.gz
    roi_mask_name=$PROJ_DIR/data/FaceProcessing/ROIs/intersect_${roi}${suffix}.nii.gz
    
    echo Making $roi_mask_name with $ppt_num participants
    
    fslmerge -t $roi_mask_name $roi_data $mask_name
    fslmaths $roi_mask_name -abs -thr 0 -bin -Tmean -thr 1 -bin $roi_mask_name
    
done



exit


