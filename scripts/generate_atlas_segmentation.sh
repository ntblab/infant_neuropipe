#!/bin/bash
#SBATCH --partition short
#SBATCH --nodes 1
#SBATCH --time 00:30:00
#SBATCH --mem-per-cpu 1G
#SBATCH --job-name 00_classifier
#SBATCH --output /gpfs/milgram/project/turk-browne/infant_anatomical/freesurfer/logs/00_create_atlas_classifier.gcs_and_template.tif-log-%J.txt

#-----------------------------------------------------------#
# Use annotation file to build a .gcs classifier file, which#
# is used for the labelling/parcellation of individual brain#
# Also, use the sphere file to build a template.tif file	#
# 															#
# Tobias W. Meissner 										#
# Visiting graduate student from Ruhr-Uni Bochum, Germany	#
# Spring 2018												#
# tobias.meissner@rub.de									#
#															#
#-----------------------------------------------------------#

# define variables
WORKING_DIR=/gpfs/milgram/project/turk-browne/infant_anatomical
ATLAS_DIR=$WORKING_DIR/freesurfer/UNC_4D_Infant_Cortical_Atlas

for age_var in 01 03 06 09 12 18 24 36 48 60 72
do
	printf "\n##########################################\n"
	printf "%s" $age_var
	printf "\n# Creating folder structure...\n"

	# create label directory
	rm -r $ATLAS_DIR/$age_var/label
	mkdir $ATLAS_DIR/$age_var/label

	# create surf directory
	rm -r $ATLAS_DIR/$age_var/surf
	mkdir $ATLAS_DIR/$age_var/surf

	for hemi in "lh" "rh"
	do
		printf "##########################################\n"
		printf "%s" $hemi
		printf "\n# Copying files...\n"
		# copy atlas anntoation file
		cp $ATLAS_DIR/$age_var/$hemi.Annot-FreeSurfer $ATLAS_DIR/$age_var/label/$hemi.UNC_4D_Infant_Cortical_Atlas.annot	
		# copy surface
		cp $ATLAS_DIR/$age_var/$hemi.smoothwm $ATLAS_DIR/$age_var/surf/$hemi.smoothwm
		# copy sphere
		cp $ATLAS_DIR/$age_var/$hemi.sphere $ATLAS_DIR/$age_var/surf/$hemi.sphere
		# copy inflated.H
		cp $ATLAS_DIR/$age_var/$hemi.inflated.H $ATLAS_DIR/$age_var/surf/$hemi.inflated.H
		# copy sulc
		cp $ATLAS_DIR/$age_var/$hemi.sulc $ATLAS_DIR/$age_var/surf/$hemi.sulc

		# train classifier on annotation file, create gcs file
		printf "##########################################\n"
		printf "# Training classifier, create gcs file...\n"
		mris_ca_train -t $ATLAS_DIR/aparc.annot.ctab -sdir $ATLAS_DIR $hemi sphere UNC_4D_Infant_Cortical_Atlas $age_var $ATLAS_DIR/$age_var/$hemi.parc_classifier.gcs
		printf "\n"

		# Use sphere to create template.tif
		printf "##########################################\n"
		printf "# Create template.tif file...\n"
		mris_make_template -sdir $ATLAS_DIR $hemi sphere $age_var $ATLAS_DIR/$age_var/$hemi.template.tif

		cp $ATLAS_DIR/$age_var/$hemi.template.tif $ATLAS_DIR/$age_var/surf/$hemi.template.tif
		printf "\n"
	done
done
