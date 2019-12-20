#!/bin/bash
#
# Run the transfer of coder files script in matlab

#SBATCH --output=./logs/transfer_coder_files-%j.out
#SBATCH -p short
#SBATCH -t 4:00:00
#SBATCH --mem 10000

source globals.sh


matlab -nodesktop -nosplash -nodisplay -nojvm -r "addpath('scripts/'); addpath('scripts/Gaze_Categorization/scripts/'); transfer_coder_files; exit"

