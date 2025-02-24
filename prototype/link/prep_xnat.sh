#!/bin/bash
#
# prep.sh prepares for analysis of the subject's data
# original author: mason simon (mgsimon@princeton.edu)
# this script was provided by NeuroPipe. modify it to suit your needs
#
#SBATCH --output=logs/prep-%j.out
#SBATCH -p long
#SBATCH -t 600
#SBATCH --mem 10000

# Set up the environment
source globals.sh

# Load the modules for interacting with XNAT
module load XNATClientTools

echo "==Prep (1): Pull the data from xnat =="
echo ' '

# Move in to the raw data folder
if [ ! -e data/raw ]
then
	
	# Make a folder
	mkdir data/raw
	cd data/raw
	
	# Copy over the data from xnat into this session
	ArcGet -s $SUBJ
	
	# Unzip the files
	unzip $SUBJ.zip
	
	# Go back to the folder
	cd ../../
	
else
	echo Data has already been pulled
fi

echo "==Prep (2): Convert the raw data into niftis and rename them according to the run order file =="
echo ' '

if [ ! -e $NIFTI_DIR ]
then
	
	# Make the nifti directory
	mkdir $NIFTI_DIR
	
	# Clean up the raw folder of files that may have been created by previous runs of this script
	cd data/raw/
	rm -f $SUBJ/*.nii
	rm -f $SUBJ/*.json
	rm -f $SUBJ/*.txt
	
	# Use afni's dcm2nii tool to convert the dicom files
	dcm2niix_afni $SUBJ
	
	# Move in to the directory
	cd $SUBJ
	
	# Pull out all of the scans from dicom directory
	scans=`ls *.nii`
	num_actual_scans=`echo $scans | wc -w`
	
	# Get the run order file
	run_order_file=${SUBJECT_DIR}/run-order.txt
	
	# Strip blank lines and comments from run order file
	echo "Converting stripped runorder file"
	stripped_run_order_file=$(mktemp -t tmp.XXXXX)
	sed '/^$/d;/^#/d;s/#.*//' $run_order_file > $stripped_run_order_file
	num_expected_scans=`cat $stripped_run_order_file | wc -l` # How many scans are expected from this run order
	
	# Check that the actual number of scans retrieved matches what's expected, and
	# exit with an error if not.
	
	if [ $num_actual_scans != $num_expected_scans ]; then
		echo "Found $num_actual_scans scans, but $num_expected_scans were described in $run_order_file. Check that you're listing enough scans for your circle localizer, etc... because those may convert as more than one scan." >/dev/stderr
		exit $UNEXPECTED_NUMBER_OF_SCANS
	fi
	
	# The scans listed in $scans are out of order (alphabetical, rather than in the order they were collected). Fix this here
	tmp_scan_order=tmp_scan_order.txt; 
	rm -f $tmp_scan_order # Delete to be sure
	for scan in $scans; 
	do 
		tmp=${scan#${SUBJ}*_2} # Pull out the part of the name that contains the date (will get caught up on some scan names that start with 2 so be careful)
		echo "${tmp#*_} ${scan}" >> $tmp_scan_order  # Store the name of the scan after the next underscore (the number corresponds to the scan number) as well as the actual scan name
	done

	# Sort the scans based on that first column
	cat $tmp_scan_order | sort -V > tmp.txt
	
	# Only take the second column, representing the run order
	awk '{print $2}' tmp.txt > ordered_scan_order.txt
	
	# Cycle through the run order file and rename the scans with that name
	number=0
	cat $stripped_run_order_file | while read name num_expected_trs; do
		let "number += 1"
		
		# Skip if this run is labelled ERROR_RUN
		if [[ $name == "ERROR_RUN" ]]; then
			continue
		fi

		# What is the input name (the nth row of the ordered scan list)
		input_name=`sed "${number}q;d" ordered_scan_order.txt`
		
		# What is the output name of the file
		output_name=${SUBJECT_DIR}/$NIFTI_DIR/${SUBJ}_${name}.nii
		
		# Check that the number of expected TRs matches what is in the run-order
		if [ -n "$num_expected_trs" ]; then
			num_actual_trs=$(fslnvols ${input_name}.nii)
			if [ $num_expected_trs -ne $num_actual_trs ]; then
				echo "$name has $num_actual_trs TRs--expected $num_expected_trs" >/dev/stderr
				exit $UNEXPECTED_NUMBER_OF_TRS
			fi
		fi
		
		# Move the file
		mv $input_name $output_name
		
	done
	
	# Return to the appropriate directory
	cd ${SUBJECT_DIR}
	
else
	echo Nifti directory already made
fi

echo "==Prep (3): Make bxh files for all the nifti files and zip them"
echo ' '

if ls $NIFTI_DIR/*.bxh 1> /dev/null 2>&1;
then
	echo "Skipping, bxh files already exist"
else
	files=`ls $NIFTI_DIR/*.nii`
	for file in $files
	do
		# Convert nii to bxh
		analyze2bxh $file ${file::-4}.bxh
	
		# Gzip all the niftis
		gzip $file
	done
fi

# Check the files are correctly sized
for file in $NIFTI_DIR/*.nii.gz; 
do
	echo $file
	fslinfo $file
done

echo "==Prep (4) : split long runs into two parts =="
echo ' '
# split long runs into two parts, so that the bxh tools don’t crash..
thresh=550  # How many TRs before a split is made?
for file in $NIFTI_DIR/*functional*.nii.gz; do

    num_volumes=$(fslnvols $file)

    echo "number of volumes is $num_volumes"
    if [[ "$num_volumes" -gt $thresh ]]; then

		# generate part 1
		prefix=${file%.nii.gz}
		postfix="_part1"
		ext=".nii.gz"
		echo "fslroi $file $prefix$postfix$ext 0 $thresh"
		echo "bxhselect --overwrite $prefix$postfix$ext $prefix$postfix"
		fslroi $file $prefix$postfix 0 $thresh
		bxhselect --overwrite $prefix$postfix$ext $prefix$postfix

		# generate part 2
		postfix="_part2"
		remain_tr=$(($num_volumes-$thresh))
		echo "fslroi $file $prefix$postfix$ext $thresh $remain_tr"
		echo "bxhselect --overwrite $prefix$postfix$ext $prefix$postfix"
		fslroi $file $prefix$postfix $thresh $remain_tr
		bxhselect --overwrite $prefix$postfix$ext $prefix$postfix
		# move/delete original 4D nifti
		#bakext=".bak"
		bxhext=".bxh"
		#mv $file $file$bakext
		#mv $prefix$bxhext $prefix$bxhext$bakext
		rm -f $file
		rm -f $prefix$bxhext
    fi
done


echo "==Prep (5) : qa-wrapped-data=="
echo ' '
bash scripts/qa-wrapped-data.sh $NIFTI_DIR $QA_DIR

echo "==Prep (6) : reorient to las=="
echo ' '
bash scripts/reorient-to-las.sh $NIFTI_DIR

echo "==Prep (7) : merge split runs =="
echo ' '
# Long runs were split into two parts, so that the bxh tools don’t crash - merge them.
if ls $NIFTI_DIR/*functional*_part1.nii.gz 1> /dev/null 2>&1;
then
	for file in $NIFTI_DIR/*functional*_part1.nii.gz; do
		prefix=${file%_part1.nii.gz}
		file2=$prefix"_part2.nii.gz"
		outfile=$prefix".nii.gz"
		echo "fslmerge -t $outfile $file $file2"
		fslmerge -t $outfile $file $file2
		# remove the split runs
		rm -f $file
		rm -f $file2
		bxhfile=$prefix"_part1.bxh"
		bxhfile2=$prefix"_part2.bxh"
		rm -f $bxhfile
		rm -f $bxhfile2
	done
fi

echo "==Finished=="
