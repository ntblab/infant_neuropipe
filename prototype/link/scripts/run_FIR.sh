#!/bin/bash
#
# Run through the FIR analyses
#
# Generate an FIR model of the block design. This ought to resemble an HRF convolved with the event time course.
# An FIR model removes assumptions about how to model the HRF in infants. 
# This will not work for all runs because it assumes all blocks must be the same length
#
# To make this work, you must have run FEAT_univariate.sh.
#
# This code takes the following steps:
#
# 1. Run preprocess_FIR.m This matlab script takes in the feats made by
# FEAT_univariate.sh and creates timing files, confound files and
# filtered funcs necessary for FIR models. Critically, this removes any
# time periods that are extra rest between runs so that all runs last
# the same amount of time.
# 
# 2. Creates fsf files and submits it to feat This uses the
# fir.fsf.template file and edits the appropriate details to make an fir
# fsf file. To use the three column format you first specify the
# stimulation onset, then the number of events at each time point
# (almost always 1) and then the weight. In other words, simply change a
# normal timing file to have a 1 instead of the event duration. Name
# this timing file 'functional$XX_fir.txt'. This is then submitted to
# feat. Next run the feat analysis. Do everything as you would a normal
# GLM except instead of specifying a double gamma HRF, use the FIR
# option. Phase is the offset of the HRF from onset, usually should be
# 0s. Number is the quantity of events to model, should be ($period/$TR)
# - 1. Window is the cycle frequency, should be the duration of each
# block (aka $period).
# 
# 3. Run Analysis_FIR.m to compare FIR outputs to raw data This loads in
# the pe files and puts them in a timecourse for each block. This is
# then compared to the raw data and the hrf for this block. Look at the
# Evoked_Response.fig in each functional$XX_fir.feat Next, create the
# fsf file for the FIR analysis and then run the feat analysis Finally,
# aggregate the results to produce an FIR plot  
#
#SBATCH --output=./logs/run_FIR-%j.out
#SBATCH -p short
#SBATCH -t 6:00:00
#SBATCH --mem 20000
# Authored by C Ellis 5/19/17

source globals.sh

# Take in the input to determine what steps to run
if [ "$#" -gt 0 ] 
then
	steps_run=$1
else
	steps_run="123"
fi

echo Running steps $steps_run

# Get some parameter names
Manual_Reg_name=Manual_Reg
Manual_Reg_Standard_name=Manual_Reg_Standard
subject_dir=`pwd`
participant=`echo ${subject_dir#*subjects/}`
sig_func_mask_type=thresh-0.05_mask

# Preprocess and create the timing files
if [[ $steps_run == *"1"* ]]
then

	# Generate the appropriate data for FIR modeling
	if [[ $SCHEDULER == slurm ]]
	then
		sbatch -p $SHORT_PARTITION ./scripts/run_preprocess_FIR.sh
	else
		submit ./scripts/preprocess_FIR.m
	fi

	#  Let the code get a head start
	echo "Starting wait"
	sleep 300s
	echo "Wait over"

fi

# Create the FEAT folders
if [[ $steps_run == *"2"* ]]
then

	# Identify what files will be created
	preprocess_firs=`ls $subject_dir/analysis/firstlevel/Exploration/*_fir.txt`

	# Cycle through the directories
	fsf_template=fsf/fir.fsf.template
	for preprocess_fir in $preprocess_firs
	do
	
		echo Making a feat folder for $preprocess_fir
	
		#Set up the names
		univariate_dir=${preprocess_fir::-8}_univariate.feat/
		root=`echo ${univariate_dir%_univariate.feat/}`
		OUTPUT_DIR=`echo ${root}_fir.feat`
		EV_FILE=`echo ${root}_fir.txt`
		functionalName=`echo ${root#*Exploration/}`
		DATA_FILE_PREFIX=$subject_dir/analysis/firstlevel/Exploration/truncated_${participant}_${functionalName}.nii.gz
		CONFOUND_FILE=$subject_dir/analysis/firstlevel/Exploration/truncated_OverallConfounds_${functionalName}.txt
		output_fsf=${root}_fir.fsf
		temp_design=${root}_fir_temp
	
		# Skip if the directory exists
		if [ ! -e $OUTPUT_DIR ]
		then
	
			# Find the parameters
			TR_NUMBER=`fslval $DATA_FILE_PREFIX dim4`
			TR_DURATION=`fslval $DATA_FILE_PREFIX pixdim4`

			# Pull out the event duration and number
			timing=`head -1 ${root}.txt`
			timing=($timing)
			WINDOW_SIZE=`echo ${timing[1]} + $TR_DURATION + $TR_DURATION | bc` # Add two TRs, leaving only one burn out
			WINDOW_NUMBER=`echo $WINDOW_SIZE / $TR_DURATION | bc`
		
			# What is the high pass threshold to use for this design. Pick a number that you can use later for find replace so that you don't have to remake all of the fsf file
			high_pass_cutoff=18919
		
			# Write to the template
			cat $fsf_template \
			| sed "s:<?= \$OUTPUT_DIR ?>:$OUTPUT_DIR:g" \
			| sed "s:<?= \$TR_NUMBER ?>:$TR_NUMBER:g" \
			| sed "s:<?= \$TR_DURATION ?>:$TR_DURATION:g" \
			| sed "s:<?= \$DATA_FILE_PREFIX ?>:$DATA_FILE_PREFIX:g" \
			| sed "s:<?= \$CONFOUND_FILE ?>:$CONFOUND_FILE:g" \
			| sed "s:<?= \$EV_FILE ?>:$EV_FILE:g" \
			| sed "s:<?= \$WINDOW_SIZE ?>:$WINDOW_SIZE:g" \
			| sed "s:<?= \$WINDOW_NUMBER ?>:$WINDOW_NUMBER:g" \
			| sed "s:<?= \$HIGH_PASS_CUTOFF ?>:$high_pass_cutoff:g" \
				> ${temp_design}.fsf #Output to this file

			# Set up the contrasts
			# This creates contrasts of every element with every element, making the size of it potentially huge

			# To do this you need to use sed to find the line you are up to then insert text in that line

			# Preset at this line
			oldtext='set fmri(con_mode) orig'

			# Cycle through all the contrasts
			for wind in `seq 1 $WINDOW_NUMBER`
			do

				Line1="# Display images for contrast_real $wind"
				Line2="set fmri(conpic_real.$wind) 1"
				newtext="\n\n${Line1}\n${Line2}"
				sed -i "s/${oldtext}/${oldtext}${newtext}/" ${temp_design}.fsf
				oldtext=$Line2

				Line1="# Title for contrast_real $wind"
				Line2="set fmri(conname_real.$wind) "\"" ($wind)"\"""
				newtext="\n\n${Line1}\n${Line2}"
				sed -i "s/${oldtext}/${oldtext}${newtext}/" ${temp_design}.fsf
				oldtext=$Line2

					for compare_wind in `seq 1 $WINDOW_NUMBER`
					do

					# Is the window being compared with itself, if so set the value to one
					if [ $compare_wind -eq $wind ]
					then
						contrast=1
					else
						contrast=0
					fi

					Line1="# Real contrast_real vector $wind element $compare_wind"
					Line2="set fmri(con_real$wind.$compare_wind) $contrast"
					newtext="\n\n${Line1}\n${Line2}"
					sed -i "s/${oldtext}/${oldtext}${newtext}/" ${temp_design}.fsf
					oldtext=$Line2

					done

				Line1="# F-test 1 element $wind"
				Line2="set fmri(ftest_real1.$wind) 1"
				newtext="\n\n${Line1}\n${Line2}"
				sed -i "s/${oldtext}/${oldtext}${newtext}/" ${temp_design}.fsf
				oldtext=$Line2

			done

			Line1="# Display images for contrast_orig 1"
			Line2="set fmri(conpic_orig.1) 1"
			newtext="\n\n${Line1}\n${Line2}"
			sed -i "s/${oldtext}/${oldtext}${newtext}/" ${temp_design}.fsf
			oldtext=$Line2

			Line1="# Title for contrast_orig 1"
			Line2="set fmri(conname_orig.1) "\"""\"""
			newtext="\n\n${Line1}\n${Line2}"
			sed -i "s/${oldtext}/${oldtext}${newtext}/" ${temp_design}.fsf
			oldtext=$Line2

			Line1="# Real contrast_orig vector 1 element 1"
			Line2="set fmri(con_orig1.1) 1"
			newtext="\n\n${Line1}\n${Line2}"
			sed -i "s/${oldtext}/${oldtext}${newtext}/" ${temp_design}.fsf
			oldtext=$Line2

			Line1="# Contrast masking - use >0 instead of thresholding?"
			Line2="set fmri(conmask_zerothresh_yn) 0"
			newtext="\n\n${Line1}\n${Line2}"
			sed -i "s/${oldtext}/${oldtext}${newtext}/" ${temp_design}.fsf
			oldtext=$Line2


			# Cycle through all the F Tests
			for wind in `seq 1 $WINDOW_NUMBER`
			do
				for compare_wind in `seq 1 $WINDOW_NUMBER`
				do

					if [ $compare_wind -ne $wind ]
					then

						Line1="# Mask real contrast\/F-test $wind with real contrast\/F-test $compare_wind?"
						Line2="set fmri(conmask${wind}_${compare_wind}) 0"
						newtext="\n\n${Line1}\n${Line2}"
						sed -i "s/${oldtext}/${oldtext}${newtext}/" ${temp_design}.fsf
						oldtext=$Line2

					fi
				done
			done

			echo "Made ${temp_design}.fsf"
		
			# Make the feat model
			feat_model ${temp_design}

			# Input the design matrix into the feat
			high_pass_cutoff_new=`cutoffcalc --tr=$TR_NUMBER -i ${temp_design}.mat`
			high_pass_cutoff_new=`echo $high_pass_cutoff_new | awk '{print $NF}'`
		
			echo Using the high pass cutoff of ${high_pass_cutoff_new}
				
			cat ${temp_design}.fsf \
			| sed "s:$high_pass_cutoff:$high_pass_cutoff_new:g" \
				> $output_fsf #Output to this file
		
			# Delete the working
			rm -f ${temp_design}*
		
			echo "Starting feat"
			# Run feat
			sbatch ./scripts/run_feat.sh $output_fsf
	
		else
			echo $OUTPUT_DIR already exists, skipping
		fi
	done

	# Wait until you have any feats done
	echo Waiting for files to be created
	num_files=`ls analysis/firstlevel/Exploration/functional*_fir.feat/stats/zstat1.nii.gz 2> /dev/null | wc -l`
	while [ $num_files -eq 0 ]
	do
		num_files=`ls analysis/firstlevel/Exploration/functional*_fir.feat/stats/zstat1.nii.gz 2> /dev/null | wc -l`
		sleep 5s
	done


	# Wait until all the feats have run and then run the analysis
	inputs=`echo "$preprocess_firs" | wc -w`
	outputs=`ls 2>/dev/null -Ub1 -- analysis/firstlevel/Exploration/functional*_fir.feat/stats/zstat1.nii.gz | wc -l`
	while [ $inputs -ne $outputs ] 
	do 
		sleep 5s
		outputs=`ls 2>/dev/null -Ub1 -- analysis/firstlevel/Exploration/functional*_fir.feat/stats/zstat1.nii.gz | wc -l`
	done

fi

# Run the summarise of the FIR data
if [[ $steps_run == *"3"* ]]
then

	# Create masks in the functional space so that you can use them for analysis
	echo Transforming standard mask into functional space
	files=`ls analysis/firstlevel/Exploration/functional*_fir.feat/stats/zstat1.nii.gz`
	for file in $files
	do
	
		# Pull out the functional run
		functional_run=${file#*/functional}
		functional_run=${functional_run%_fir.feat*}

		# Transform standard space ROIs into functional space. 
		standard_reg_folder=${subject_dir}/analysis/secondlevel/registration.feat/reg/${Manual_Reg_Standard_name}/
		highres_reg_folder=${subject_dir}/analysis/firstlevel/functional${functional_run}.feat/reg/${Manual_Reg_name}/

		# If the registration folder doesn't exist then quit
		if [ ! -e $standard_reg_folder ]
		then
			echo The registration folder to standard doesnt exist, quitting.
			exit
		fi

		# If these files don't exist then make them
		ROIs="occipital frontal A1 occipital_pole V1 sig_func" # To include sig_func you must run the scripts/preprocessing_exploration/loo_randomise.sh script
		last_ROI=`echo $ROIs | awk '{ print $NF }'`
		output_path=${subject_dir}/analysis/firstlevel/Exploration/functional${functional_run}_fir.feat/
		if [ ! -e ${output_path}/${last_ROI}_mask.nii.gz ]
		then
			# Take the transformation from highres to standard and flip it
			convert_xfm -omat ${standard_reg_folder}/standard2highres.mat -inverse ${standard_reg_folder}/highres2standard.mat

			# Invert example func 2 highres
			convert_xfm -omat ${highres_reg_folder}/highres2example_func.mat -inverse ${highres_reg_folder}/example_func2highres.mat

			# Copy and paste transformation into highres
			cp ${highres_reg_folder}/example_func2highres.mat ${output_path}/example_func2highres.mat

			# Combine the transformations from standard to functional
			convert_xfm -omat ${output_path}/standard2example_func.mat -concat ${highres_reg_folder}/highres2example_func.mat ${standard_reg_folder}/standard2highres.mat

			# Cycle through the ROIs
			for ROI in $ROIs
			do

				# If the ROI is participant specific then do that here
				if [ $ROI == "sig_func" ]
				then
					input_mask=${PROJ_DIR}/results/loo_randomise_masks/masks/sig_2_all_default_${participant}_${sig_func_mask_type}.nii.gz
					output_mask=${output_path}/sig_func_mask.nii.gz
				else
					input_mask=$ATLAS_DIR/masks/${ROI}_MNI_1mm.nii.gz
					output_mask=${output_path}/${ROI}_mask.nii.gz
				fi

				if [ -e ${input_mask} ]
				then
					# Do the transformation of the ROIs to the functional
					flirt -in $input_mask -ref ${output_path}/filtered_func_data.nii.gz -init ${output_path}/standard2example_func.mat -applyxfm -o ${output_path}/${ROI}_mask.nii.gz

					# Take the union of the functional and ROIs
					fslmaths ${subject_dir}/analysis/firstlevel/functional${functional_run}.feat/mask.nii.gz -mul ${output_path}/${ROI}_mask.nii.gz -bin ${output_path}/${ROI}_mask.nii.gz
				else
					echo "Could not find ${input_mask}, not fitting to ${participant}"
				fi

			done
		else
			echo ${output_path}/${last_ROI}_mask.nii.gz exists, not recreating
		fi

		## Calculate the percent signal change for a given EV file
		#  Take in a parameter estimate file, the mean_func (part of the feat outputs), the max
		#  height of the box car from the design (usually but not always 1) and the name of the
		#  output.

		mean_func=${subject_dir}/analysis/firstlevel/Exploration/functional${functional_run}_fir.feat/mean_func.nii.gz
		pe_files=`ls ${subject_dir}/analysis/firstlevel/Exploration/functional${functional_run}_fir.feat/stats/pe*.nii.gz`
		for pe_file in $pe_files
		do

			# Figure out the ev height by reading from the design mat
			design_mat=`cat ${subject_dir}/analysis/firstlevel/Exploration/functional${functional_run}_fir.feat/design.mat`
		
			# What PE is this?
			pe_num=${pe_file#*/pe}
			pe_num=${pe_num::-7}
		
			pe_counter=0
			for word in $design_mat
			do
			
				# If there is a match then store this as the height
				if [ $pe_counter -eq $pe_num ]
				then 
					ev_height=$word
				fi
			
				# Increment counter
				if [ $pe_counter -gt 0 ]
				then
					pe_counter=$((pe_counter + 1))
				fi
			
				# Is this the word listing the heights
				if [ $word = "/PPheights" ]
				then
					pe_counter=1
				fi
			
			done
		
			# Figure out the PSC
			output_file=${subject_dir}/analysis/firstlevel/Exploration/functional${functional_run}_fir.feat/stats/psc_pe${pe_num}.nii.gz

			# Run the fslmaths calculation
			fslmaths $pe_file -div $mean_func -mul $ev_height -mul 100 $output_file
		done

	done


	# Generate the FIR results for each run and mask type
	files=`ls analysis/firstlevel/Exploration/functional*_fir.feat/stats/zstat1.nii.gz`
	for file in $files
	do
	
		# Pull out the functional run
		functional_run=${file#*/functional}
		functional_run=${functional_run%_fir.feat*}
		masks=`ls analysis/firstlevel/Exploration/functional${functional_run}_fir.feat/*_mask.nii.gz`
		for masktype in 0 1 2 3 $masks
		do

			# Submit for final analysis
			if [[ $SCHEDULER == slurm ]]
			then
				sbatch -p $SHORT_PARTITION ./scripts/run_Analysis_FIR.sh $masktype $functional_run
			else
				submit ./scripts/Analysis_FIR.m $masktype $functional_run
			fi 
		done
	done

fi
