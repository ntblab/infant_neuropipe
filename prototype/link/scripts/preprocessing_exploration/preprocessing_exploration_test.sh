#!/bin/bash
#
# Analyse the preprocessing testing
# Take in a functional run number and then use the transformations
# (standard 2 highres and highres 2 example func) to put an occipital mask
# in functional space. Then use this mask as a way to quantify the z score
# in the ROI of interest
#
# C Ellis 081417. 
#
#SBATCH --output=./logs/preprocessing_exploration_test-%j.out
#SBATCH -p short
#SBATCH -t 300
#SBATCH --mem 20000

# What is the name of the functional being selected
functional_run=$1

# If there is another input then use it as the suffix for the output folder
if [ $# -gt 1 ]
then
output_suffix=$2
else
output_suffix=''
fi

min_blocks=2

source globals.sh

# Pull out the fsl path (assumes that FSL has been loaded)
fslpath=`which feat`
fslpath=${fslpath%feat}

# Are you using slurm or not?
if [[ ${SCHEDULER} == slurm ]]
then
	slurm=1
else
	slurm=0
fi

# Get the fsl path to the standard brains
fsl_data=`which fsl`
fsl_data=${fsl_data%bin*}
fsl_data=$fsl_data/data/standard/

# What is the root directory for the subject
subject_dir=$(pwd)
subject_name=${subject_dir#*subjects/} # What is the participant name
subject_name=${subject_name%/*} # Remove the slash

echo Testing $subject_name run $functional_run

# What is the path to the folder where these analyses will be run?
exploration_path="${subject_dir}/analysis/firstlevel/Exploration/preprocessing_exploration/"
output_path=$PROJ_DIR/results/preprocessing_exploration${output_suffix}/individual/

# What are the ROIs you want to test
ROIs="occipital frontal A1 V1 LOC"

# Make the directory where these analyses will be output
mkdir -p ${exploration_path}
mkdir -p ${output_path}

# Transform standard space ROIs into functional space. 
standard_reg_folder=${subject_dir}/analysis/secondlevel/registration.feat/reg/
highres_reg_folder=${subject_dir}/analysis/firstlevel/Exploration/reg${functional_run}/

# Specify a registration folder
if [ ! -e ${highres_reg_folder}/mask.nii.gz ]
then
	echo The registration folder to highres doesnt exist, trying to copy it from firstlevel
	
	if [ -e ${subject_dir}/analysis/firstlevel/functional${functional_run}.feat/reg/ ]
	then
		cp -R ${subject_dir}/analysis/firstlevel/functional${functional_run}.feat/reg/ ${subject_dir}/analysis/firstlevel/Exploration/reg${functional_run}
	
		# Convert a volume into a mask
		cp ${subject_dir}/analysis/firstlevel/functional${functional_run}.feat/mask.nii.gz ${subject_dir}/analysis/firstlevel/Exploration/reg${functional_run}/
	else
		echo Could not find the folder, try running a different version of the following
		echo cp -R ${subject_dir}/analysis/firstlevel/functional${functional_run}.feat/reg/ ${subject_dir}/analysis/firstlevel/Exploration/reg${functional_run}
		echo cp ${subject_dir}/analysis/firstlevel/functional${functional_run}.feat/mask.nii.gz ${subject_dir}/analysis/firstlevel/Exploration/reg${functional_run}/
		exit
	fi
fi

# If the registration folder doesn't exist then quit
if [ ! -e $standard_reg_folder ]
then
	echo The registration folder to standard doesnt exist, quitting.
	exit
fi

# If these files don't exist then make them
last_ROI=${ROIs##* } # Get the last ROI in the list (should have been run)
if [ ! -e ${exploration_path}/${last_ROI}_${functional_run}_mask.nii.gz ]
then
	# Take the transformation from highres to standard and flip it
	convert_xfm -omat ${standard_reg_folder}/standard2highres.mat -inverse ${standard_reg_folder}/highres2standard.mat
	
	# Invert example func 2 highres
	convert_xfm -omat ${highres_reg_folder}/highres2example_func.mat -inverse ${highres_reg_folder}/example_func2highres.mat

	# Copy and paste transformation into highres
	cp ${highres_reg_folder}/example_func2highres.mat ${exploration_path}/example_func2highres_${functional_run}.mat
	
	# Combine the transformations from standard to functional
	convert_xfm -omat ${exploration_path}/standard2example_func_${functional_run}.mat -concat ${highres_reg_folder}/highres2example_func.mat ${standard_reg_folder}/standard2highres.mat

	# Invert the transformation
	convert_xfm -omat ${exploration_path}/example_func2standard_${functional_run}.mat -inverse ${exploration_path}/standard2example_func_${functional_run}.mat

	# Cycle through the ROIs
	for ROI in $ROIs
	do
		# Do the transformation of the ROIs to the functional
		flirt -in $ATLAS_DIR/masks/${ROI}_MNI_1mm.nii.gz -ref ${exploration_path}/functional${functional_run}_default.feat/example_func.nii.gz -init ${exploration_path}/standard2example_func_${functional_run}.mat -applyxfm -o ${exploration_path}/${ROI}_${functional_run}_mask.nii.gz

		# Take the union of the functional and ROIs
		fslmaths ${highres_reg_folder}/mask.nii.gz -mul ${exploration_path}/${ROI}_${functional_run}_mask.nii.gz -bin ${exploration_path}/${ROI}_${functional_run}_mask.nii.gz
	done
else
	echo ${exploration_path}/${last_ROI}_${functional_run}_mask.nii.gz exists, not recreating
fi

# Get all the analyses
analysis_types=`ls ${exploration_path}/functional${functional_run}*.feat/stats/zstat1.nii.gz`

# Iterate through the feat folders and mask for occipital and visual activity
for zstat_map in $analysis_types
do
	
	condition=${zstat_map%.feat*}
	condition=${condition#*functional??_}
	
	# If there is still a prefix in the variable then remove it here
	if [[ $condition == *"functional"* ]]
	then
		condition=${condition#*functional???_}
	fi

	# Where is the data from
	directory=${exploration_path}/functional${functional_run}_${condition}.feat/

	# Remove all of the prefiltered files to reduce the size of the directory
	#rm -f ${exploration_path}/functional${functional_run}_${condition}.feat/prefiltered*
	
	# Check that this analysis has the minimum number of blocks
	ev_file=${exploration_path}/ev_files/functional${functional_run}_${condition}.txt 
	
	# Copy over the sfnr files if the run is slice
	if [[ $condition == *"_sliced" ]]
	then
		condition_trimmed=${condition%_sliced}
		cp ${exploration_path}/functional${functional_run}_${condition_trimmed}.feat/sfnr* ${directory}/
	fi
		
	# Sum the number of blocks
	BlockNum=`cat $ev_file | awk '{sum+=$3} END{print sum}'`
	if [ $BlockNum -ge $min_blocks ]
	then
	
		SFNR=0 # Set to a value other than 1 to skip this 
		for ROI in $ROIs
		do
		
			# Where will this information be printed
			filename_mean=$output_path/${ROI}_mean.txt
			filename_max=$output_path/${ROI}_max.txt
			filename_threshold_95=$output_path/${ROI}_threshold_95.txt
			filename_proportion_sig_voxels=$output_path/${ROI}_proportion_sig_voxels.txt
			filename_proportion_sig_voxels_p_05=$output_path/${ROI}_proportion_sig_voxels_p_05.txt
			filename_SFNR=$output_path/${ROI}_SFNR.txt
		

			volume=${zstat_map%.nii.gz}_${ROI}_${functional_run}_mask.nii.gz
		
			# Check whether the entry exists in these files and if so, skip it
			if [ -e $filename_mean ]
			then
				file_text=`cat $filename_mean`
			else
				file_text=''
			fi

			root=`echo $zstat_map | rev | cut -c 8- | rev`
			if [[ $file_text != *"$subject_name functional${functional_run} ${condition}:"* ]]
			then
				echo Participant information is not stored in $filename_mean, adding
		
				# Mask the zstat maps
				fslmaths ${zstat_map} -mas ${exploration_path}/${ROI}_${functional_run}_mask.nii.gz $volume
	
				# Get useful descriptives
				mean=`fslstats $volume -M`
				max=`fslstats $volume -P 100`
				threshold_95=`fslstats $volume -P 95`
				fslmaths $volume -thr 2.3 -bin temp_${functional_run}.nii.gz # Mask the values above the sig threshold
				proportion_sig=`fslstats temp_${functional_run}.nii.gz -m`
				proportion_mask=`fslstats ${exploration_path}/${ROI}_${functional_run}_mask.nii.gz -m`
				proportion_sig_voxels=`echo $proportion_sig / $proportion_mask | bc -l`
				proportion_sig_voxels=${proportion_sig_voxels:0:8}
		
                                fslmaths $volume -thr 1.96 -bin temp_${functional_run}.nii.gz # Mask the values above the sig threshold
				proportion_sig_p_05=`fslstats temp_${functional_run}.nii.gz -m`
				proportion_sig_voxels_p_05=`echo $proportion_sig_p_05 / $proportion_mask | bc -l`
				proportion_sig_voxels_p_05=${proportion_sig_voxels_p_05:0:8}
				# If the sfnr hasn't been calculated for this volume then do so now
				if [ $SFNR == 0 ]
				then
					echo Calculate the SFNR
				
					# Calculate the SFNR with the timing file (since some get it wrong)
					
					input_file=${directory}/prefiltered_func_data_st.nii.gz
					confound_file=${subject_dir}/analysis/firstlevel/Confounds/MotionConfounds_functional${functional_run}.txt # Set as default
		
					# Change the parameters
					if [[ $condition == "MotionParameters_None" ]] || [[ $condition == "MotionParameters_Standard" ]] || [[ $condition == "MotionConfounds_None" ]] || [[ $condition == "MotionParameters_Extended" ]] 
					then
						confound_file=""
					elif [[ $condition == "MotionConfounds_PCA_thr"* ]]
					then
		
						# What threshold are you using for PCA testing
						threshold=${condition#*thr}
		
						# Use the confound timepoints as specified by this threshold
						confound_file=${subject_dir}/analysis/firstlevel/Confounds/MotionConfounds_PCA_threshold_${threshold}_functional${functional_run}.txt
					elif [[ $condition == "MotionConfounds_fslmotion_thr"* ]]
					then
		
						# What threshold are you using for fslmotion testing
						threshold=${condition#*thr}
		
						# Use the confound timepoints as specified by this threshold
						confound_file=${subject_dir}/analysis/firstlevel/Confounds/MotionConfounds_fslmotion_${threshold}_functional${functional_run}.txt
					fi
		
					if [ ! -e $confound_file ]
					then
						run_confound=0
						confound_file=""
					fi


					matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('$PROJ_DIR/prototype/link/scripts/'); whole_brain_sfnr('${input_file}', '${directory}', '${confound_file}'); exit"
		
					# Fill in holes in the mask
					fslmaths ${directory}/sfnr_prefiltered_func_data_st.nii.gz -mas ${directory}/sfnr_mask_prefiltered_func_data_st.nii.gz temp_${functional_run}.nii.gz
		
					# Take the average value of the SFNR just created	
					SFNR=`fslstats temp_${functional_run}.nii.gz -M`
				fi
		
				# Append the information to a text file
				if [ -e $volume ]
				then
		
					echo "$volume found, reporting all statistics"
					echo $subject_name functional${functional_run} ${condition}: $mean >> $filename_mean
					echo $subject_name functional${functional_run} ${condition}: $max >> $filename_max
					echo $subject_name functional${functional_run} ${condition}: $threshold_95 >> $filename_threshold_95
					echo $subject_name functional${functional_run} ${condition}: $proportion_sig_voxels >> $filename_proportion_sig_voxels
					echo $subject_name functional${functional_run} ${condition}: $proportion_sig_voxels_p_05 >> $filename_proportion_sig_voxels_p_05
				fi
		
				echo $subject_name functional${functional_run} ${condition}: $SFNR >> $filename_SFNR	
			
				# Remove temporary files
				rm temp_${functional_run}.nii.gz
			else
				echo "$subject_name functional${functional_run} ${condition} already exists. Skipping"				
			fi
		done

		## Create images showing the sig regions
		root=`echo $zstat_map | rev | cut -c 8- | rev`
		echo Looking for ${root}_overlay_highres.nii.gz
		if [ ! -e ${root}_overlay_highres.nii.gz ] # [[ $file_text != *"$subject_name functional${functional_run} ${condition}:"* ]]
		then
			# Preset	
			zmin=2.3
			zmax=3
		
			# Preset files
			mask=${highres_reg_folder}/mask.nii.gz
	
			# Register the maps for anatomical space
			output_image=${root}_highres.png
			output_brain=${root}_highres.nii.gz
			output_overlay=${root}_overlay_highres.nii.gz
			flirt -in $zstat_map -applyxfm -init ${exploration_path}/example_func2highres_${functional_run}.mat -out ${output_brain} -ref ${highres_reg_folder}/highres.nii.gz

			#Overlay the maps
			./scripts/overlay_stats.sh ${output_brain} ${highres_reg_folder}/highres.nii.gz ${output_overlay} $zmin $zmax

			sleep 30s # Sometimes necessary
			echo "Overlayed $output_overlay"

			slicer ${output_overlay} -a ${output_image}
		fi
	
		echo Looking for ${root}_overlay_standard.nii.gz
		if [ ! -e ${root}_overlay_standard.nii.gz ] # [[ $file_text != *"$subject_name functional${$
		then
			# Register the maps for standard space
			output_image=${root}_standard.png
			output_brain=${root}_standard.nii.gz
			output_overlay=${root}_overlay_standard.nii.gz
			flirt -in $zstat_map -applyxfm -init ${exploration_path}/example_func2standard_${functional_run}.mat -out ${output_brain} -ref $fsl_data/MNI152_T1_1mm.nii.gz

			#Overlay the maps
			./scripts/overlay_stats.sh ${output_brain} $fsl_data/MNI152_T1_1mm.nii.gz ${output_overlay} $zmin $zmax

			sleep 30s # Sometimes necessary
			echo "Overlayed $output_overlay"

			slicer ${output_overlay} -a ${output_image}
		fi
	else
		# Output 
		echo Run ${condition} $functional_run only has $BlockNum blocks, not remapping
	fi

	
done

