#!/bin/bash
#
# Create convexity files in standard space. Assumes that the SUMA folder has been created for the participant. 
#
# This uses the convexity files are in a scratch folder. This step is done automatically by the iBEAT preprocessing pipeline in infant_neuropipe. To make the 1d conv files (should be made already) use: SurfaceMetrics -conv -i_fs ${fs_dir}/surf/rh.orig -prefix ${fs_dir}/scratch/rh

#SBATCH --output=logs/generate_std_conv-%j.out
#SBATCH -p short
#SBATCH -t 4:00:00
#SBATCH --mem 20G

source globals.sh
module load AFNI

fs_name=$1 # Presumably it is iBEAT

cd analysis/freesurfer/${fs_name}

# Run the command
for hemi in lh rh
do

# Convert the surfaces
SurfToSurf -i SUMA/std.141.${hemi}.smoothwm.asc -i SUMA/${hemi}.smoothwm.asc -dset scratch/${hemi}.conv.1D.dset -prefix SUMA/std.141.${hemi}.conv.1D.dset

# Strip the first column of this file since it is the second that is the relevant one
1dcat -sel '[1]' SUMA/std.141.${hemi}.conv.${hemi}.conv.1D.dset > SUMA/std.141.${hemi}.conv.1D.dset

done
