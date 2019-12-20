#!/bin/bash
#
# Run the ICA script in matlab for detecting outliers
#
#SBATCH --output=feat_ICA-%j.out
#SBATCH -p short
#SBATCH -t 120
#SBATCH --mem 20000

# Load the globals (need to change directory)
current_dir=`pwd`
cd ${current_dir%analysis/*}
source globals.sh
cd ${current_dir}

# Submit these jobs
submit_jobs=$1
ICA_Threshold=$2
current_dir=$3

matlab -nodesktop -nosplash -r "addpath $PROJ_DIR/subjects/$SUBJ/scripts/; ICA_Motion_Detector($submit_jobs, $ICA_Threshold, $current_dir); exit"
