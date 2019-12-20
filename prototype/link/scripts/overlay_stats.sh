#!/bin/bash
#
# Overlays the 3d input image with an anatomical image, useful for
# displaying stats.
#
# Specify input, highres and output images. Find the range of the
# anatomical image. Make an inverted input file temporally so that min
# max can be used again. Run the overlay.

input=$1
highres=$2
output=$3

source ./globals.sh

# What are the zstat bounds
if [ $# -lt 4 ]
then
	zmin=2.3
	zmax=3
else
	zmin=$4
	zmax=$5
fi

# Find the bounds of the anatomical
min=`fslstats $highres -p 0`
max=`fslstats $highres -p 100`

# Make an inverse volume (use this name to avoid overwritting if running things simultaneously)
fslmaths $input -mul -1 $output

# Overlay the results
overlay 0 0 $highres $min $max $input $zmin $zmax $output $zmin $zmax $output
