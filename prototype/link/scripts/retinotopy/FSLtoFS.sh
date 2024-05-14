#!/bin/bash

#Takes in the Feat reg folder of the secondlevel data and makes it interoperatable with Freesurfer
#To do this it first finds the registration.feat directories and then adds relevant information
#It copies in the registration directory from the other analysis and then converts files as appropriate
#
# Naz Fall 2010
# Vik 0313 adapting for sculpt01 retmap analysis
# Cellis 0616 made for the development project
#
#SBATCH --output=logs/fsltofs-%j.out
#SBATCH -p short
#SBATCH -t 300
#SBATCH --mem 20G

set -ue

source ./globals.sh

SUBJECTS_DIR=analysis/freesurfer/; export SUBJECTS_DIR;

if [ $# -eq 0 ]
then
	FreesurferFolder="recon"
	echo "No Freesurfer folder supplied. Assuming recon"
else
	FreesurferFolder=$1
fi

featDir=analysis/secondlevel/registration.feat

if [ ! -d ${featDir}/stats/ ]; then
mkdir ${featDir}/stats/
fi

yes | cp $REGCONCAT_DIR/default/func2highres.nii.gz ${featDir}/stats/func2highres.nii.gz

echo 'Replacing bad transformation matrices with good ones'
yes | cp -f scripts/retinotopy/identitymatrix.mat $featDir/reg/example_func2initial_highres.mat
updatefeatreg $featDir/

#Allows FSL and Freesurfer to speak the same language
#Take a look at this web address to see what this does: http://www.fmrib.ox.ac.uk/fsl/freesurfer/index.html
echo 'Running FSL-FS interoperability programs'
if [[ ${SCHEDULER} == slurm ]]
then
	SubmitName=`sbatch scripts/retinotopy/run_reg-feat2anat.sh ${featDir} ${FreesurferFolder}`
elif [[ ${SCHEDULER} == qsub ]]
then
	SubmitName=`submit scripts/retinotopy/run_reg-feat2anat.sh ${featDir} ${FreesurferFolder}` #Submit and get the name
fi

echo Submitted $SubmitName to make an anat folder

#What is the name of the file
JobID=`echo $SubmitName | awk '{print $NF}'`

if [[ ${SCHEDULER} == slurm ]]
then
	SubmitName=`sbatch --dependency=afterok:${JobID} scripts/retinotopy/run_feat2surf.sh ${featDir}`
elif [[ ${SCHEDULER} == qsub ]]
then
	submit -hold_jid ${JobID} scripts/retinotopy/feat2surf.sh ${featDir} #Submit this because it will take long, must be submitted after the above has completed since there are contingencies
fi

echo Submitted $SubmitName to make a surf folder
