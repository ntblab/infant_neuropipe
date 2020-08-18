#!/usr/bin/env bash
# Run the supersubject analyses on the stat learning data. This takes all of the participant data meeting the criteria specified, and taking the ROI specified, then randomly samples the participants with replacement, according to the seed provided, to create the average values for each ROI and each participant. The output is a dictionary containing keys for each of the 6 blocks, and numpy matrices for each code corresponding to the participants x ROI matrix. If seed is set to -1 then no shuffling is done and the 'true' results are reported. currently the `ppt_condition` is irrelevant, but could be editted if other criteria were added
#
# sbatch scripts/StatLearning/run_supersubject_StatLearning.sh 0 _both_halves 0 1
#
#SBATCH --output=logs/supersubject_statlearning-%j.out
#SBATCH -p short
#SBATCH -t 30
#SBATCH --mem 10000

# Load in the appropriate environment
source ./globals.sh

input_seed=$1 # What is the input seed used in the randomizer for picking participants
ppt_condition=$2 # What is the participant condition being used
posterior_anterior=$3 # Do you want to subsample the ROI (-1 posterior, 0 all, 1 anterior)
bilateral_masks=$4 # Do you want to collapse bilaterally (0 no, 1 yes)

# Run the python script
python ./scripts/StatLearning/supersubject_StatLearning.py $input_seed $ppt_condition $posterior_anterior $bilateral_masks
