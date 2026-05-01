#!/bin/bash
#
# Generate the intersect mask for a given movie
# Here, we use both the Live and Cartoon movies together

alignment='nonlinear_alignment' # which alignment did you use?
preproc='' # '' or smoothing0_sfnrmask-1 for looking at eyeballs 


# (1) Who do you want to include in the mask (only infants for eyeball mask, infants and adults for the whole brain mask) and
# (2) What do you want to name the output file
if [[ $preproc == 'smoothing0_sfnrmask-1' ]]
then
    subs=`cat data/Movies/LionKing_Cartoon/infant_participants.csv | cut -d ',' -f1`
    mask_name=data/CartoonLive/ROIs/intersect_mask_standard_eyes.nii.gz
else
    subs=`cat data/Movies/LionKing_Cartoon/*_participants.csv | cut -d ',' -f1`
    mask_name=data/CartoonLive/ROIs/intersect_mask_standard_LionKing_all.nii.gz
fi

# preset
files=""

# cycle through subjects kusted in the .csv 
for sub in $subs
do

# cycle through the two movies
for movie in 'LionKing_Live' 'LionKing_Cartoon'
do

# ignore the header, otherwise, append to the list of data files
if [[ $sub != 'ppt' ]]
then
    files="${files} data/Movies/${movie}/${preproc}/preprocessed_standard/${alignment}/${sub}_Z.nii.gz"
    
fi
done
done

# Count the number of participants, and tell us what we are doing
ppt_num=`echo $files | wc -w`
echo Making $mask_name with $ppt_num participants

# Remove the intersect
rm -f $mask_name

# cycle through the files
for file in $files
do
    # remove previous version 
    rm temp.nii.gz 
    
    # get the participant and movie names
    file_type=_Z
    ppt=${file#*${alignment}/}
    ppt=${ppt%${file_type}.nii.gz}

    movie=${file%*/${preproc}/preprocessed_standard*}
    movie=${movie#*Movies/}
    
    # set thee file path
    file_path=data/Movies/${movie}/${preproc}/preprocessed_standard/${alignment}/

    # actual participant file name 
    data=$file_path/${ppt}_Z.nii.gz
    
    # Take only a single TR
    fslroi $data temp.nii.gz 0 1
    
    # Bin the data because it's currently a stat map with positive and negative values -- binning gives us a mask
    fslmaths temp.nii.gz -abs -bin temp.nii.gz

    # Merge or create the mask
    if [ -e $mask_name ]
    then
        fslmerge -t $mask_name $mask_name temp.nii.gz
    else
        cp temp.nii.gz $mask_name
    fi

done


# Remove intermediate file
#rm -f temp.nii.gz

# Average the data across time (aka, across subjects, giving us the intersect mask when we bin at a threshold of 1)
fslmaths $mask_name -Tmean -thr 1 -bin $mask_name
