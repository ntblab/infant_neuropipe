#!/bin/bash
#
# Create a regressor for a given EV timing file.
# 
# This takes an fsf file with the specified convolution parameters and
# timing information. What is relevant is the TR duration and the number
# of TRs. It will then create a temporary folder within which the EV
# will be stored in custom_timing folder. feat_model is then run which
# will produce a design.mat which contains the regressor. This is then
# stripped of irrelevant information, leaving only the regressor
# timecourse.
# 
# It is possible to take advantage of some of the quirks of this system
# to be used more generally. For instance, you can over estimate the
# number of TRs and then scale it back in the output file

# What are the inputs
Input_fsf=$1
Input_EV=$2
Output_file=$3

# Make the folder
id=$RANDOM
mkdir -p temp_${id}.feat/custom_timing_files; fslFixText $Input_EV temp_${id}.feat/custom_timing_files/ev1.txt

# Move the file
cp $Input_fsf temp_${id}.feat/; cd temp_${id}.feat

# Remove the extension
fsf_base=`echo ${Input_fsf} | rev | cut -c 5- | rev`
LastIdx=`echo "$fsf_base" | awk -F"/" '{print length($0)-length($NF)}'`
fsf_base=${fsf_base:LastIdx}

# Run the feat model
feat_model $fsf_base

# Convert the design.mat file that was created into a regressor. Only the first column is relevant.
design_mat=`echo ${Input_fsf##*/}`; design_mat=`echo ${design_mat%.fsf}.mat`;
cat $design_mat | grep -E "^[^/]" > ../temp_${id}.mat  # Ignore all lines starting with '/'
#awk 'NF{NF-=1};1' ../$Output_file > ../$Output_file # Store file

# Return to original directory and delete this folder
cd ..;

# Copy the file back
mv temp_${id}.mat $Output_file

# Remove file
rm -rf temp_${id}.feat/
