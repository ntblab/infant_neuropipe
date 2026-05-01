#!/usr/bin/env bash
# Run randomise for live or cartoon movie outputs vs. chance level
#
# An example command is sbatch scripts/CartoonLive/run_randomise_vs_chance.sh "${participants[@]}" LionKing_Cartoon faces_decode_SL infants
#
#SBATCH --output=logs/randomise-%j.out
#SBATCH -p psych_day
#SBATCH -t 350
#SBATCH --mem 5000

participants=$1 # list of the participants' names (to pass an array in bash: use "${participants[@]}" as input)
movie=$2 # Which movie is it? e.g., LionKing_Cartoon
analysis=$3 # what type of analysis are you looking at? e.g., temporal_isc, faces_decode_SL, scene_decode_SL
suffix=$4 # what is the suffix that will be used for the output files? (e.g., "adults" "infants")

# source the globals variable
source globals.sh

# What is the mask being used (assume all) 
mask_file=$PROJ_DIR/data/CartoonLive/ROIs/intersect_mask_standard_LionKing_all.nii.gz

# What is the mask that is "chance" (0.5 decoding value for face decoding, 0.33 for scene decoding) 
# This is the intersect mask multiplied by the cahnce values
if [[ "$analysis" == "faces_decode_SL" ]] 
then
    chance_file=$PROJ_DIR/data/CartoonLive/ROIs/intersect_mask_0.5.nii.gz
elif [[ "$analysis" == "scene_decode_SL" ]]
then
    chance_file=$PROJ_DIR/data/CartoonLive/ROIs/intersect_mask_0.33.nii.gz
fi

# Make the output folder if it doesn't already exist
mkdir -p $PROJ_DIR/data/CartoonLive/randomise

# Specify the output root names
merged_file=$PROJ_DIR/data/CartoonLive/randomise/${movie}_${analysis}_${suffix}_chance_diff.nii.gz
randomise_file=$PROJ_DIR/data/CartoonLive/randomise/${movie}_${analysis}_${suffix}

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
        # Get the data for the decode file
        file_name_pre_chance=$PROJ_DIR/data/Movies/${movie}/${analysis}/${ppt}_decode_movie.nii.gz
        
        # name the output 
        file_name=$PROJ_DIR/data/Movies/${movie}/${analysis}/${ppt}_decode_movie_vs_chance.nii.gz
        
        # subtract the chance map
        fslmaths $file_name_pre_chance -sub $chance_file $file_name
    
    # if not, chance is 0, so no subtraction necessary
    else
        # Get the data for the fisher-Z transformed ISC map 
        file_name=$PROJ_DIR/data/Movies/${movie}/${analysis}/${ppt}_Z.nii.gz
    fi
    
	# Either create or merge this file to the list
	if [ ! -e $merged_file ]
	then
        echo Initializing with $ppt 
		scp $file_name $merged_file
		
	else
		fslmerge -t $merged_file $merged_file $file_name
		echo Appending $ppt
	fi
    

done

# Mask the merged file again so that all of the background values are zero
fslmaths $merged_file -mas $mask_file $merged_file

# Run randomise 
randomise -i $merged_file -o $randomise_file -1 -n 1000 -x -T -t $PROJ_DIR/scripts/CartoonLive/contrast.con -C 2.09 

echo Finished

# Remove the merged file 
#rm -f $merged_file

