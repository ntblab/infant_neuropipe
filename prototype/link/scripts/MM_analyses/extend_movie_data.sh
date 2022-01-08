#!/usr/bin/sh
#
# Take in a volume name (representing data stored in a group standard folder) and number of TRs to add a movies worth of data (93 TRs for MM) to both the functional volume and to the confound regressor
source ./globals.sh

# What is the volume
vol=$1

# What is the output name for the confound regressor
ConfoundFile=$2

# How many TRs total should there be?
total_trs=$3

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

	echo Creating blank volume for $vol
	
	# Create the blank
	fslcreatehd $dim1 $dim2 $dim3 $diff_trs $pixdim1 $pixdim2 $pixdim3 $pixdim4 0 0 0 16 temp_blank.nii.gz
	
	# Merge the volumes
	fslmerge -t $vol $vol temp_blank.nii.gz
	
else
	
	echo There are ${dim4} TRs in ${vol}, not appending a new volume

fi


# Only do the confound appending if the file is the right size
if [ $diff_trs -ne 0 ]
then

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

    # Append an identity matrix to the confound file
    echo Appending the identity matrix to the confound file
    matlab -nodesktop -nosplash -nodisplay -nojvm -r "addpath('$PROJ_DIR/prototype/link/scripts/'); append_regressor_file('temp_confound.txt', '$ConfoundFile', '1'); exit"

else
    echo Skipping confound creation
fi

echo Finished
