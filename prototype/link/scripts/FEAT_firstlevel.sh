#!/bin/bash
#
# Create the FEAT analysis appropriate for the firstlevel of processing 
# that implements features unique to infant_neuropipe
#
# This does a normal FEAT analysis but with a few extra additions: 
#   Uses the centroid TR for registration and motion correction
#   Interpolates TRs that are to be excluded before you do detrending so that they have minimal effect on analyses
#   Uses the SFNR values as the criteria for excluding brain and nonbrain, rather than mean intensity
#   Despikes the voxel time courses to remove outliers
# 
# This script also supports ./scripts/manual_registration.sh by using a premade reg folder if available
#
# It no longer runs MELODIC by default but can support it if necessary
#
# To run this, provide the full fsf file path. It will then extract the information from this to run the FEAT.
#
# This code directly uses a specific TR (found here: analysis/firstlevel/Confounds/examplefunc_functionalXX.nii.gz) for registration and motion correction. 
# This is the centroid TR selected by scripts/prep_raw_data.m. However, if this TR is still not optimal (e.g. has less anatomical information than other time-points due to noise), you could change it yourself by replacing that TR with the one desired.
#
# First made by C Ellis 2/21/17
# Added Slurm functionality C Ellis 8/10/17
#
#SBATCH --output=./logs/feat_firstlevel-%j.out
#SBATCH -p short
#SBATCH -t 300
#SBATCH --mem 20000

# Store the inputs
fsf_path=$1

source globals.sh

echo "Running feat for $fsf_path"

# Pull out the fsl path (assumes that FSL has been loaded)
fslpath=`which feat`
fslpath=${fslpath%feat}

# Find what the feat output ought to be
FileInfo=`cat $fsf_path`
CorrectLine=0
for word in $FileInfo
do
	
	# If you are on the correct line the store all the words until you aren't
	if [[ $CorrectLine == 1 ]]; then
		fsf_base=$word
		fsf_base=`echo ${fsf_base:1} | rev | cut -c 2- | rev`
		
		if [ ${fsf_base:(-4)} == feat ]; then
			fsf_base=`echo $fsf_base | rev | cut -c 6- | rev`
		fi
		CorrectLine=0
	elif [[ $CorrectLine == 2 ]]; then
		# What is the ICA cut off threshold
		ICA_Correlation=$word
		CorrectLine=0
	fi
	
	# Are you on the correct line
	if [[ $word == "fmri(outputdir)" ]]; then
		CorrectLine=1
	elif [[ $word == "fmri(melodic_corr_threshold)" ]]; then
		CorrectLine=2
	fi
	
done

# If the directory exists then name it with a plus on the end
FEAT_Name=${fsf_base}
while [ -d ${FEAT_Name}.feat ]
do
	FEAT_Name=${FEAT_Name}+
done

echo "Initializing the feat directory"
Output_FEAT=${FEAT_Name}.feat

# Make the new feat name and move into that directory
mkdir ${Output_FEAT}; cd ${Output_FEAT};

# Put the fsf file in the newly created feat folder
yes | cp ${fsf_path} ${Output_FEAT}/design.fsf

# Make the relevant design files
${fslpath}/feat_model design

# Set up some files
mkdir .files;cp ${fslpath}/../doc/fsl.css .files;cp -r ${fslpath}/../doc/images .files/images

# Initialize the feat analysis

jid_init=`${fslpath}/fsl_sub -T 10 -l logs -N feat0_init   ${fslpath}/feat ${Output_FEAT}/design.fsf -D ${Output_FEAT} -I 1 -init`

#Wait for initalize to complete in order to  start the prestats script
echo Run prestats

if [[ ${SCHEDULER} == slurm ]]
then
	SubmitName=`sbatch --dependency=afterok:${jid_init} -p $SHORT_PARTITION $PROJ_DIR/prototype/link/scripts/FEAT_prestats.sh ${Output_FEAT}`
elif [[ ${SCHEDULER} == qsub ]]
then
	SubmitName=`submit_long -hold_jid ${jid_init} $PROJ_DIR/prototype/link/scripts/FEAT_prestats.sh ${Output_FEAT}`
fi

#What is the name of the file
jid_prestats=`echo $SubmitName | awk '{print $NF}'`

echo Run the ICA 
if [[ ${SCHEDULER} == slurm ]]
then
	echo sbatch --dependency=afterok:${jid_prestats} -p $SHORT_PARTITION $PROJ_DIR/prototype/link/scripts/run_ICA_Motion_Detector.sh 1 $ICA_Correlation 1
	SubmitName=`sbatch --dependency=afterok:${jid_prestats} -p $SHORT_PARTITION $PROJ_DIR/prototype/link/scripts/run_ICA_Motion_Detector.sh 1 $ICA_Correlation 1`
elif [[ ${SCHEDULER} == qsub ]]
then
	SubmitName=`submit -hold_jid ${jid_prestats} $PROJ_DIR/prototype/link/scripts/ICA_Motion_Detector.m 1 $ICA_Correlation 1`
fi

#What is the name of the file
jid_ica=`echo $SubmitName | awk '{print $NF}'`

# Submit stats
echo Run stats
if [[ ${SCHEDULER} == slurm ]]
then
	SubmitName=`sbatch --dependency=afterok:${jid_ica} -p $SHORT_PARTITION $PROJ_DIR/prototype/link/scripts/FEAT_stats.sh ${Output_FEAT}`
elif [[ ${SCHEDULER} == qsub ]]
then
	SubmitName=`submit -hold_jid ${jid_ica} $PROJ_DIR/prototype/link/scripts/FEAT_stats.sh ${Output_FEAT}`
fi

# Wait for these jobs to be finished
while [ ! -e ${Output_FEAT}/stats/smoothness ] 
do 
sleep 60s
done

# The hidden files that were made often have the wrong permissions
chmod -R 770 ${Output_FEAT}

#Submit post stats
echo "Performing post stats"
${fslpath}/fsl_sub -T 20 -l logs -N feat4_post ${fslpath}/feat ${Output_FEAT}/design.fsf  -D ${Output_FEAT} -poststats 0
