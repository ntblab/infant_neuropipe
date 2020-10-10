#!/bin/bash
#
# Take screenshots of the iBEAT output (can be run on normal freesurfer too)
# 
# Requires a freesurfer directory is supplied
#
# To run, either jump on an interactive node (srun --x11 --pty bash) and then run or launch interactive job:
# srun --x11 --pty ./scripts/iBEAT/iBEAT_QC.sh analysis/freesurfer/iBEAT/
#
#SBATCH --output=./logs/iBEAT_QC-%j.out
#SBATCH -p short
#SBATCH -t 20
#SBATCH --mem 2000

source globals.sh

# What is the freesurfer directory (relative path is sufficient)
if [ "$#" -eq 0 ]; then
echo No arguments supplied, exiting.
exit
fi

# Load the freesurfer directory
fs_dir=$1

echo Using $fs_dir

curr_dir=$(pwd) # Preserve

# Move into the freesurfer directory
cd $fs_dir

mkdir -p screenshots/

# Run the freeview QC
srun --x11 --pty freeview -cmd ${curr_dir}/scripts/iBEAT/iBEAT_QC_cmd.txt

# For some reason the alignment is correct for this version but not 6.0.0
module load FreeSurfer/5.3.0 
srun --x11 --pty freeview -cmd ${curr_dir}/scripts/iBEAT/iBEAT_QC_surface_cmd.txt

# Make the html summarizing this pipeline
QC_template=${curr_dir}/scripts/iBEAT/iBEAT_QC_summary.template
fs_dir=$(pwd) # Just incase a relative path was provided
output_template=${fs_dir}/iBEAT_QC_summary.html
cat $QC_template | sed "s:<?= \$FS_DIR ?>:$fs_dir:g" > $output_template 

# Make the firefox output for use
firefox $output_template

echo Finished
