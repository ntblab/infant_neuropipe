#!/bin/bash
#SBATCH --partition long
#SBATCH --nodes 1
#SBATCH --time 48:00:00
#SBATCH --mem-per-cpu 8G
#SBATCH --job-name rec_stepw
#SBATCH --output ./logs/recon-all_custom-log-%J.txt

#-----------------------------------------------------------#
# reconstructs cortical surface and labels surface of 		#
# custom atlases/brains using 								#
# 	1) the UNC_4D_Infant_Cortical_Atlas						#
# 	2) the standard freesurfer Atlas (optional)				#
#															#
# Functionality can be extended to a new atlas by using 	#
# scripts/generate_atlas_segmentation.sh. Read for more		#
# documentation												#
#															#
# See these documentations for information on what is 		#
# included in the freesurfer recon-all pipeline: 			#
# https://surfer.nmr.mgh.harvard.edu/fswiki/				#
# 1)ReconAllTableStableV6.0									#
# 2) recon-all												#
#															#
#															#
# If a subject was already run, all its previous data will	#
# be deleted.												#
#															#
# tested with FreeSurfer 6.0.0								#
#															#
# INPUT PARAMETERS:											#
# $1 = Full path of anatomical that is will be used			#
# $2 = Name you want to use for saving data 				#
# (e.g. petra01_brain) that will be put in the freesurfer 	#
# folder			 										#
# $3 = do UNC infant atlas AND standard freesurfer?			#
# 1 = yes, anything else = only UNC infant atlas			#
#															#
# Nifti data quality cannot be super crappy, otherwise,		#
# 1) autorecon2 crashes or 									#
# 2) the script runs without error but the reconstructed 	#
# 	surface is not realistic as sulci and fissures are not 	#
# 	reliably detected (no gyrification)						#
# 3) autorecon2 takes several days (usually attempting to 	#
# 	fix the topology)										#
#															#
# Tobias W. Meissner 										#
# Visiting graduate student from Ruhr-Uni Bochum, Germany	#
# Spring 2018												#
# tobias.meissner@rub.de									#
#															#
#-----------------------------------------------------------#

# Set up the environment
source globals.sh
. /apps/hpc/Apps/FREESURFER/6.0.0/FreeSurferEnv.sh 

# define directory variables
UNC_DIR=$ATLAS_DIR/UNC_4D_Infant_Cortical_Atlas/  # where is the infant atlas?
FREESURFER_DIR=$SUBJECT_DIR/analysis/freesurfer/  # Where is the freesurfer dir

# Export the new dir
SUBJECTS_DIR=analysis/freesurfer/
export SUBJECTS_DIR

input_name=$1  # What is the input folder name
output_name=$2  # What is the output folder name
run_adult_pipeline=$3  # Are you running the adult pipeline (basically gives you more segmentation but isn't possible with the UNC infant atlas

output_dir=$FREESURFER_DIR/$output_name/
output_dir_adult=$FREESURFER_DIR/${output_name}_adult/

printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Getting age information"

# Read in the text file for the participant information (which has the age)
Participant_Data=`cat $PROJ_DIR/scripts/Participant_Data.txt`

# Pull out the appropriate atlas folder of the participant
ATLAS=`./scripts/age_to_standard.sh UNC`

# Return the standard brain
printf "\nUNC_4D_Infant_Cortical_Atlas age template used for registration and parcellation is: "
printf "%s" $ATLAS
printf "...\n\n"

# delete subject directory if it exists, i.e. if the subject was run before
if [ -d $output_dir ] 
then
	rm -r $output_dir
fi

# autorecon1: recon-all steps 2-4
printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Doing recon-all autorecon1...\n\n"
recon-all -i $input_name -autorecon1 -cw256 -subjid $output_name

# autorecon2: recon-all steps 6-23
printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Doing recon-all autorecon2...\n\n"
recon-all -autorecon2 -subjid $output_name

# due to some inconsistency in the freesurfer versions,
# ?h.white is not created, but ?h.white.preaparc. This is only a naming issue.
if [ ! -f $output_dir/surf/lh.white ]
then
	cp $output_dir/surf/lh.white.preaparc $output_dir/surf/lh.white
fi
if [ ! -f $output_dir/surf/rh.white ]
then
	cp $output_dir/surf/rh.white.preaparc $output_dir/surf/rh.white
fi

if [ $run_adult_pipeline -eq 1 ]
then
	# Copy complete subject folder to a new location. 
	# So far, all steps follow the standard routine. 
	# On the copied folder, recon-all autorecon3 is run after the infant pipeline is 
	# finished to compare the impact of using the UNC atlas and the standard atlas.
	# Infant pipeline is run first, because it should be less likely to crash or take
	# several days due to many reconstruction errors that have to be corrected.
	printf "#\n#\n#\n#\n#\n#####################################################\n"
	printf "Autorecon 3 with freesurfers standard adult atlas will be done after the infant pipeline is completed.\n Copying complete freesurfer subject folder with results from autorecon1 and autorecon2 into separate directory for autorecon3..."
	# delete subject directory if it exists, i.e. if the subject was run before
	if [ -d $output_dir_adult ] 
	then
		rm -r $output_dir_adult
	fi
	
	# Copy up to this point
	cp -r $output_dir $output_dir_adult
	
	# the subject "$FREESURFER_HOME/subjects/V1_average" has to be in $SUBJECTS_DIR for V1 mapping
	if [ ! -d $output_dir_adult/V1_average ]
	then
		cp -r $FREESURFER_HOME/subjects/V1_average $output_dir_adult/V1_average
	fi
	
	printf "done!\n"
	printf "Continuing with infant pipeline...\n\n"

else
	printf "#\n#\n#\n#\n#\n#####################################################\n"
	printf "Only the infant pipeline will run. No adult atlas will be used for comparison...\n\n"
fi

# recon-all step 24: start of autorecon3
printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Doing recon-all -sphere...\n\n"
recon-all -sphere -subjid $output_name

# recon-all step 25 & 25 - left & right hemisphere: Register the subject's individual surface to the atlas' surface
printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Doing mris_register...\n\n"
mris_register -1 $output_dir/surf/lh.sphere $ATLAS/lh.sphere $output_dir/surf/lh.sphere.reg
mris_register -1 $output_dir/surf/rh.sphere $ATLAS/rh.sphere $output_dir/surf/rh.sphere.reg

# recon-all step jacobian. Computes how much the white surface was distorted 
# in order to register to the spherical atlas during the -surfreg step. 
# Creates ?h.jacobian_white (a curv formatted file). 
printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Doing recon-all -jacobian_white...\n\n"
recon-all -jacobian_white -subjid $output_name

# recon-all step 27 
# UNC Infant Atlas does not provide a template file. To run this step, 
# a template file must have been created for the atlas previously.
# Cannot use recon-all -avgcurv, as it would not use the correct template (.tif file)
printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Doing mrisp_paint ...\n\n"
mrisp_paint $ATLAS/template.tif $output_dir/surf/lh.sphere.reg $output_dir/surf/lh.avg_curv
mrisp_paint $ATLAS/template.tif $output_dir/surf/rh.sphere.reg $output_dir/surf/rh.avg_curv

# The following steps can only be done after the .gcs classifier file is constructed 
# by training a classifier on one or more .annot files using mris_ca_train. 
# recon-all step 28: Cortical Parcellation, create Annotation file
printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Doing mris_ca_label ...\n\n"
# copy the atlas colortable file into the participants label folder, where later commands will look for it
cp $UNC_DIR/aparc.annot.ctab $output_dir/label/aparc.annot.ctab
mris_ca_label $output_name lh sphere.reg $ATLAS/lh.parc_classifier.gcs $output_dir/label/lh.aparc.annot
mris_ca_label $output_name rh sphere.reg $ATLAS/rh.parc_classifier.gcs $output_dir/label/rh.aparc.annot

printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Doing recon-all -pial...\n\n"
recon-all -pial -subjid $output_name

printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Doing recon-all -cortribbon...\n\n"
recon-all -cortribbon -subjid $output_name

# recon-all step XX: Parcellation Statistics, parcstats - left hemisphere
printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Calculate cortical parcellation statistics using mris_anatomical_stats...\n\n"
mris_anatomical_stats -a $output_dir/label/lh.aparc.annot -b -f $output_dir/stats/lh.aparc.stats $output_name lh pial
mris_anatomical_stats -a $output_dir/label/rh.aparc.annot -b -f $output_dir/stats/rh.aparc.stats $output_name rh pial

# Computes the vertex-by-vertex percent contrast between white and gray matter.
# pct = (100*(W-G))/(0.5*(W+G))
# WM is sampled 1mm below the white surface. Changeable: --wm-proj-abs. 
# GM is sampled 30% the thickness into the cortex. Changeable: --gm-proj-frac. 
printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Doing recon-all -pctsurfcon...\n\n"
recon-all -pctsurfcon -subjid $output_name

# necessary for mri_aparc2aseg
printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Doing recon-all -hyporelabel...\n\n"
recon-all -hyporelabel -subjid $output_name

# Maps the cortical labels from the automatic cortical parcellation (aparc) 
# to the automatic segmentation volume (aseg).
# The result can be used as the aseg would 
printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Create aparc+aseg.mgz using mri_aparc2aseg...\n\n"
mri_aparc2aseg --s $output_name --volmask --aseg aseg.presurf.hypos --relabel $output_dir/mri/norm.mgz $output_dir/mri/transforms/talairach.m3z $FREESURFER_HOME/average/RB_all_2016-05-10.vc700.gca $output_dir/mri/aseg.auto_noCCseg.label_intensities.txt

# Create aseg.mgz
printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Create aseg.mgz with -apas2aseg...\n\n"
recon-all -apas2aseg -subjid $output_name

# Calculate non-cortex statistics (for aseg)
printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Calculate aseg statistics using recon-all -segstats...\n\n"
recon-all -segstats -subjid $output_name

# Parcellate white matter and calculate statistics
printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Parcellate white matter and calculate statistics using recon-all -wmparc...\n\n"
recon-all -wmparc -subjid $output_name

# Map brodmann area map labels
# http://ftp.nmr.mgh.harvard.edu/fswiki/BrodmannAreaMaps
printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Map brodmann area map labels using recon-all -balabels...\n\n"
recon-all -balabels -subjid $output_name

# Map v1 labels
printf "#\n#\n#\n#\n#\n#####################################################\n"
printf "Map v1 labels using recon-all -label_v1...\n\n"
# the subject "$FREESURFER_HOME/subjects/V1_average" has to be in $SUBJECTS_DIR
# https://surfer.nmr.mgh.harvard.edu/fswiki/V1
if [ ! -d $FREESURFER_DIR/V1_average ] 
then
	cp -r $FREESURFER_HOME/subjects/V1_average $FREESURFER_DIR/V1_average
fi
recon-all -label_v1 -subjid $output_name 

# run the hippocampal subfields segmentation: https://surfer.nmr.mgh.harvard.edu/fswiki/HippocampalSubfields
#printf "#\n#\n#\n#\n#\n#####################################################\n"
#printf "Run the hippocampal subfields segmentation...\n\n"
#recon-all -subjid $1 -hippocampal-subfields-T1 # use "-hippocampal-subfields-T1T2 <path to T2>" if T2 is available

if [ $run_adult_pipeline -eq 1 ]
then
	# On the copied folder, recon-all autorecon3 is run after the infant pipeline has 
	# finished to compare the impact of using the UNC atlas and the standard atlas.
	# Infant pipeline is run first, because it should be less likely to crash or take
	# several days due to many reconstruction errors that have to be corrected.
	printf "#\n#\n#\n#\n#\n#####################################################\n"
	printf "Do autorecon 3 with freesurfers standard adult atlas for comparison...\n\n"
	recon-all -autorecon3 -subjid $output_name -sd $output_dir
	
	# run the hippocampal subfields segmentation: https://surfer.nmr.mgh.harvard.edu/fswiki/HippocampalSubfields
	#recon-all -subjid $1 -hippocampal-subfields-T1 # use "-hippocampal-subfields-T1T2 <path to T2>" if T2 is available
fi
