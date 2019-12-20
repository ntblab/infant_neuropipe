#!/bin/bash
#
# Create the FEAT analysis appropriate for the firstlevel task versus rest contrast. 
# This takes the timing files from the firstlevel folders and grabs only the block onset and duration information
# It also creates a new fsf file with the appropriate task vs rest contrast set up
# This job is submitted and runs
# When it finishes, analyses are run to compare the motion parameters with the task design to see if motion is correlated with task.
#
#SBATCH --output=./logs/feat_univariate-%j.out
#SBATCH -p short
#SBATCH -t 300
#SBATCH --mem 2000

# Provide the participant folder path
if [ $# -eq 1 ]
then
	ParticipantFolder=$1
else
	ParticipantFolder=`pwd`
fi

cd $ParticipantFolder

# Set up environment
source globals.sh

# Where is the fsf file stored
firstlevel_dir=${ParticipantFolder}/analysis/firstlevel

#Find the default fsf directories (including pseudoruns)
temp_fsf_paths=`ls -d $PRESTATS_DIR/functional*.fsf`

# You need to remove any non-default files from this list 
fsf_paths=''
for fsf_path in $temp_fsf_paths
do

# If this folder name has an underscore then it shouldn't be included
if [[ $fsf_path != *"functional"*"_"*".fsf" ]]
then
fsf_paths="${fsf_paths} ${fsf_path}"
fi

done

fsfNumber=`echo $fsf_paths | wc -w`

# Quit the script if necessary
if [ $fsfNumber -eq 0 ]
then
	echo "No feat directories detecting. Quiting"
	exit
fi

# Iterate through the fsf files until there are none left
for fsf_path in $fsf_paths
do

	## Aggregate all of the timing files
	echo "Making aggregate timing file"
	
	func_number=`echo ${fsf_path#*functional}`; func_number=`echo ${func_number%.fsf}`; 
	
	# Pull out timing file names
	timingFiles=`find ${firstlevel_dir}/Timing/ -maxdepth 1 -name "functional${func_number}*.txt"`

	# Iterate through the timing files that aren't events or conditions or RestingState and concatenate these timing files
	concatenatedTiming=${firstlevel_dir}/Exploration/functional${func_number}.txt
	rm -f $concatenatedTiming
	for word in $timingFiles
	do
		if [[ $word != *Events.txt ]] && [[ $word != *Condition*.txt ]] && [[ $word != *RestingState*.txt ]]; then
			cat $word >> $concatenatedTiming
		fi
	done
	
	# Check that the timing file exists. If it doesn't then skip running these analyses since it won't work
	if [ -e $concatenatedTiming ]
	then
		
		# Edit the fsf file, changing the output name, disabling registration and adding the EVs
	
		new_fsf=${firstlevel_dir}/Exploration/functional${func_number}.fsf
		defaultOutput=${firstlevel_dir}/functional${func_number}.feat
		newOutput=${firstlevel_dir}/Exploration/functional${func_number}_univariate.feat
		defaultEVname='""'; EVname='"Task"'
		concatenatedTiming="\"$concatenatedTiming\""
	
		# Needs to be done in two parts because of formatting issues
		cat $fsf_path \
		| sed "s:fmri(reghighres_yn) 1:fmri(reghighres_yn) 0:g" \
		| sed "s:fmri(regstandard_yn) 1:fmri(regstandard_yn) 0:g" \
		| sed "s:$defaultOutput:$newOutput:g" \
		| sed "s:fmri(evtitle1) $defaultEVname:fmri(evtitle1) $EVname:g" \
			> temp.fsf #Output to this file
	
		cat temp.fsf \
		| sed "s:fmri(shape1) 0:fmri(shape1) 3:g" \
		| sed "s:fmri(convolve1) 2:fmri(convolve1) 3:g" \
		| sed "s:# Skip (EV 1):# Custom EV file (EV 1):g" \
		| sed "s:set fmri(skip1) 0:set fmri(custom1) $concatenatedTiming:g" \
		| sed "s:set fmri(off1):#set fmri(off1):g" \
		| sed "s:set fmri(on1):#set fmri(on1):g" \
		| sed "s:set fmri(phase1):#set fmri(phase1):g" \
		| sed "s:set fmri(stop1):#set fmri(stop1):g" \
		| sed "s:set fmri(gammasigma1):#set fmri(gammasigma1):g" \
		| sed "s:set fmri(gammadelay1):#set fmri(gammadelay1):g" \
			> $new_fsf 
	
		rm -f temp.fsf 
	
		# Run the fsf file through FEAT_firstlevel.sh
	
		if [[ ${SCHEDULER} == slurm ]]
		then
			SubmitName=`sbatch -p $SHORT_PARTITION ./scripts/FEAT_firstlevel.sh $new_fsf`
		else
			SubmitName=`submit ./scripts/FEAT_firstlevel.sh $new_fsf`
		fi
	
		# Pull out the job ID
		jid_firstlevel=`echo $SubmitName | awk '{print $NF}'`
	else
		echo "No timing file was created because there are no included blocks for run $func_number. Not running a feat"
	fi
done

# Figure out the correlation of the participant motion to the task design
if [[ ${SCHEDULER} == slurm ]]
then
	sbatch --dependency=afterany:${jid_firstlevel} ./scripts/run_Analysis_DesignMotion.sh
else
	submit -hold_jid ${jid_firstlevel} ./scripts/run_Analysis_DesignMotion.sh
fi
