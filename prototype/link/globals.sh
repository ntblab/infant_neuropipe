#!/bin/bash
# author: mgsimon@princeton.edu
# this script sets up global variables for the analysis of the current subject
# Edited by C Ellis 6/23

set -e # stop immediately when an error occurs

###### THINGS TO CHANGE ######
export BXH_DIR=/nexsan/apps/hpc/Tools/BXH_XCEDE/1.11.14/bin
PROJ_DIR=/gpfs/milgram/project/turk-browne/projects/dev_neuropipe/
TR=2
PACKAGES_DIR=/gpfs/milgram/project/turk-browne/packages/
ATLAS_DIR=/gpfs/milgram/project/turk-browne/shared_resources/atlases/
SCHEDULER=slurm  
SHORT_PARTITION=short # Partition for jobs <6 hours
LONG_PARTITION=verylong # Partition for jobs >24 hours

# Modules
module load Apps/Matlab/R2016b
module load Apps/AFNI/2017-08-11
module load Apps/FSL/5.0.9
module load Langs/Python/3.5-anaconda
module load Apps/FREESURFER/6.0.0
module load Tools/BXH_XCEDE/1.11.14
module load Pypkgs/brainiak/0.7.1-anaconda
module load Pypkgs/NILEARN/0.4.0-anaconda

. ${FSLDIR}/etc/fslconf/fsl.sh
#. /apps/hpc/Apps/FREESURFER/6.0.0/FreeSurferEnv.sh

##############################

# If this file exists (won't when you are in the project directory)
if [ -e scripts/subject_id.sh ]
then
	source scripts/subject_id.sh  # this loads the variable SUBJ
fi

SUBJECTS_DIR=$PROJ_DIR/subjects/
SUBJECT_DIR=$PROJ_DIR/subjects/$SUBJ
ALL_SUBJECTS=`ls $SUBJECTS_DIR`

RUNORDER_FILE=run-order.txt

DATA_DIR=data
SCRIPT_DIR=scripts
FSF_DIR=fsf
DICOM_ARCHIVE=data/raw.tar.gz
NIFTI_DIR=data/nifti
QA_DIR=data/qa
BEHAVIORAL_DATA_DIR=data/behavioral
FIRSTLEVEL_DIR=analysis/firstlevel
SECONDLEVEL_DIR=analysis/secondlevel
EV_DIR=design
BEHAVIORAL_OUTPUT_DIR=output/behavioral
PRESTATS_DIR='analysis/firstlevel'
REGCONCAT_DIR='analysis/secondlevel'
BURNIN_DURATION=6
DECAY_DURATION=6

# Fill in below variables to fit your roi analysis -- all are used in roi.sh or scripts called within it
ROI_COORDS_FILE=design/roi.txt
LOCALIZER_DIR=analysis/firstlevel/localizer_hrf.feat
ROI_DIR=results/roi
ROI_KERNEL_TYPE=sphere
ROI_KERNEL_SIZE=4
