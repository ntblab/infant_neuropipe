# Subject directory

This directory was automatically created by the program *scaffold* from your infant_neuropipe project directory. it should contain all scripts and data necessary to perform the analysis of a single subject.  

For the most part, filepaths in this directory will be referenced relative to this current path.  

## Directory structure

Initially, your subject directory will look like this:  
  |--README.txt  
  |--run-order.txt  
  |--globals.sh  
  |--prep_xnat.sh  
  |--scripts/  
  |--analysis/  
  |--fsf/  
  |--data/  
  |--logs/

## Getting started

Your first step (step 1 of the infant_neuropipe README) is to convert your data into the NIFTI format and store it in the data/nifti/ directory. You likely have your own procedures for doing this. However, there are tools to convert a gzipped tar archive ($SUBJ_DIR/prep_xnat.sh) via the information stored in $SUBJ_DIR/run-order.txt which should be edited to match the sequences run.
