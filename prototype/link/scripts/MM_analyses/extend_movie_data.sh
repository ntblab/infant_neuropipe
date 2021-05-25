#!/usr/bin/sh
#
# Take in a volume name (representing data stored in a group standard folder) and number of TRs to add enough TRs for a movies worth of data (93 TRs for MM) in both the functional volume and the confound regressor
source ./globals.sh

# What is the volume
vol=$1

# what viewing number?
counter=$2

# which movie name?
movie_out_name=$3

# How many TRs total should there be?
total_trs=$4

if [ $# -eq 4 ]
then
    preprocessing_type='nonlinear_alignment'
else
    preprocessing_type=$4
fi

file_base_name=${vol##*/}

# Create the blank volume
dim1=`fslval $vol dim1`
dim2=`fslval $vol dim2`
dim3=`fslval $vol dim3`
dim4=`fslval $vol dim4`
pixdim1=`fslval $vol pixdim1`
pixdim2=`fslval $vol pixdim2`
pixdim3=`fslval $vol pixdim3`
pixdim4=`fslval $vol pixdim4`

# How many TRs should be added
diff_trs=$(echo "$total_trs - $dim4" | bc)

echo Difference between desired and actual TRs: $diff_trs 

# Are there any more TRs to add?
if [ $diff_trs -ne 0 ]
then


    mkdir -p $PROJ_DIR/data/Movies/${movie_out_name}/preprocessed_standard/${preprocessing_type}_bkp/
    
	echo Creating blank volume for $vol
	
	# Create the blank
	fslcreatehd $dim1 $dim2 $dim3 $diff_trs $pixdim1 $pixdim2 $pixdim3 $pixdim4 0 0 0 16 temp_blank.nii.gz
	
	# Make the backup
	cp $vol $PROJ_DIR/data/Movies/${movie_out_name}/preprocessed_standard/${preprocessing_type}_bkp/${file_base_name}
	
	# Merge the volumes
	fslmerge -t $vol $vol temp_blank.nii.gz
	
else
	
	echo There are ${dim4} TRs in ${vol}, not appending a new volume

fi


# Only do the confound appending if the file is the right size
if [ $diff_trs -ne 0 ]
then

    mkdir -p $PROJ_DIR/data/Movies/${movie_out_name}/motion_confounds/bkp/
    
    # Create the confound file
    rm -f temp_confound.txt
    for i in `seq 1 $diff_trs`
    do 
        line='' 
            for j in `seq 1 $diff_trs`
            do 
                line="$line $((i==j))"; 
            done; 
        # write each line	
        printf "$line\n" >> temp_confound.txt; 
    done
    
    if [ $counter -eq 1 ] 
	then		
        file_name=${SUBJ}.txt
	else
        file_name=${SUBJ}_viewing_${counter}.txt
	fi
    
    # Backup the file
    ConfoundFile=$PROJ_DIR/data/Movies/${movie_out_name}/motion_confounds/${file_name}

    cp $ConfoundFile $PROJ_DIR/data/Movies/${movie_out_name}/motion_confounds/bkp/${file_name}

    # Append an identity matrix to the confound file
    echo Appending the identity matrix to the confound file
    matlab -nodesktop -nosplash -nodisplay -nojvm -r "addpath('$PROJ_DIR/prototype/link/scripts/'); append_regressor_file('temp_confound.txt', '$ConfoundFile', '1'); exit"

else
    echo Skipping confound creation
fi

echo Finished
