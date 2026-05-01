#!/usr/bin/env bash
# Run randomise on live vs. cartoon movie outputs 
#
# An example command is sbatch scripts/CartoonLive/run_randomise_paired_diff.sh "${participants[@]}" temporal_isc infants
#
#SBATCH --output=logs/CartoonLive_randomise-%j.out
#SBATCH -p psych_day
#SBATCH -t 350
#SBATCH --mem 5000

participants=$1 # list of the participants' names (to pass an array in bash: use "${participants[@]}" as input)
analysis=$2 # what type of analysis are you looking at? e.g., temporal_isc, faces_decode_SL, scene_decode_SL
suffix=$3 # what is the suffix that will be used for the output files? (e.g., "adults" "infants")

# source the globals variable
source globals.sh

# What is the mask being used (assume all) 
mask_file=$PROJ_DIR/data/CartoonLive/ROIs/intersect_mask_standard_LionKing_all.nii.gz

# Make the output folder if it doesn't already exist
mkdir -p $PROJ_DIR/data/CartoonLive/randomise

# Specify the output root names
merged_file=$PROJ_DIR/data/CartoonLive/randomise/${analysis}_${suffix}_merged_diffs.nii.gz # this will be temporary
randomise_file=$PROJ_DIR/data/CartoonLive/randomise/${analysis}_${suffix}_condition_diff

# Remove in case it exists
rm -f $merged_file

echo Making $merged_file
echo Outputting $randomise_file
echo Using $mask_file

# Cycle through the ppts
echo $participants
for ppt in $participants
do

    # if it is a decoding analysis, do this 
    if [[ "$analysis" == *"decode"* ]]
    then 
    
        # Get the data for the two files
        live_file_name=$PROJ_DIR/data/Movies/LionKing_Live/${analysis}/${ppt}_decode_movie.nii.gz
        cartoon_file_name=$PROJ_DIR/data/Movies/LionKing_Cartoon/${analysis}/${ppt}_decode_movie.nii.gz
     
    # if not, do this
    else
        # Get the data for the fisher-Z transformed ISC map for each condition
        live_file_name=$PROJ_DIR/data/Movies/LionKing_Live/${analysis}/${ppt}_Z.nii.gz
        cartoon_file_name=$PROJ_DIR/data/Movies/LionKing_Cartoon/${analysis}/${ppt}_Z.nii.gz
    fi
    
    if [ ! -e $live_file_name ] || [ ! -e $cartoon_file_name ]
    then
        echo 'missing' $ppt ' -- exiting'
        exit
    else
        fslmaths ${live_file_name} -sub ${cartoon_file_name} temp_diff_${analysis}.nii.gz
    fi

	# Either create or merge this file to the list
	if [ ! -e $merged_file ]
	then
        echo Initializing with $ppt difference
		scp temp_diff_${analysis}.nii.gz $merged_file
		
	else
		fslmerge -t $merged_file $merged_file temp_diff_${analysis}.nii.gz
		echo Appending $ppt difference
	fi

done

# Mask the merged file again so that all of the background values are zero
fslmaths $merged_file -mas $mask_file $merged_file

# Run randomise 
randomise -i $merged_file -o $randomise_file -1 -n 1000 -x -T -t $PROJ_DIR/scripts/CartoonLive/contrast.con -C 2.09 

echo Finished

# Remove the merged file 
rm -f $merged_file

