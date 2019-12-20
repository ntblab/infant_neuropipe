#!/bin/bash -e
#Author: Naz Al-Aidroos
#Edited by: Alexa Tompary
# This script re-scaffolds all subjects in your project directory

source globals.sh

for subj in $ALL_SUBJECTS; do
	bash $PROJ_DIR/scaffold $subj
done