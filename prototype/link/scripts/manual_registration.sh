#!/bin/bash
#
# Perform manual registration either to highres (at both first and second level) or to standard space (second level).
# Takes as an input firstlevel_${FEAT_NAME}, secondlevel_highres or secondlevel_standard 
#
# This script will ask several questions that you answer in command line. These questions should guide you through the process. First off, it asks whether you want to make a new registration (using some default settings of FLIRT) or use the registration that has been previously created (this means you can run this script iteratively to gradually improve the fit). It also asks whether you want to also include another functional runs alignment as an alternative reference for registration, so as to make it easier to align all functionals to one another. Finally, it is also possible to use the transformation matrix from another run if you think two runs have the brain in a similar position and you have already 'fixed' one of those brains. This script includes many instructions you should follow, especially for your first time.
#
# This code assumes that you will be running matlab or freeview from the cluster, which is recommended for simplicity. However, if necessary it is possible to run locally by downloading the relevant files and then uploading the newly created registration file that is made. 

registration_level=$1

#source scripts/subject_id.sh
source globals.sh

# Get the fsl path to the standard brains
fsl_data=`which fsl`
fsl_data=${fsl_data%bin*}
fsl_data=$fsl_data/data/standard/

# What standard will you use
standard_brain=`scripts/age_to_standard.sh`

# Determine what type of registration you are going to do
if [[ $registration_level == "secondlevel_highres" ]] || [[ $registration_level == "firstlevel_"* ]]
then
	
#	Function for adding Manual Reg files instead of running it again	
# 	functional=01
# 	yes | cp analysis/firstlevel/Manual_Reg/functional${functional}/example_func2highres_automatic.mat analysis/firstlevel/functional${functional}.feat/reg/example_func2highres_automatic.mat
# 	flirt -in analysis/firstlevel/functional${functional}.feat/reg/example_func.nii.gz -ref analysis/firstlevel/functional${functional}.feat/reg/highres.nii.gz -applyxfm -init analysis/firstlevel/functional${functional}.feat/reg/example_func2highres_automatic.mat -o analysis/firstlevel/functional${functional}.feat/reg/example_func2highres_automatic.nii.gz
# 	yes | cp analysis/firstlevel/Manual_Reg/functional${functional}/example_func2highres.nii.gz analysis/firstlevel/functional${functional}.feat/reg/example_func2highres_baseline.nii.gz
# 	yes | cp analysis/firstlevel/Manual_Reg/functional${functional}/example_func2highres.mat analysis/firstlevel/functional${functional}.feat/reg/example_func2highres_baseline.mat
# 	./scripts/manual_registration.sh firstlevel_functional${functional}

	# Set up variable names (different for whether it is a certain registration type
	if [[ $registration_level == "firstlevel_"* ]]
	then
				
		FUNCTIONAL=${registration_level#*firstlevel_} # What is the name of the feat folder in the firstlevel directory you want to register to
		FEAT_DIR=$(pwd)/analysis/firstlevel/${FUNCTIONAL}.feat
		Manual_Backup_dir=$(pwd)/analysis/firstlevel/Manual_Reg/${FUNCTIONAL}
				
	else
		FEAT_DIR=$(pwd)/analysis/secondlevel/registration.feat
	fi

	echo "Using registration from $FEAT_DIR"	
	example_func=$FEAT_DIR/reg/example_func.nii.gz
	highres=$FEAT_DIR/reg/highres.nii.gz

	# How many runs where there
	runs=`ls -d $(pwd)/analysis/firstlevel/functional*.feat/reg/example_func2highres.nii.gz`
	run_num=`echo $runs | wc -w`
	
	# Decide whether to re run the flirt or use a previously created one
	if [ ! -e $FEAT_DIR/reg/example_func2highres_baseline.nii.gz ]
	then
		echo "Do you want to make a new automatic registration with flirt (1), use the registration from a different run (2), or use the one generated automatically created previously (0)? Press [ENTER] when decided"
	else
		echo "Do you want to make a new automatic registration with flirt (1), use the registration from a different run (2) or use the one generated previously by this script (labelled with '_baseline') (0)? Press [ENTER] when decided"
	fi
	read new_registration

	# If this is a new registration then take the highres and register to that
	if [ $new_registration == 1 ]
	then

		printf "\nMaking a new registration with $highres\n"
		rm -f $FEAT_DIR/reg/example_func*highres*~* $FEAT_DIR/reg/*highres*example_func*~*
		
		# Make the new flirt
		flirt -in $example_func -ref $highres -omat $FEAT_DIR/reg/example_func2highres_automatic.mat -o $FEAT_DIR/reg/example_func2highres_automatic.nii.gz -searchrx -10 10 -searchry -10 10 -searchrz -10 10 -dof 6
		
		# Make the baseline file
		cp $FEAT_DIR/reg/example_func2highres_automatic.mat $FEAT_DIR/reg/example_func2highres_baseline.mat
		cp $FEAT_DIR/reg/example_func2highres_automatic.nii.gz $FEAT_DIR/reg/example_func2highres_baseline.nii.gz
		
		echo "Check that the alignment is a good approximation" 	
		printf "Using the following flirt command. If you want to use something else then re-run this and elect to use the specified registration as a base:\n\nflirt -in $example_func -ref $highres -omat $FEAT_DIR/reg/example_func2highres_baseline.mat -o $FEAT_DIR/reg/example_func2highres_baseline.nii.gz -searchrx -10 10 -searchry -10 10 -searchrz -10 10 -dof 6\n"
		fslview $highres $FEAT_DIR/reg/example_func2highres_baseline.nii.gz
		
		printf "\nWas that alignment in the ballpark? If not press ctrl + C now to quit, otherwise wait 10s\n"
		sleep 10s 	
	elif [ $new_registration == 2 ]
	then
		
		echo ""
		echo "Using the alignment of another run as a start. Type the number corresponding to the answer and press ENTER"
		
		# Cycle through the runs and print the names
		counter=1
		for run in $runs
		do
			run_counter=${run#*/functional}
			run_counter=${run_counter%.feat/*}
			echo "$counter. functional${run_counter}"
			counter=$((counter + 1))
		done
		
		# Read in answer
		read func_include

		# Add the alignment for the corresponding run
		counter=1
		for run in $runs
		do
			if [ $counter -eq $func_include ]
			then
				# Make copies of the automatic registration if you haven't already
				if [ ! -e $FEAT_DIR/reg/example_func2highres_automatic.nii.gz ]
				then
					yes | cp $FEAT_DIR/reg/example_func2highres.nii.gz $FEAT_DIR/reg/example_func2highres_automatic.nii.gz
					yes | cp $FEAT_DIR/reg/example_func2highres.mat $FEAT_DIR/reg/example_func2highres_automatic.mat
				fi
				
				# Determine the path of the other run
				other_FEAT_DIR=${run%/*}
				echo "Using ${other_FEAT_DIR}/example_func2highres.mat as a baseline for alignment. Running the flirt with this matrix"

				# Copy over the mat data from the other dir
				yes | cp $other_FEAT_DIR/example_func2highres.mat $FEAT_DIR/reg/example_func2highres_baseline.mat
				
				# Perform the flirt
				flirt -in $example_func -ref $highres -applyxfm -init $FEAT_DIR/reg/example_func2highres_baseline.mat -o $FEAT_DIR/reg/example_func2highres_baseline.nii.gz
				
			fi
			
			# Increment counter
			counter=$((counter + 1))
		done

	else
		
		# Check whether there is a baseline file, if there isn't then assume you haven't 
		if [ ! -e $FEAT_DIR/reg/example_func2highres_baseline.nii.gz ]
		then
			printf "\nCreating $FEAT_DIR/reg/example_func2highres_baseline.nii.gz\n"
			yes | cp $FEAT_DIR/reg/example_func2highres.nii.gz $FEAT_DIR/reg/example_func2highres_baseline.nii.gz
			yes | cp $FEAT_DIR/reg/example_func2highres.nii.gz $FEAT_DIR/reg/example_func2highres_automatic.nii.gz
			yes | cp $FEAT_DIR/reg/example_func2highres.mat $FEAT_DIR/reg/example_func2highres_baseline.mat
			yes | cp $FEAT_DIR/reg/example_func2highres.mat $FEAT_DIR/reg/example_func2highres_automatic.mat
		fi

		printf "\nUsing $FEAT_DIR/reg/example_func2highres_baseline\n"
	fi
	
	
	# Remove the manual directory
	rm -rf $FEAT_DIR/reg/Manual_Reg; 
	mkdir $FEAT_DIR/reg/Manual_Reg; 
	
	# Adds only the essentials to the dir
	yes | cp $FEAT_DIR/reg/example_func2highres_baseline.nii.gz $FEAT_DIR/reg/Manual_Reg/inplane.nii.gz; 
	yes | cp $highres $FEAT_DIR/reg/Manual_Reg/volume_anat.nii.gz;
	

	
	# Decide if you want to also output a run to this folder too
	func_include=0
	if [ $run_num -gt 1 ]
	then
		echo ""
		echo "Multiple runs detected. Would you like to include another functional run for comparison? Type the number corresponding to the answer and press ENTER"
		echo "0. Do not add another"
		
		# Cycle through the runs and print the names
		counter=1
		for run in $runs
		do
			run_counter=${run#*/functional}
			run_counter=${run_counter%.feat/*}
			echo "$counter. functional${run_counter}"
			counter=$((counter + 1))
		done
		
		# Read in answer
		read func_include
		
		# Add the func from the corresponding number
		counter=1
		for run in $runs
		do
			if [ $counter -eq $func_include ]
			then
				baseline_func=$FEAT_DIR/reg/Manual_Reg/volume_func.nii.gz
				yes | cp $run $baseline_func
				
				echo "Adding $run"
			fi
			
			counter=$((counter + 1))
		done
	fi
	
	# Move into the folder
	cd $FEAT_DIR/reg/Manual_Reg/; 
	gunzip *.nii.gz;
	
	printf "\n\nOpen an interactive session of MATLAB (recommend tunnelling for speed) and change directory to:\n"
	printf "cd $(pwd)\n" 
	printf "addpath(genpath('$PACKAGES_DIR/mrTools/'))\n\n"

	echo "Run 'mrAlign'"
	echo "File>Load Destination (volume): volume_anat.nii.gz (or volume_func.nii.gz if available)"
	echo "File>Load Source (Inplane): inplane.nii.gz"
	echo "Click transpose, flip and change the alpha in order to orient the brain appropriately"
	echo "Perform the alignment using the slider and then to save:"
	echo "File>Export>Export Alignment: temp.mat"
	printf "In the matlab window:\n\nload temp.mat; xform\n\n"
	echo "Copy the output of xform into a file with the following path"
	echo "$(pwd)/example_func2highres_manual.mat"
	printf "This code will hang until this is created\n\n"
	
	while [ ! -e $(pwd)/example_func2highres_manual.mat ]
	do
		sleep 3s
	done
	
	# Add additional info (can't have anything superfluous in the file when you open mrAlign
	echo "Found the transformation, using it to make the appropriate files for registration"
	cp ../example_func2highres_baseline.mat example_func2highres_baseline.mat;
	
	# Convert the transformation matrices
	convert_xfm -omat example_func2highres.mat -concat example_func2highres_manual.mat example_func2highres_baseline.mat
	convert_xfm -inverse -omat highres2example_func.mat example_func2highres.mat
	yes | cp --backup=t *.mat ..; 
	
	# Return to the reg directory
	cd ..;
		
	# Perform flirt in both directions between highres and example_func
	flirt -in example_func.nii.gz -applyxfm -ref highres.nii.gz -init example_func2highres.mat -o example_func2highres.nii.gz;
	flirt -in highres.nii.gz -applyxfm -ref example_func.nii.gz -init highres2example_func.mat -o highres2example_func.nii.gz;
	
	# Copy these files as a back up
	yes | cp --backup=t example_func2highres.mat example_func2highres_baseline.mat
	yes | cp --backup=t example_func2highres.nii.gz example_func2highres_baseline.nii.gz
	
	# Save the alignment to this directory	
	if [[ $registration_level == "firstlevel_"* ]]
	then
		
		# Delete and replace this directory
		rm -rf $Manual_Backup_dir
		mkdir -p $Manual_Backup_dir
		
		yes | cp -R * $Manual_Backup_dir/
	fi
	
	# Check that the files look good
	echo "Opening fslview to view the outputs"
	view_brains="highres.nii.gz example_func2highres.nii.gz example_func2highres_automatic.nii.gz"
	
	# Append this brain to the list if necessary
	if [ $func_include -gt 0 ]
	then
		view_brains="$view_brains $baseline_func"
	fi
	
	fslview $view_brains

elif [[ $registration_level == "secondlevel_standard" ]]
then

	# Set up some variable names
	FEAT_DIR=$(pwd)/analysis/secondlevel/registration.feat
	STANDARD=$FEAT_DIR/reg/standard.nii.gz
	GLOBAL_STANDARD=$fsl_data/MNI152_T1_1mm.nii.gz
	
	# Do you want to create 
	if [[ ! -e $FEAT_DIR/reg/highres2standard_infant_baseline.nii.gz ]] && [[ ! -e $FEAT_DIR/reg/highres2standard_adult_baseline.nii.gz ]]
	then
		echo "Rerunning flirt to create a file structure with the appropriate names"
		new_registration=1
	else
		echo "Do you want to make a new automatic rigid body registration with flirt (1) or use the one generated previously by this script (labelled with '_baseline') (0)? Press [ENTER] when decided"
		read new_registration
	fi
	
	# If this is a new registration then take the appropriate standard brain and register the highres to that
	if [ $new_registration == 1 ]
	then

		# Read in the text file for the participant information (which has the age)
		Participant_Data=`cat $PROJ_DIR/scripts/Participant_Data.txt`

		# Find the participant name and then the age (this is annoying since you are doing most of the work of the age_to_standard script, but otherwise it is difficult to get the naming system to call the standards_infant or _child or something
		CorrectLine=0
		for word in $Participant_Data
		do
			# This word is the age
			if [[ $CorrectLine == 2 ]]; then
				Age=$word
				CorrectLine=0
			fi

			# Don't take the word immediately after the subject name, take the one after
			if [[ $CorrectLine == 1 ]]; then
				CorrectLine=2
			fi

			# Are you on the correct line
			if [[ $word == ${SUBJ} ]] && [[ $CorrectLine == 0 ]]; then
				CorrectLine=1
			fi

		done
		
		# Round the age to the nearest integer (although it doesn't do swedish rounding)
		Age=`echo $Age | xargs printf "%.*f\n" 0`
		if [ $Age -lt 60 ]
		then

			# What brain type are they
			#TRANSFORM_STANDARD=$ATLAS_DIR/nihpd_obj2_asym_nifti/nihpd_asym_2_MNI152_T1_1mm.mat
			TRANSFORM_STANDARD=${standard_brain::-8}_2_MNI152_T1_1mm.mat
			brain_type='infant'
			
		elif [ $Age -lt 200 ]
		then

			# What brain type are they
			#TRANSFORM_STANDARD=$ATLAS_DIR/nihpd_asym_all_nifti/nihpd_asym_2_MNI152_T1_1mm.mat
			TRANSFORM_STANDARD=${standard_brain::-8}_2_MNI152_T1_1mm.mat
			brain_type='child'
				
		else
			# If they are adults than the infant atlases then use this
			TRANSFORM_STANDARD=$PROJ_DIR/prototype/copy/analysis/secondlevel/identity.mat
			standard_brain=$fsl_data/MNI152_T1_1mm.nii.gz #Default to standard
			brain_type='adult'
		fi

		printf "\nMaking a new registration with $standard_brain\n"
		rm -f $FEAT_DIR/reg/*standard*~*
		
		# If this is already zipped then act differently
		if [ ${standard_brain:${#standard_brain}-2} != 'gz' ]
		then
		
			yes| cp $standard_brain $FEAT_DIR/reg/standard_${brain_type}.nii
			rm -f $FEAT_DIR/reg/standard_${brain_type}.nii.gz
		
			# Remove the files that might be there already
			gzip $FEAT_DIR/reg/standard_${brain_type}.nii
		
		else
			yes| cp $standard_brain $FEAT_DIR/reg/standard_${brain_type}.nii.gz
		fi
		
		# Relabel things that are the automatic output as such
		yes | cp $FEAT_DIR/reg/example_func2standard.nii.gz $FEAT_DIR/reg/example_func2standard_automatic.nii.gz 
		
		flirt -in $FEAT_DIR/reg/highres.nii.gz -ref $FEAT_DIR/reg/standard_${brain_type}.nii.gz -omat $FEAT_DIR/reg/highres2standard_${brain_type}_automatic.mat -o $FEAT_DIR/reg/highres2standard_${brain_type}_automatic.nii.gz -searchrx -10 10 -searchry -10 10 -searchrz -10 10 -dof 6
		
		# Make the baseline file
		cp $FEAT_DIR/reg/highres2standard_${brain_type}_automatic.mat $FEAT_DIR/reg/highres2standard_${brain_type}_baseline.mat
		cp $FEAT_DIR/reg/highres2standard_${brain_type}_automatic.nii.gz $FEAT_DIR/reg/highres2standard_${brain_type}_baseline.nii.gz
		
		echo "Check that the alignment is a good approximation" 	
		printf "Using the following flirt command. If you want to use something else then re-run this and elect to use the specified registration as a base:\n\nflirt -in $FEAT_DIR/reg/highres.nii.gz -ref $FEAT_DIR/reg/standard_${brain_type}.nii.gz -omat $FEAT_DIR/reg/highres2standard_${brain_type}_baseline.mat -o $FEAT_DIR/reg/highres2standard_${brain_type}_baseline.nii.gz -searchrx -10 10 -searchry -10 10 -searchrz -10 10 -dof 6\n\n"
		fslview $FEAT_DIR/reg/standard_${brain_type}.nii.gz $FEAT_DIR/reg/highres2standard_${brain_type}_automatic.nii.gz
		
		printf "Was that alignment in the ballpark? If not press ctrl + C now to quit, otherwise wait 10s\n"
		sleep 10s 	

	else
		
		# If you want to use the file that was created before then just set up some of the names
		
		# Pull out the brain type itself
		brain_type=`ls $FEAT_DIR/reg/highres2standard_*baseline.nii.gz`
		brain_type=${brain_type#*highres2standard_}
		brain_type=${brain_type%_baseline*}
		
		if [[ ${brain_type} == 'adult' ]]		
		then
			TRANSFORM_STANDARD=$PROJ_DIR/prototype/copy/analysis/secondlevel/identity.mat
		else
			#TRANSFORM_STANDARD=$ATLAS_DIR/nihpd_obj2_asym_nifti/nihpd_asym_2_MNI152_T1_1mm.mat
			TRANSFORM_STANDARD=${standard_brain::-8}_2_MNI152_T1_1mm.mat
		fi
		
		printf "\nUsing $FEAT_DIR/reg/highres2standard_${brain_type}_baseline\n"
	fi
	
	# Create the transformation from the infant standard to the adult standard
	if [ ! -e $TRANSFORM_STANDARD ]
	then 
		echo "${TRANSFORM_STANDARD} doesn't exist, creating it for now. However, it is recommended that you check this is good and if it isn't that you manually edit it. To manually edit it, follow these steps (where \${age} is the age range of the participant and assuming you are doing it for the youngest infants)."
		echo flirt -in nihpd_asym_\${age}_t1w.nii -applyxfm -ref /nexsan/apps/hpc/Apps/FSL/5.0.9/data/standard/MNI152_T1_1mm.nii.gz -omat nihpd_asym_\${age}_2_MNI152_T1_1mm.mat -o nihpd_asym_\${age}_2_MNI152_T1_1mm_automatic.nii.gz
		echo Edit alignment using FreeView
		echo convert_xfm -omat nihpd_asym_\${age}_2_MNI152_T1_1mm.mat -concat nihpd_asym_\${age}_2_MNI152_T1_1mm_manual.mat nihpd_asym_\${age}_2_MNI152_T1_1mm_automatic.mat
		echo flirt -in nihpd_asym_\${age}_t1w.nii -applyxfm -ref /nexsan/apps/hpc/Apps/FSL/5.0.9/data/standard/MNI152_T1_1mm.nii.gz -init nihpd_asym_\${age}_2_MNI152_T1_1mm.mat -o nihpd_asym_\${age}_2_MNI152_T1_1mm.nii.gz; 
	
		flirt -in $standard_brain -ref $GLOBAL_STANDARD -omat $TRANSFORM_STANDARD -out ${TRANSFORM_STANDARD::-4}.nii.gz 
	fi

	# Clear the directory out for this
	rm -rf $FEAT_DIR/reg/Manual_Reg_Standard; 
	mkdir $FEAT_DIR/reg/Manual_Reg_Standard; 
 
 	# Insert default files in the Manual_Reg folder
	yes | cp $FEAT_DIR/reg/highres2standard_${brain_type}_baseline.nii.gz $FEAT_DIR/reg/Manual_Reg_Standard/highres2standard_${brain_type}_baseline.nii.gz; 
	yes | cp $FEAT_DIR/reg/highres2standard_${brain_type}_baseline.mat $FEAT_DIR/reg/Manual_Reg_Standard/highres2standard_${brain_type}_baseline.mat
	yes | cp $FEAT_DIR/reg/standard_${brain_type}.nii.gz $FEAT_DIR/reg/Manual_Reg_Standard/standard_${brain_type}.nii.gz;
	yes | cp $GLOBAL_STANDARD $FEAT_DIR/reg/standard.nii.gz
	yes | cp $TRANSFORM_STANDARD $FEAT_DIR/reg/Manual_Reg_Standard/standard_${brain_type}2standard.mat
	
	# Jump into the directory
	cd $FEAT_DIR/reg/Manual_Reg_Standard;
	
	printf "\n\nOpen these files in Freeview in the desktop (the application, not from terminal):"
	printf "\nfreeview -v $FEAT_DIR/reg/Manual_Reg_Standard/standard_${brain_type}.nii.gz $FEAT_DIR/reg/Manual_Reg_Standard/highres2standard_${brain_type}_baseline.nii.gz\n\n"
	echo "Change the color map of the volume, lower the opacity. Go to Tools>Transform Volume... and align the volume."
	echo "I recommend performing rigid body transformation first and then do scaling to make it easier to understand"
	echo "IF YOU ROTATE (EITHER IN Y OR Z) OR TRANSLATE (IN X) THE VOLUME, FLIP THE SIGNS BEFORE SAVING (FSL has a different reference than freeview)"
	echo "Once you have found the perfect alignment and then flipped the signs, click 'Save_Reg' and choose a temporary destination for the .lta file"
	echo "In an active terminal open the .lta file and look for the first 4x4 matrix (approximately the 5th line down). This is the affine matrix that was created, copy it"
	printf "Paste this matrix into:\n\n$(pwd)/highres2standard_${brain_type}_manual.mat\n\n(copy matrix, open nano (without a name), paste, copy the name path and the save)"
	printf "This code will hang until this is created\n\n"
	
	# Wait for the code to finish
	while [ ! -e $(pwd)/highres2standard_${brain_type}_manual.mat ]
	do
		sleep 3s
		
		# Have the user check that the desired alignment is correct
		if [ -e $(pwd)/highres2standard_${brain_type}_manual.mat ]
		then
		
			echo "File found."
			echo "Load the file below into your freeview window now in order to check that the registration is as desired (helps to check that you did the orientation steps correctly).:"
			echo "$FEAT_DIR/reg/Manual_Reg_Standard/test_reg.nii.gz"
			echo "If this is incorrect type 0 and press [ENTER] and it will delete the mat file so that you can remake it, otherwise type 1 [ENTER]"
			
			# Create a temporary transformation
			flirt -in highres2standard_${brain_type}_baseline.nii.gz -applyxfm -ref standard_${brain_type}.nii.gz -init highres2standard_${brain_type}_manual.mat -o test_reg.nii.gz;
			
			# Listen for the response after this check
			read reg_accepted
			
			if [ $reg_accepted == 0 ]
			then
				rm $(pwd)/highres2standard_${brain_type}_manual.mat
				echo "Deleted the transformation matrix, make it again"
			else
				# Clean up
				rm $FEAT_DIR/reg/Manual_Reg_Standard/test_reg.nii.gz
			fi
		fi
	done
	
	echo "Assuming the registration was good. Converting into the necessary transformation matrices"
	printf "\nMaking all the necessary transformation matrices and transforming data"
	
	# First make all of the directions of transformation in the Manual_Reg_Standard folder
	convert_xfm -omat highres2standard_${brain_type}.mat -concat highres2standard_${brain_type}_manual.mat highres2standard_${brain_type}_baseline.mat 
	convert_xfm -omat highres2standard.mat -concat standard_${brain_type}2standard.mat highres2standard_${brain_type}.mat
	convert_xfm -inverse -omat standard2highres.mat highres2standard.mat
	convert_xfm -inverse -omat standard_${brain_type}2highres.mat highres2standard_${brain_type}.mat
	yes | cp --backup=t *.mat ..; 
	
	# Now make all the directions of transformation in the reg folder
	cd ..;
	convert_xfm -omat example_func2standard.mat -concat highres2standard.mat example_func2highres.mat 
	convert_xfm -omat example_func2standard_${brain_type}.mat -concat highres2standard_${brain_type}.mat example_func2highres.mat 
	convert_xfm -inverse -omat standard2example_func.mat example_func2standard.mat
	convert_xfm -inverse -omat standard_${brain_type}2example_func.mat example_func2standard_${brain_type}.mat
	
	# Apply all of the transformations
	flirt -in example_func.nii.gz -applyxfm -ref standard_${brain_type}.nii.gz -init example_func2standard_${brain_type}.mat -o example_func2standard_${brain_type}.nii.gz;
	flirt -in example_func.nii.gz -applyxfm -ref standard.nii.gz -init example_func2standard.mat -o example_func2standard.nii.gz;

	flirt -in highres.nii.gz -applyxfm -ref standard_${brain_type}.nii.gz -init highres2standard_${brain_type}.mat -o highres2standard_${brain_type}.nii.gz;
	flirt -in highres.nii.gz -applyxfm -ref standard.nii.gz -init highres2standard.mat -o highres2standard.nii.gz;
	flirt -in highres.nii.gz -applyxfm -ref standard.nii.gz -init highres2standard.mat -o highres2standard.nii.gz;

	flirt -in standard.nii.gz -applyxfm -ref highres.nii.gz -init standard2highres.mat -o standard2highres.nii.gz;
	flirt -in standard.nii.gz -applyxfm -ref example_func.nii.gz -init standard2example_func.mat -o standard2example_func.nii.gz;
	
	flirt -in standard_${brain_type}.nii.gz -applyxfm -ref highres.nii.gz -init standard_${brain_type}2highres.mat -o standard_${brain_type}2highres.nii.gz;	
	flirt -in standard_${brain_type}.nii.gz -applyxfm -ref example_func.nii.gz -init standard_${brain_type}2example_func.mat -o standard_${brain_type}2example_func.nii.gz;
	
	printf "\nMake or replace the necessary files if you want to re run any of these analyses\n\n"
	yes | cp  --backup=t highres2standard_${brain_type}.mat highres2standard_${brain_type}_baseline.mat
	yes | cp  --backup=t highres2standard_${brain_type}.nii.gz highres2standard_${brain_type}_baseline.nii.gz
		
	echo "Opening fslview to view the outputs"
	fslview example_func2standard.nii.gz standard.nii.gz highres2standard.nii.gz;

else
	echo "Could not find ${registration_level}"	
fi
