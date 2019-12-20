#!/bin/bash
#SBATCH --partition short
#SBATCH --nodes 1
#SBATCH --time 6:00:00
#SBATCH --mem-per-cpu 4G
#SBATCH --job-name screenshots
#SBATCH --output /gpfs/milgram/project/turk-browne/infant_anatomical/freesurfer/logs/02_freeview_screenshots-log-%J.txt

#-----------------------------------------------------------#
#															#
# Tobias W. Meissner 										#
# Visiting graduate student from Ruhr-Uni Bochum, Germany	#
# Spring 2018												#
# tobias.meissner@rub.de									#
#															#
# saves .png images of slices (screenshots) of freesurfer	#
# results, i.e. T1 image with pial and white matter surface	#
# and segmentation											#
#															#
# creates .txt file for each subject in $SUBJ_DIR and then 	#
# executes a freesurfer command that reads in the .txt files#
# freeview -cmd $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt		#
#															#
# needs an interactive session on milgram, e.g.				#
# srun --pty --x11 -t 6:00:00 -p short --mem=4G bash		#
#															#
# -v: load in volume										#
# -f: load in surface										#
# -viewport: e.g. coronal 									#
# -slice: X Y Z coordinates of slice						#
# -ss: <output filename> <zoom factor>						#
#															#
#-----------------------------------------------------------#

# An example for a screenshot_cmd.txt file created and read in by this script is:

# freeview 
# -v /gpfs/milgram/project/turk-browne/infant_anatomical/freesurfer/subjects_infantAtlas/011917_dev02_petra01_brain/mri/T1.mgz -f /gpfs/milgram/project/turk-browne/infant_anatomical/freesurfer/subjects_infantAtlas/011917_dev02_petra01_brain/surf/lh.white:edgethickness=2 /gpfs/milgram/project/turk-browne/infant_anatomical/freesurfer/subjects_infantAtlas/011917_dev02_petra01_brain/surf/rh.white:edgethickness=2 /gpfs/milgram/project/turk-browne/infant_anatomical/freesurfer/subjects_infantAtlas/011917_dev02_petra01_brain/surf/lh.pial:edgecolor=red:edgethickness=2 /gpfs/milgram/project/turk-browne/infant_anatomical/freesurfer/subjects_infantAtlas/011917_dev02_petra01_brain/surf/rh.pial:edgecolor=red:edgethickness=2
# -viewport coronal -slice 100 100 126 -ss /gpfs/milgram/project/turk-browne/infant_anatomical/freesurfer/screenshots/011917_dev02_petra01_brain_inf_cor_T1_100_100_126 2
# -viewport coronal -slice 100 100 106 -ss /gpfs/milgram/project/turk-browne/infant_anatomical/freesurfer/screenshots/011917_dev02_petra01_brain_inf_cor_T1_100_100_106 2
# -viewport coronal -slice 100 100 86 -ss /gpfs/milgram/project/turk-browne/infant_anatomical/freesurfer/screenshots/011917_dev02_petra01_brain_inf_cor_T1_100_100_86 2
# -viewport coronal -slice 100 100 66 -ss /gpfs/milgram/project/turk-browne/infant_anatomical/freesurfer/screenshots/011917_dev02_petra01_brain_inf_cor_T1_100_100_66 2
# -v /gpfs/milgram/project/turk-browne/infant_anatomical/freesurfer/subjects_infantAtlas/011917_dev02_petra01_brain/mri/aseg.mgz:colormap=lut:opacity=0.2
# -viewport coronal -slice 100 100 126 -ss /gpfs/milgram/project/turk-browne/infant_anatomical/freesurfer/screenshots/011917_dev02_petra01_brain_inf_cor_T1_100_100_126_aseg 2
# -viewport coronal -slice 100 100 106 -ss /gpfs/milgram/project/turk-browne/infant_anatomical/freesurfer/screenshots/011917_dev02_petra01_brain_inf_cor_T1_100_100_106_aseg 2
# -viewport coronal -slice 100 100 86 -ss /gpfs/milgram/project/turk-browne/infant_anatomical/freesurfer/screenshots/011917_dev02_petra01_brain_inf_cor_T1_100_100_86_aseg 2
# -viewport coronal -slice 100 100 66 -ss /gpfs/milgram/project/turk-browne/infant_anatomical/freesurfer/screenshots/011917_dev02_petra01_brain_inf_cor_T1_100_100_66_aseg 2
# freeview -quit

# define variables
WORKING_DIR=/gpfs/milgram/project/turk-browne/infant_anatomical/freesurfer
SUBJ_DIR=$WORKING_DIR/subjects_infantAtlas

for BRAIN in $SUBJ_DIR/*
do
	if [[ -d $BRAIN && ! -L $BRAIN ]] && [[ $BRAIN =~ ^$SUBJ_DIR/[0-9]*_dev02_.*_brain$ ]] # directory, and no symbolic link, and matching the pattern
	then
		BRAIN=${BRAIN%*/}
		BRAIN=${BRAIN##*/}

		if [[ -f $SUBJ_DIR/$BRAIN/mri/T1.mgz ]] && [[ -f $SUBJ_DIR/$BRAIN/mri/aseg.mgz ]] && [[ -f $SUBJ_DIR/$BRAIN/surf/lh.white ]] && [[ -f $SUBJ_DIR/$BRAIN/surf/rh.white ]] && [[ -f $SUBJ_DIR/$BRAIN/surf/lh.pial ]] && [[ -f $SUBJ_DIR/$BRAIN/surf/rh.pial ]] # do all the files exist that I need?
		then
			printf "%s" "freeview " > $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt

			# load T1
			printf "\n-v " >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" $SUBJ_DIR/$BRAIN/mri/T1.mgz >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt

			# load surfaces
			printf "%s" " -f " >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s"$SUBJ_DIR/$BRAIN/surf/lh.white:edgethickness=2 >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" " " >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" $SUBJ_DIR/$BRAIN/surf/rh.white:edgethickness=2 >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" " " >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" $SUBJ_DIR/$BRAIN/surf/lh.pial:edgecolor=red:edgethickness=2 >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" " " >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" $SUBJ_DIR/$BRAIN/surf/rh.pial:edgecolor=red:edgethickness=2 >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt

			# screenshots without segmentation
			printf "\n-viewport coronal -slice 100 100 126 -ss " >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" $WORKING_DIR/screenshots/$BRAIN >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" "_inf_cor_T1_100_100_126 2" >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt

			printf "\n-viewport coronal -slice 100 100 106 -ss " >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" $WORKING_DIR/screenshots/$BRAIN >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" "_inf_cor_T1_100_100_106 2" >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt

			printf "\n-viewport coronal -slice 100 100 86 -ss " >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" $WORKING_DIR/screenshots/$BRAIN >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" "_inf_cor_T1_100_100_86 2" >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt

			printf "\n-viewport coronal -slice 100 100 66 -ss " >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" $WORKING_DIR/screenshots/$BRAIN >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" "_inf_cor_T1_100_100_66 2" >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt

			# load segmentation
			printf "\n-v " >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" $SUBJ_DIR/$BRAIN/mri/aseg.mgz:colormap=lut:opacity=0.2 >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt

			# screenshots with segmentation
			printf "\n-viewport coronal -slice 100 100 126 -ss " >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" $WORKING_DIR/screenshots/$BRAIN >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" "_inf_cor_T1_100_100_126_aseg 2" >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt

			printf "\n-viewport coronal -slice 100 100 106 -ss " >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" $WORKING_DIR/screenshots/$BRAIN >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" "_inf_cor_T1_100_100_106_aseg 2" >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt

			printf "\n-viewport coronal -slice 100 100 86 -ss " >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" $WORKING_DIR/screenshots/$BRAIN >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" "_inf_cor_T1_100_100_86_aseg 2" >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt

			printf "\n-viewport coronal -slice 100 100 66 -ss " >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" $WORKING_DIR/screenshots/$BRAIN >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt
			printf "%s" "_inf_cor_T1_100_100_66_aseg 2" >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt

			# close freeview
			printf "\nfreeview -quit" >> $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt

			# execute all the commands that were written to the file
			freeview -cmd $SUBJECTS_DIR/$BRAIN/screenshot_cmd.txt

			printf "%s" $BRAIN
			printf " saved as screenshot\n"
		else
			printf "%s" $BRAIN
			printf " NOT saved as screenshot, because at least one volume or surface file was missing\n"
		fi
	fi
done
