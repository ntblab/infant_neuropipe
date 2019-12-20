#!/bin/bash
#
# This implements the necessary preprocessing steps for infant_neuropipe.
#
# Many of the steps are identical to typical FEAT, while other steps are unique,
# like using the centroid TR, interpolating excluded TRs, using SFNR for masking
# and Despiking
#
# This script should be launched from FEAT_firstlevel.sh but can be co-opted
# in specific cases to run preprocessing alone.
# Critically, the design MUST be the same in the template FEAT directory
# compared to the one you wish to create. If you change confounds or EVs
# this won't work
# 
# This command takes the following inputs:
# 
# A path to a FEAT directory to be used as a template. 
# The name of the FEAT directory to be created. 
# The path to the new example_func
# 
# The commands will then be run for this data as a normal FEAT analysis
# would run.
#
# First made by C Ellis 2/21/17
# 
#SBATCH --output=feat_prestats-%j.out
#SBATCH -p short
#SBATCH -t 300
#SBATCH --mem 20000

echo "Running pre-stats"

# Load the globals (need to change directory)
current_dir=`pwd`
cd ${current_dir%analysis/*}
source globals.sh
cd ${current_dir}

# Store the inputs
Base_FEAT=$1
Output_FEAT=$2
Input_example_func=$3

# Pull out the fsl path (assumes that FSL has been loaded)
fslpath=`which feat`
fslpath=${fslpath%feat}

# If only one input is provided then assume you are overwriting the input with the optimal functional
if [ $# -eq 1 ]
then
	Output_FEAT=$Base_FEAT
	
	idx=`awk -v a="$Base_FEAT" -v b="firstlevel" 'BEGIN{print index(a,b)}'`
	firstlevel_dir=${Base_FEAT::(idx+10)}
	
fi

# Move into the folder
cd $Output_FEAT

# What is the full path to this file
path=`pwd`

## Registration
echo "Running registration"
# Pull out some registration parameters
FileInfo=`cat design.fsf`
command=""
CorrectLine=0
highres=0
for word in $FileInfo
do
	
	# If you are on the correct line the store all the words until you aren't
	if [[ $CorrectLine == 1 ]]; then
		highres=$word
		highres=`echo ${highres:1} | rev | cut -c 2- | rev`
		CorrectLine=0
	elif [[ $CorrectLine == 2 ]]; then
		standard=$word
		standard=`echo ${standard:1} | rev | cut -c 2- | rev`
		CorrectLine=0
	elif [[ $CorrectLine == 3 ]]; then
		regstandard_dof=$word
		CorrectLine=0
	elif [[ $CorrectLine == 4 ]]; then
		regstandard_search=$word
		CorrectLine=0
	elif [[ $CorrectLine == 5 ]]; then
		reghighres_search=$word
		CorrectLine=0
	elif [[ $CorrectLine == 6 ]]; then
		reghighres_dof=$word
		CorrectLine=0
	elif [[ $CorrectLine == 7 ]]; then
		Confound_File=$word
		Confound_File=`echo ${Confound_File:1} | rev | cut -c 2- | rev` # Remove the speech marks
		CorrectLine=0
	elif [[ $CorrectLine == 8 ]]; then
		
		# If the example func was not supplied then call it here
		if [ $# -lt 3 ]
		then
			Input_example_func=$word
			Input_example_func=`echo ${Input_example_func:1} | rev | cut -c 2- | rev` # Remove the speech marks
		fi
		
		CorrectLine=0
	elif [[ $CorrectLine == 9 ]]; then
		despiking=$word
		CorrectLine=0	
	elif [[ $CorrectLine == 10 ]]; then
		melodic=$word
		CorrectLine=0	
	elif [[ $CorrectLine == 11 ]]; then
		use_sfnr_masking=$word
		CorrectLine=0
	elif [[ $CorrectLine == 12 ]]; then
		confound_interpolation=$word
		CorrectLine=0	
	fi
	
	# Are you on the correct line
	if [[ $word == "highres_files(1)" ]]; then
		CorrectLine=1
	elif [[ $word == "fmri(regstandard)" ]]; then
		CorrectLine=2
	elif [[ $word == "fmri(regstandard_dof)" ]]; then
		CorrectLine=3
	elif [[ $word == "fmri(regstandard_search)" ]]; then
		CorrectLine=4
	elif [[ $word == "fmri(reghighres_search)" ]]; then
		CorrectLine=5
	elif [[ $word == "fmri(reghighres_dof)" ]]; then
		CorrectLine=6
	elif [[ $word == "confoundev_files(1)" ]]; then
		CorrectLine=7
	elif [[ $word == "example_func_files(1)" ]]; then
		CorrectLine=8
	elif [[ $word == "despiking_yn" ]]; then
		CorrectLine=9
	elif [[ $word == "fmri(melodic_yn)" ]]; then
		CorrectLine=10
	elif [[ $word == "use_sfnr_masking_yn" ]]; then
		CorrectLine=11
	elif [[ $word == "confound_interpolation_yn" ]]; then
		CorrectLine=12
	fi
	
done

# Overwrite the example func with the old one
yes | cp $Input_example_func example_func.nii.gz

# Run the registration command but only if it was run in the template
if [[ $highres != 0 ]]; then
	#${fslpath}/mainfeatreg -F 6.00 -d $path -l $path/logs/feat2_pre -R $path/report_unwarp.html -r $path/report_reg.html  -i $path/example_func.nii.gz -h $highres -x $reghighres_dof -x $reghighres_search -s $standard -y $regstandard_dof -z $regstandard_search

	# Get the path to the manual_reg, if it exists
	manual_reg_path="${SUBJECT_DIR}/analysis/firstlevel/Manual_Reg/"
	func_run=${Output_FEAT#*functional}
	func_run=${func_run%.feat*} # Remove the feat dir
	func_run=${func_run%_*} # Ignore any suffix for the func
	func_run=${func_run%%+*} # Ignore any duplicate suffixes

	# Is there a reg folder already?
	if [ -e $manual_reg_path/functional${func_run}/ ]
	then
		echo $manual_reg_path/functional${func_run}/, copying it over

		# Get the difference between the example funcs
		fslmaths $manual_reg_path/functional${func_run}/example_func.nii.gz -sub example_func.nii.gz reg_example_func_diff.nii.gz
		
		example_func_diff=`fslstats reg_example_func_diff.nii.gz -m`
		
		if (( $(echo "$example_func_diff == 0" | bc -l) ))
		then
			echo Copying over reg folder
			cp -R $manual_reg_path/functional${func_run} $Output_FEAT/reg/
		else
			echo Example_funcs do not match
		fi
	else
		echo $manual_reg_path/functional${func_run}/ does not exist, making a new reg folder
	fi
	
	# If there isn't a reg folder yet then make it with flirt
	if [ ! -e $Output_FEAT/reg/ ]
	then
		echo Running flirt
		
		# Submit as a job, it is not necessary to wait
		if [[ ${SCHEDULER} == slurm ]]
		then
			sbatch $PROJ_DIR/prototype/link/scripts/FEAT_reg.sh --FEAT_Folder $Output_FEAT --highres $highres --standard $standard
		elif [[ ${SCHEDULER} == qsub ]]
		then
			submit $PROJ_DIR/prototype/link/scripts/FEAT_reg.sh --FEAT_Folder $Output_FEAT --highres $highres --standard $standard 
		fi
		
	fi
fi

## Perform interpolation of TRs (to remove those that are confounds). Outputs file with the same name and resaves this file with '_raw' as a suffix
if [[ $confound_interpolation == 1 ]]
then
	echo "Performing interpolation"
	interpolation_type="mean_included" # Options include mean (average between adjacent TRs, including potentially ignored TRs), mean_included (take adjacent TRs when considering the included TRs
	yes | cp prefiltered_func_data.nii.gz prefiltered_func_data_raw.nii.gz # Back up
	if [[ ${SCHEDULER} == slurm ]]
	then
		matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('$PROJ_DIR/prototype/link/scripts/'); interpolate_TRs('prefiltered_func_data.nii.gz', 'prefiltered_func_data.nii.gz', '$Confound_File', '$interpolation_type'); exit"
	elif [[ ${SCHEDULER} == qsub ]]
	then
		submit $PROJ_DIR/prototype/link/scripts/interpolate_TRs.m prefiltered_func_data.nii.gz prefiltered_func_data.nii.gz $Confound_File $interpolation_type
	fi
else
	echo Skipping interpolation
fi

## Perform pre processing
echo "Perform motion correction"

# Run the motion correction
${fslpath}/mcflirt -in prefiltered_func_data -out prefiltered_func_data_mcf -mats -plots -reffile example_func -rmsrel -rmsabs -spline_final
/bin/mkdir -p mc ; /bin/mv -f prefiltered_func_data_mcf.mat prefiltered_func_data_mcf.par prefiltered_func_data_mcf_abs.rms prefiltered_func_data_mcf_abs_mean.rms prefiltered_func_data_mcf_rel.rms prefiltered_func_data_mcf_rel_mean.rms mc
cd mc
${fslpath}/fsl_tsplot -i prefiltered_func_data_mcf.par -t 'MCFLIRT estimated rotations (radians)' -u 1 --start=1 --finish=3 -a x,y,z -w 640 -h 144 -o rot.png 
${fslpath}/fsl_tsplot -i prefiltered_func_data_mcf.par -t 'MCFLIRT estimated translations (mm)' -u 1 --start=4 --finish=6 -a x,y,z -w 640 -h 144 -o trans.png 
${fslpath}/fsl_tsplot -i prefiltered_func_data_mcf_abs.rms,prefiltered_func_data_mcf_rel.rms -t 'MCFLIRT estimated mean displacement (mm)' -u 1 -w 640 -h 144 -a absolute,relative -o disp.png 
cd ..

# Perform slice timing correction
echo "Perform slice timing correction"
CorrectLine=0
for word in $FileInfo
do
	
	# If you are on the correct line the store all the words until you aren't
	if [[ $CorrectLine == 1 ]]; then
		TR=$word
		CorrectLine=0
		
	elif [[ $CorrectLine == 2 ]]; then
		slice_setting=$word
		
		# Depending on the slice_setting setting, do something different
		if [[ $slice_setting == 4 ]]; then
			slice_type=--tcustom
			
		elif [[ $slice_setting == 5 ]]; then
			slice_type=--odd
		fi
		CorrectLine=0
	elif [[ $CorrectLine == 3 ]]; then
		
		slice_timing_file=`echo ${word:1} | rev | cut -c 2- | rev`
		# Get the name of the slice timing file as an input		
		slice_type="${slice_type}=$slice_timing_file"

		CorrectLine=0
	
	fi
	
	# Are you on the correct line
	if [[ $word == "fmri(tr)" ]]; then
		CorrectLine=1
	elif [[ $word == "fmri(st)" ]]; then
		CorrectLine=2
	elif [[ $word == "fmri(st_file)" ]]; then
		CorrectLine=3
	fi
done

# Actually run the function
${fslpath}/slicetimer -i prefiltered_func_data_mcf --out=prefiltered_func_data_st -r $TR $slice_type  

# Generate the mask 
echo "Generating the mask"

${fslpath}/fslmaths prefiltered_func_data_st -Tmean mean_func

${fslpath}/bet2 mean_func mask -f 0.3 -n -m; ${fslpath}/immv mask_mask mask

if [[ $use_sfnr_masking == 1 ]]
then

	echo "Using SFNR for masking"
	
	# Backup the bet masked data
	mv mask.nii.gz mask_bet.nii.gz

	# Generate mask using the sfnr of the data
	if [[ ${SCHEDULER} == slurm ]]
	then
		matlab -nodesktop -nosplash -nodisplay -jvm -r "addpath('$PROJ_DIR/prototype/link/scripts/'); whole_brain_sfnr('prefiltered_func_data_st.nii.gz', './', '$Confound_File'); exit"
	elif [[ ${SCHEDULER} == qsub ]]
	then
		submit $PROJ_DIR/prototype/link/scripts/whole_brain_sfnr.m prefiltered_func_data_st.nii.gz ./ $Confound_File
	fi

	# Wait until this job has completed
	while [ ! -e sfnr_prefiltered_func_data_st.nii.gz ] 
	do 
	sleep 5s
	done

	# Fill in holes in the mask
	3dinfill -blend SOLID -ed 3 1 -prefix mask_sfnr.nii.gz -minhits 2 -input sfnr_mask_prefiltered_func_data_st.nii.gz

	# Is the SFNR mask appropriately sized to warrant inclusion? If not exit the script
	sfnr_voxels=$(IFS=" " ; set -- `fslstats mask_sfnr.nii.gz -V` ; echo $1)

	echo "$sfnr_voxels unmasked voxels"

	if [[ $sfnr_voxels -lt 70000 ]] && [[ $sfnr_voxels -gt 10000 ]]; then
		yes | cp mask_sfnr.nii.gz mask.nii.gz
	else
		echo "THE MASK IS THE WRONG SIZE, USING THE BET MASK INSTEAD"
		yes | cp mask_bet.nii.gz mask.nii.gz
	fi
else
	echo "Not using SFNR for masking"
fi

# Apply the mask
${fslpath}/fslmaths prefiltered_func_data_st -mas mask prefiltered_func_data_masked

range=`${fslpath}/fslstats prefiltered_func_data_masked -p 2 -p 98`

# # Re calculate the mask based on the masked values
# range=( $range )
# lowerbound=`echo ${range[0]}`
# upperbound=`echo ${range[1]}`
# 
# threshold=$(echo "$upperbound/10" | bc -l)
# ${fslpath}/fslmaths prefiltered_func_data_masked -thr $threshold -Tmin -bin mask -odt char

# Find the 50th percentile activation for prefiltered_func_data_st within the mask 
median_activation=`${fslpath}/fslstats prefiltered_func_data_st -k mask -p 50`

#${fslpath}/fslmaths mask -dilF mask

${fslpath}/fslmaths prefiltered_func_data_st -mas mask prefiltered_func_data_thresh

# Smooth the data
echo "Smoothing the data"

# Find the FWHM smoothing parameter from the fourth command of the SUSAN command
CorrectLine=0
word_counter=0
smoothing=8 # default, just incase you don't find it
for word in $FileInfo
do
	
	# If the word counter is up to 4
	if [[ $CorrectLine == 1 ]]; then
		smoothing=$word
		smoothing_sd=`echo "$smoothing / 2.3548" | bc -l` # To convert from FWHM to SUSAN you divide FWHM by 2*sqrt(log(2))=2.3548
		CorrectLine=0
	fi
	
	# Are you on the correct line
	if [[ $word == "fmri(smooth)" ]]; then
		CorrectLine=1
	fi

done

if (( $(echo "$smoothing > 0" | bc -l) )); then

	${fslpath}/fslmaths prefiltered_func_data_thresh -Tmean mean_func
	
	# Run SUSAN, the smoothing algorithm they use
	brightness_threshold=$(echo "$median_activation*.75" | bc -l)
	${fslpath}/susan prefiltered_func_data_thresh $brightness_threshold $smoothing_sd 3 1 1 mean_func $brightness_threshold prefiltered_func_data_smooth
	
	echo "${fslpath}/susan prefiltered_func_data_thresh $brightness_threshold $smoothing_sd 3 1 1 mean_func $brightness_threshold prefiltered_func_data_smooth"
	
	#Set the function to be masked and normalized
	temp_filtered_func=prefiltered_func_data_smooth
else
	#Set the function to be masked and normalized	
	temp_filtered_func=prefiltered_func_data_thresh
fi

#Intensity normalization and masking
echo "Performing intensity normalization and bandpass filtering"

${fslpath}/fslmaths $temp_filtered_func -mas mask $temp_filtered_func

normalization_factor=$(echo "10000/$median_activation" | bc -l)
${fslpath}/fslmaths $temp_filtered_func -mul $normalization_factor prefiltered_func_data_intnorm

echo "${fslpath}/fslmaths $temp_filtered_func -mul $normalization_factor prefiltered_func_data_intnorm"

${fslpath}/fslmaths prefiltered_func_data_intnorm -Tmean tempMean

# Find the bandpass filter
CorrectLine=0
for word in $FileInfo
do
	
	# If you are on the correct line then grab this word and stop looking
	if [[ $CorrectLine == 1 ]]; then
		bptf=`echo "$word / ($TR * 2)" | bc -l`
		CorrectLine=0
	fi
		
	# Are you on the correct line
	if [[ $word == "fmri(paradigm_hp)" ]]; then
		CorrectLine=1
	fi

done
${fslpath}/fslmaths prefiltered_func_data_intnorm -bptf $bptf -1 -add tempMean prefiltered_func_data_tempfilt

${fslpath}/imrm tempMean

${fslpath}/fslmaths prefiltered_func_data_tempfilt filtered_func_data

# Despike the filtered_func
if [ $despiking -eq 1 ]
then

	echo "Running despiking"
	mv filtered_func_data.nii.gz filtered_func_data_original.nii.gz

	3dDespike -prefix filtered_func_data_despiked.nii.gz filtered_func_data_original.nii.gz

	yes | cp filtered_func_data_despiked.nii.gz filtered_func_data.nii.gz

else
	echo "Skipping despiking"
fi

# Run MELODIC
if [ $melodic -eq 1 ]
then
	seed=0 # Set the seed, if it is -1 then it will be random, otherwise it is the number supplied
	echo "Running MELODIC, using seed $seed"
	${fslpath}/melodic -i filtered_func_data -o filtered_func_data.ica -v --nobet --bgthreshold=1 --tr=$TR -d 0 --mmthresh=0.5 --report --guireport=../../report.html --seed=$seed
else
	echo "Skipping MELODIC"
fi
