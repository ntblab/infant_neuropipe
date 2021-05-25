#!/bin/bash
#
# Generate the intersect mask for a given movie

movie=$1 # what is the movie data folder called?
alignment=$2 # which alignment did you use?

files=`ls data/Movies/${movie}/preprocessed_standard/${alignment}/*_Z.nii.gz`

file_path=data/Movies/${movie}/preprocessed_standard/${alignment}/
mask_name=data/Movies/${movie}/intersect_mask_standard_all.nii.gz

ppt_num=`echo $files | wc -w`
echo Making $mask_name with $ppt_num participants

# Remove the intersect
rm -f $mask_name

for file in $files
do
    file_type=_Z
    ppt=${file#*${alignment}/}
    ppt=${ppt%${file_type}.nii.gz}

    data=$file_path/${ppt}_Z.nii.gz

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
