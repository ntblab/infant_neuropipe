#!/bin/bash
# Run several steps of freesurfer on a hemisphere of iBEAT data in order to make it usable as part of the FS pipeline
# This creates the white and pial surface, then creates the curvature file, then inflates and then makes a sphere
#
# Can supply a second argument as the fs_name if not 'iBEAT'
#
# This calls the wb_thickness_sulc script at the end to align the sulc to the registered sphere
#
# To interpret the outputs, use srun --x11 --pty iBEAT_QC.sh analysis/freesurfer/iBEAT/
#
# Example command: 
# sbatch ./scripts/iBEAT/iBEAT_inflate_sphere.sh lh
#
#SBATCH --partition short
#SBATCH --nodes 1
#SBATCH --time 6:00:00
#SBATCH --mem-per-cpu 20G
#SBATCH --job-name iBEAT
#SBATCH --output logs/iBEAT-%J.txt

if [ "$#" -eq 0 ]; then
echo No arguments supplied, exiting.
exit
fi

# What hemisphere are you analyzing
hemi=$1

source globals.sh

SUBJECTS_DIR=$(pwd)/analysis/freesurfer/
export SUBJECTS_DIR

if [ "$#" -eq 1 ]; then
FS_NAME=iBEAT
else
FS_NAME=$2
fi

FS_DIR=${SUBJECTS_DIR}/$FS_NAME/

echo ''; echo ''; echo First make the inner surface and duplicate it for necessary uses
mris_convert ${FS_DIR}/scratch/${hemi}.Inner.surf.gii ${FS_DIR}/surf/${hemi}.orig
cp ${FS_DIR}/surf/${hemi}.orig ${FS_DIR}/surf/${hemi}.smoothwm
cp ${FS_DIR}/surf/${hemi}.orig ${FS_DIR}/surf/${hemi}.white

echo ''; echo ''; echo Make the pial surface too
mris_convert  ${FS_DIR}/scratch/${hemi}.Outer.surf.gii ${FS_DIR}/surf/${hemi}.pial

# echo ''; echo ''; echo Make the inflated version keep it gifti
# for layer in Inner Outer; do 
# mris_inflate  ${FS_DIR}/scratch/${hemi}.${layer}.surf.gii  ${FS_DIR}/scratch/${hemi}.inflate.${layer}.surf.gii
# done
# 
# echo ''; echo ''; echo Convert the inflated version to the appropriate format and make the sulc file
# mris_convert  ${FS_DIR}/scratch/${hemi}.inflate.Inner.surf.gii ${FS_DIR}/surf/${hemi}.inflated

echo ''; echo ''; echo Create the convexity file necessary for loading into tksurfer, although will need to be loaded in as an overlay
#mris_make_surfaces -whiteonly iBEAT $hemi  # Don't use this because this makes its own files
SurfaceMetrics -conv -i_fs ${FS_DIR}/surf/${hemi}.orig -prefix ${FS_DIR}/scratch/${hemi} # Create a 1d file of the convexity from the original surface
ConvertDset -input ${FS_DIR}/scratch/${hemi}.conv.niml.dset -o ${FS_DIR}/surf/${hemi}.conv.gii # Convert it to a gifti

# echo ''; echo ''; echo Smooth the white file that is created from mris_make_surfaces, making it read for creating the final inflated version
# mris_smooth -n 3 -nw ${FS_DIR}/surf/${hemi}.white ${FS_DIR}/surf/${hemi}.smoothwm

echo ''; echo ''; echo Inflate the brain
mris_inflate ${FS_DIR}/surf/${hemi}.smoothwm ${FS_DIR}/surf/${hemi}.inflated

echo ''; echo ''; echo Calculate curvature stats
#mris_curvature -thresh .999 -n -a 5 -w -distances 10 10 ${SUBJ}/surf/${hemi}.inflated
#mris_curvature_stats -m --writeCurvatureFiles -G -o ${SUBJ}/stats/${hemi}.curv.stats -F smoothwm ${SUBJ} ${hemi} curv sulc
#mris_curvature -w ${SUBJ}/surf/${hemi}.pial
#mris_curvature -w ${SUBJ}/surf/${hemi}.white

mris_curvature -thresh .999 -n -a 5 -w -distances 10 10 ${FS_DIR}/surf//${hemi}.inflated
#mris_curvature_stats -m --writeCurvatureFiles -G -o ${FS_DIR}/stats/${hemi}.curv.stats -F smoothwm iBEAT ${hemi} curv sulc

echo ''; echo ''; echo Make spheres of the data. Can start making cuts once this begins
mris_sphere ${FS_DIR}/surf/${hemi}.inflated ${FS_DIR}/surf/${hemi}.sphere

echo ''; echo ''; echo Run the registration of the sphere to standard
freesurfer_path=`which freesurfer`
reg_file=${freesurfer_path%bin*}/average/${hemi}.average.curvature.filled.buckner40.tif
#mris_register -curv ${FS_DIR}/surf/${hemi}.sphere ${reg_file} ${FS_DIR}/surf/${hemi}.sphere.reg
mris_register ${FS_DIR}/surf/${hemi}.sphere ${reg_file} ${FS_DIR}/surf/${hemi}.sphere.reg

echo ''; echo ''; echo Quantify how much the white matter surface has to move in order to fit on the sphere.
mris_jacobian ${FS_DIR}/surf/${hemi}.white ${FS_DIR}/surf/${hemi}.sphere.reg ${FS_DIR}/surf/${hemi}.jacobian_white
# To show the Jacobian surface
# freeview -f ${FS_DIR}/surf/lh.white:overlay=${FS_DIR}/surf/lh.jacobian_white:overlay_threshold=0,2 ${FS_DIR}/surf/rh.white:overlay=${FS_DIR}/surf/rh.jacobian_white:overlay_threshold=0,2

echo ''; echo ''; echo Compute curvature statistics
mrisp_paint -a 5 $FREESURFER_HOME/average/${hemi}.average.curvature.filled.buckner40.tif#6 ${FS_DIR}/surf/${hemi}.sphere.reg ${FS_DIR}/surf/${hemi}.avg_curv

echo ''; echo ''; echo Overlay the desikan atlas
mris_ca_label -aseg ${FS_DIR}/mri/aseg.mgz ${FS_NAME} ${hemi} ${hemi}.sphere.reg $FREESURFER_HOME/average/${hemi}.curvature.buckner40.filled.desikan_killiany.2010-03-25.gcs ${FS_DIR}/label/${hemi}.aparc.annot
# To show the desikan atlas
# freeview -f analysis/freesurfer/iBEAT/surf/rh.pial:annot=analysis/freesurfer/iBEAT/label/rh.aparc.annot analysis/freesurfer/iBEAT/surf/lh.pial:annot=analysis/freesurfer/iBEAT/label/lh.aparc.annot

echo ''; echo ''; echo Use workbench to make a midthickness and align the sulc to that
sbatch ./scripts/iBEAT/wb_thickness_sulc.sh ${FS_DIR} ${hemi}

echo ''; echo ''; echo Finished

