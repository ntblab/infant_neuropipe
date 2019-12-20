#!/bin/bash
#
# When performing statistics FEAT (as in you have done the
# preprocessing), the analysis creates a mask from the filtered func
# which assumes the values range from 0 to inf. However, if using z
# scored or res4d information as the input then this will not be true
# since negative values are common. To correct for this, supply a mask
# (probably from the original feat) that will then be substituted in.
# 
# Critically, the design MUST be the same in the template FEAT directory
# compared to the one you wish to create. If you change confounds or EVs
# this won't work
# 
# This command takes the following inputs:
# 
# A path to a FEAT directory to be used as a template. This should
# contain the mask that will be used. 
# The name of the FEAT directory to be created. 
# The path to the new filtered_func you want to use for computing stats
# 
# The commands will then be run for this data as a normal FEAT analysis
# would run.
# 
# First made by C Ellis 2/21/17
# Made compatible with other needs for FEAT_stats
# 
#SBATCH --output=feat_stats-%j.out
#SBATCH -p short
#SBATCH -t 300
#SBATCH --mem 20000

echo "Running stats"

# Store the inputs
Base_FEAT=$1
Output_FEAT=$2
Input_filtered_func=$3

# Where are all the necessary fsl files stored?
fslpath=`which feat`
fslpath=${fslpath%feat}

# If you are trying to just run stats, given a design fsf then you will do it differently then if you want to rerun stats given a new functional
Prewhitening="--noest "
if [ $# -eq 1 ]
then
	Output_FEAT=$Base_FEAT
	
	FileInfo=`cat design.fsf`
	CorrectLine=0
	EVCounter=1
	for word in $FileInfo
	do
		
		# If an EV is supplied then make a timing file for it.
		if [[ $CorrectLine == 1 ]]; then
			if [[ ${#word} == 2 ]]; then
				CorrectLine=0
			else
				# Create the timing file (by copying the evs into custom_timing_files. It doesn't seem necessary but helps)
				EVFile=$word
				EVFile=`echo ${EVFile:1} | rev | cut -c 2- | rev`
				mkdir -p custom_timing_files; ${fslpath}fslFixText $EVFile custom_timing_files/ev${EVCounter}.txt
				EVCounter=$(echo "$EVCounter+1" | bc -l)
				CorrectLine=0
			fi
		elif [[ $CorrectLine == 2 ]]; then
			ConfoundFile=$word
			ConfoundFile=`echo ${ConfoundFile:1} | rev | cut -c 2- | rev`
			CorrectLine=0
		elif [[ $CorrectLine == 3 ]]; then
			MotionParameters=$word
			CorrectLine=0
		elif [[ $CorrectLine == 4 ]]; then
			if [[ ${word} == 1 ]]; then
				Prewhitening="--sa --ms=5 "
			fi
			CorrectLine=0
		fi
		
		if [[ $word == "fmri(custom${EVCounter})" ]]; then
			CorrectLine=1
			
		elif [[ $word == "confoundev_files(1)" ]]; then
			CorrectLine=2		
			
		elif [[ $word == "fmri(motionevs)" ]]; then
			CorrectLine=3	
		elif [[ $word == "fmri(prewhiten_yn)" ]]; then	
			CorrectLine=4
		fi
	
	done
	
	# If there is a motion parameter supplied then concatenate it with the confound file, otherwise just use the confound file
	if [[ $MotionParameters == 0 ]]; then
		yes | cp ${ConfoundFile} confoundevs.txt
	else
		
		# If it is extended motion parameters then you need to calculate that here
		if [[ $MotionParameters == 2 ]]; then
			
			mp_diffpow.sh mc/prefiltered_func_data_mcf.par mc/prefiltered_func_data_mcf_diff

			paste -d ' ' mc/prefiltered_func_data_mcf.par mc/prefiltered_func_data_mcf_diff.dat  > mc/prefiltered_func_data_mcf_final.par
		else
			cp mc/prefiltered_func_data_mcf.par mc/prefiltered_func_data_mcf_final.par
		fi
		
		paste -d  ' '  mc/prefiltered_func_data_mcf_final.par ${ConfoundFile} > confoundevs.txt

	fi
	
	# Create the model for Stats
	${fslpath}feat_model design confoundevs.txt
	
	# The default value after intensity normalization
	min=1000
	
else

	## Pre processing

	# Make a copy of the new FEAT
	yes | cp -rf $Base_FEAT $Output_FEAT

	# Move the filtered_func
	yes | cp $Input_filtered_func ${Output_FEAT}/filtered_func_data.nii.gz

	# Move into the dir
	cd $Output_FEAT

	# Get the range of values
	range=`${fslpath}fslstats filtered_func_data -k mask -R | awk '{ print  }' -`

	# Convert into the relevant format
	range=( $range )

	# Pull out the min
	min=`echo ${range[0]}`

	# Calculate the mean func
	${fslpath}fslmaths filtered_func_data -Tmean mean_func
	
	#Remove the current stats folder
	rm -rf ./stats/
	
	# Is there an f test 
	
fi

## Run the stats 

# Make the linear model
if [ -e design.fts ]; then
	${fslpath}film_gls --in=filtered_func_data --rn=stats --pd=design.mat --thr=$min $Prewhitening --con=design.con  --fcon=design.fts
else
	${fslpath}film_gls --in=filtered_func_data --rn=stats --pd=design.mat --thr=$min $Prewhitening --con=design.con  
fi	

# Calculate the dparameter (the number of rows minus the number of columns in the design matrix)
FileInfo=`cat design.mat`
NextCharacter=0
for word in $FileInfo
do
	if [[ $NextCharacter == 1 ]]; then
		TRs=$word
	elif [[ $NextCharacter == 2 ]]; then
		Waves=$word
	fi
	if [[ $word == "/NumPoints" ]]; then
		NextCharacter=1
	elif [[ $word == "/NumWaves" ]]; then
		NextCharacter=2
	else
		NextCharacter=0
	fi
done

dparameter=`expr $TRs - $Waves`

# Calculate the smoothness of the res4d
${fslpath}smoothest -d $dparameter   -m mask -r stats/res4d > stats/smoothness

# If you are doing FEAT_stats for 'Statistics only' also run post stats 
if [ $# -eq 3 ]
then
	
	#Submit post stats
	echo "Performing post stats"
	${fslpath}fsl_sub -T 20 -l logs -N feat4_post ${fslpath}feat ${Output_FEAT}/design.fsf  -D ${Output_FEAT} -poststats 0

fi


# # Pull out the information from the smoothness calculation
# FileInfo=`cat stats/smoothness`
# NextCharacter=0
# for word in $FileInfo
# do
# 	if [[ $NextCharacter == 1 ]]; then
# 		Voxel_number=$word
# 	elif [[ $NextCharacter == 2 ]]; then
# 		DLH=$word
# 	fi
# 	if [[ $word == "VOLUME" ]]; then
# 		NextCharacter=1
# 	elif [[ $word == "DLH" ]]; then
# 		NextCharacter=2
# 	else
# 		NextCharacter=0
# 	fi
# done
#
# ## Post Stats
# 
# path=`pwd`
# jid_poststats=`/opt/pkg/FSL/fsl/bin/fsl_sub -T 20 -l logs -N feat4_post /opt/pkg/FSL/fsl/bin/feat $path/design.fsf -D $path -poststats 0`
# 
# /opt/pkg/FSL/fsl/bin/fsl_sub -T 1 -l logs -N feat5_stop -j ${jid_poststats}  /opt/pkg/FSL/fsl/bin/feat $path/design.fsf -D $path -stop
# 
# 
# # Pull out the z thresholds from the report
# FileInfo=`cat report_log.html`
# NextCharacter=0
# CorrectLine=0
# pvalue=0.05 # Defaults
# Z_Threshold=2.3 # Defaults
# for word in $FileInfo
# do
# 	if [[ $NextCharacter == 1 ]]; then
# 		Z_Threshold=$word
# 	elif [[ $NextCharacter == 2 ]]; then
# 		pvalue=$word
# 		CorrectLine=0
# 	fi
# 	
# 	# Are you on the correct line
# 	if [[ $word == "/opt/pkg/FSL/fsl/bin/cluster" ]]; then
# 		CorrectLine=1
# 	fi
# 	
# 	if [[ $word == '-t' ]] && [[ $CorrectLine == 1 ]]; then
# 		NextCharacter=1
# 	elif [[ $word == '-p' ]] && [[ $CorrectLine == 1 ]]; then
# 		NextCharacter=2
# 	else
# 		NextCharacter=0
# 	fi
# done
# 
# # How many contrasts were performed?
# FileInfo=`cat design.con`
# NextCharacter=0
# for word in $FileInfo
# do
# 	if [[ $NextCharacter == 1 ]]; then
# 		Contrast_Number=$word
# 	fi
# 	if [[ $word == "/NumContrasts" ]]; then
# 		NextCharacter=1
# 	else
# 		NextCharacter=0
# 	fi
# done
# 
# # For each contrast, perform the following thresholding and slicing
# for con_num in `seq 1 $Contrast_Number`
# 
# do
# 	
# 	# Mask the z stat
# 	/opt/pkg/FSL/fsl/bin/fslmaths stats/zstat1 -mas mask thresh_zstat${con_num}
# 	
# 	# How many voxels are there
# 	echo $Voxel_number > thresh_zstat${con_num}.vol
# 	
# 	# Cluster threshold the data
# 	/opt/pkg/FSL/fsl/bin/cluster -i thresh_zstat${con_num} -c stats/cope${con_num} -t $Z_Threshold -p $pvalue -d $DLH --volume=$Voxel_number --othresh=thresh_zstat${con_num} -o cluster_mask_zstat${con_num} --olmax=lmax_zstat${con_num}.txt --scalarname=Z > cluster_zstat${con_num}.txt
# 	
# 	# Convert cluster data into html
# 	/opt/pkg/FSL/fsl/bin/cluster2html . cluster_zstat${con_num} 
# 	
# 	# Calculate the upper and lower bounds of the Z maps
# 	range=`/opt/pkg/FSL/fsl/bin/fslstats thresh_zstat${con_num} -l 0.0001 -R 2>/dev/null`
# 	
# 	# Reorganize
# 	range=( $range )
# 
# 	# Pull out the min
# 	Zlowerbound=`echo ${range[0]}`
# 	Zupperbound=`echo ${range[1]}`
# 	
# 	# Overlay he volume
# 	/opt/pkg/FSL/fsl/bin/overlay 1 0 example_func -a thresh_zstat${con_num} ${Zlowerbound} ${Zupperbound} rendered_thresh_zstat${con_num}
# 	
# 	# Show the data
# 	/opt/pkg/FSL/fsl/bin/slicer rendered_thresh_zstat${con_num} -A 750 rendered_thresh_zstat${con_num}.png
# 
# done
# 
# /bin/cp /opt/pkg/FSL/fsl/etc/luts/ramp.gif .ramp.gif
