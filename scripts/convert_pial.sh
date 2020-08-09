#!/bin/bash

# Convert pial surfaces for a ppt into stl files to make them dowloadable

module load FreeSurfer

ppt=$1 # What participant are you loading

files=`ls subjects/$ppt/analysis/freesurfer/*/surf/?h.pial`

for file in $files
do

# Convert the files
mris_convert $file ${file}.stl

done
