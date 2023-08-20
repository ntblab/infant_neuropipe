#!/bin/bash
# author: mgsimon@princeton.edu
# this script sets up global variables for the analysis of the current subject
# Edited by C Ellis 6/23

set -e # stop immediately when an error occurs

###### THINGS TO CHANGE ######
export BXH_DIR= # Full path to BXH_XCEDE binary file
PROJ_DIR= # Full path to project directory file
TR= # TR duration in seconds
PACKAGES_DIR= # Full path to package directory
ATLAS_DIR= #Full path to atlas directory
SCHEDULER=slurm  # Default scheduler
SHORT_PARTITION=short # Partition for jobs <6 hours
LONG_PARTITION=verylong # Partition for jobs >24 hours

# Modules
# Load Matlab (tested on R2016b)
# Load AFNI (tested on 2017-08-11)
# Load FSL (tested on 5.0.9)
# Load Anacoda with python 3.5
# Load Freesurfer (tested on 6.0.0)
# Load BXH_XCEDE tools (tested on 1.11.14)
# Load brainiak (tested on 0.7.1)
# Load nilearn (tested on 0.4.0)
# Load ANTs (tested on 2.3.1-foss-2018a)

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
