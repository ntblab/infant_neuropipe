#!/usr/bin/env bash
# Run randomise with the submem categories
# Mirrored off of CE's stat learning run_randomise
#
# An example command is sbatch scripts/SubMem_Categories/run_randomise.sh Task 1 default
#
#SBATCH --output=logs/randomise-%j.out
#SBATCH -p psych_day
#SBATCH -t 350
#SBATCH --mem 5000

participants=$1 # list of the participants' names (to pass an array in bash: use "${participants[@]}" as input)
feat_type=$2 # For instance "Task" or "Binary"
contrast_num=$3 # For instance "1"
suffix=$4 # what is the suffix that will be used for the output files? (e.g., "all" "younger" or "older")

# source the globals variable
source globals.sh

# What is the mask being used (assume all)
mask_file=$PROJ_DIR/data/SubMem/masks/intersect_mask_standard.nii.gz

# Make the output folder if it doesn't already exist
mkdir -p $PROJ_DIR/data/SubMem/randomise/${feat_type}

# Specify the output root names
merged_file=$PROJ_DIR/data/SubMem/${feat_type}_zstat${contrast_num}_${suffix}.nii.gz # this will be temporary
randomise_file=$PROJ_DIR/data/SubMem/randomise/${feat_type}/zstat${contrast_num}_${suffix}

# Remove in case it exists
rm -f $merged_file

echo Making $merged_file
echo Outputting $randomise_file
echo Using $mask_file

# Cycle through the ppts
echo $participants
for ppt in $participants
do
    secondlevel_path=$PROJ_DIR/subjects/${ppt}/analysis/secondlevel_SubMem_Categories/default/ 
    file_name=${secondlevel_path}/SubMem_Categories_${feat_type}_Z.feat/stats/zstat${contrast_num}_registered_standard.nii.gz

	# Either create or merge this file to the list
	if [ ! -e $merged_file ]
	then
        echo Initializing with $file_name
		scp $file_name $merged_file
		
	else
		fslmerge -t $merged_file $merged_file $file_name
		echo Appending $file_name
	fi

done

# Mask the merged file again so that all of the background values are zero
fslmaths $merged_file -mas $mask_file $merged_file

# Run randomise 
randomise -i $merged_file -o $randomise_file -1 -n 1000 -x -T -t $PROJ_DIR/scripts/SubMem_Categories/contrast.con -C 2.09 

echo Finished

# Remove the merged file 
rm -f $merged_file

