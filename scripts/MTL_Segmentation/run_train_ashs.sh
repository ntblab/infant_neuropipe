#!/bin/bash
# Script for running ASHS training pipeline
#
#SBATCH --output=/output_directory/ashs_train-%j.out
#SBATCH -p psych_day
#SBATCH -t 24:00:00
#SBATCH -N 1 --exclusive # Set it to use a whole node
#SBATCH --mem=0

# We are running this code in parallel on a node; this module provides parallel shell execution; use your own module if parallel processing is desired
module load  parallel/20180822-foss-2018b

# What inputs are necessary
data_manifest_file=$1 # What is the name of the data manifest file that defines all of the volumes to be used
output_directory=$2 # Where do you want to save the ashs model

if [ "$#" -gt 2 ]
then
config_file=$3
fi

# Make directory if it doesn't exist
mkdir -p $output_directory

if [ "$#" -gt 2 ]
then
$ASHS_ROOT/bin/ashs_train.sh \
  -D $data_manifest_file \
  -L label_description_test.txt \
  -w $output_directory \
  -C $config_file \
  -P

else
$ASHS_ROOT/bin/ashs_train.sh \
  -D $data_manifest_file \
  -L label_description_test.txt \
  -w $output_directory \
  -P
fi
