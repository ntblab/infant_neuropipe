#!/bin/bash
#
# Run a feat script with the specified fsf file as an input
#
#SBATCH --output=./logs/feat-%j.out
#SBATCH -p short
#SBATCH -t 360
#SBATCH --mem 20000

source globals.sh

# Export memory
export FSL_MEM=20

# Run feat
feat $1
