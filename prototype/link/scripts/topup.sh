#!/bin/bash
#
# Prepare fieldmap
#
# For a recipe, see:
# https://sites.google.com/site/theunofficialpnimriwiki/home/fmri/topup
# or this:
# https://lcni.uoregon.edu/kb-articles/kb-0003
#
#SBATCH --output=topup-%j.out
#SBATCH -p short
#SBATCH -t 300
#SBATCH --mem 10000

source globals.sh

# Create a folder to put all the intermediate top-up stuff in.
TOPUP_DIR=$SUBJECT_DIR/$NIFTI_DIR/topup
if [ ! -d "$TOPUP_DIR" ]; then
  mkdir $TOPUP_DIR
fi

# Concatenate the SE images:
SE_AP_FILE=$SUBJECT_DIR/$NIFTI_DIR/${SUBJ}_SP_AP.nii.gz
SE_PA_FILE=$SUBJECT_DIR/$NIFTI_DIR/${SUBJ}_SP_PA.nii.gz
SE_CONCAT_FILE=$TOPUP_DIR/all_SE.nii.gz
fslmerge -t $SE_CONCAT_FILE $SE_AP_FILE $SE_PA_FILE

# Create an acqparams.txt file. First three columns are PE direction, fourth column is total readout time.
ACQPARAMS_FILE=$TOPUP_DIR/acqparams.txt
cat > $ACQPARAMS_FILE << EOF
0 -1 0 0.0978
0 -1 0 0.0978
0 -1 0 0.0978
0 1 0 0.0978
0 1 0 0.0978
0 1 0 0.0978
EOF

# Run topup (takes about 40 mins, so either qrsh or submit to cluster):
topup --imain=$SE_CONCAT_FILE --datain=$ACQPARAMS_FILE --config=b02b0.cnf --out=$TOPUP_DIR/topup_output --iout=$TOPUP_DIR/topup_iout --fout=$TOPUP_DIR/topup_fout --logout=$TOPUP_DIR/topup_logout

# topup_iout are the unwarped SE images; check these to see if unwarping went well. use the average of these images as magnitude image (see below).
# topup_fout is the fieldmap, in Hz.

# Convert fieldmap from Hz to rad/s:
FIELDMAP_RAD_FILE=$SUBJECT_DIR/$NIFTI_DIR/my_fieldmap_rads.nii.gz
fslmaths $TOPUP_DIR/topup_fout -mul 6.28 $FIELDMAP_RAD_FILE

# Create magnitude image and brain-extract it:
FIELDMAP_MAG_FILE=$SUBJECT_DIR/$NIFTI_DIR/my_fieldmap_mag.nii.gz
fslmaths $TOPUP_DIR/topup_iout -Tmean $FIELDMAP_MAG_FILE
FIELDMAP_MAG_BRAIN_FILE=$SUBJECT_DIR/$NIFTI_DIR/my_fieldmap_mag_brain.nii.gz
bet2 $FIELDMAP_MAG_FILE $FIELDMAP_MAG_BRAIN_FILE -f 0.6
# erode
fslmaths $FIELDMAP_MAG_BRAIN_FILE -ero $FIELDMAP_MAG_BRAIN_FILE

# These fieldmaps are used by Feat.
