#!/bin/bash
#
# Convert the sphere and other files into 32k standard space (based on the standard mesh directory)
# This is necessary to make a sulc file that you can then view
# Once this is setup you can then resample functionals to the mid thickness file and create cifti files
#
# for hemi in lh rh; do wb_command -volume-to-surface-mapping ${func}.nii.gz ${fs_dir}/surf/${hemi}.midthickness.32k_fs_LR.surf.gii  ${fs_dir}/surf/${hemi}.${func}.32k_fs_LR.func.gii -trilinear; done
# wb_command -cifti-create-dense-scalar ${fs_dir}/surf/${func}.32k_fs_LR.dscalar.nii -left-metric ${fs_dir}/surf/lh.${func}.32k_fs_LR.func.gii -right-metric ${fs_dir}/surf/rh.${func}.32k_fs_LR.func.gii
#
# This uses ConnectomeWorkbench as a module, change the environment if this is inappropriate 
# This assumes you have downloaded the standard mesh atlases in the $ATLAS_DIR
#
#SBATCH --output=./logs/wb_midthickness_sulc-%j.out
#SBATCH -p short
#SBATCH -t 20
#SBATCH --mem 2000

source globals.sh

# Loads work bench as a special module to avoid interference
module load ConnectomeWorkbench

# Check how many arguments are supplied
if [ "$#" -eq 0 ]; then
echo No arguments supplied, exiting.
exit
fi

# Load the freesurfer directory
fs_dir=$1

# What hemisphere are you using
hemi=$2

echo Using $fs_dir
echo Using $hemi hemisphere

# What hemisphere is this
if [ $hemi == lh ]
then
hemi_capital=L
else
hemi_capital=R
fi

# Specify the mesh and copy it so that it is easier to call
mesh_dir=${ATLAS_DIR}/standard_mesh_atlases
mesh=${mesh_dir}/resample_fsaverage/fs_LR-deformed_to-fsaverage.${hemi_capital}.sphere.32k_fs_LR.surf.gii
mesh_out=${fs_dir}/surf/${hemi}.sphere.32k_fs_LR.surf.gii
cp $mesh $mesh_out

# Resample the data into standard space
wb_shortcuts -freesurfer-resample-prep \
    ${fs_dir}/surf/${hemi}.white \
    ${fs_dir}/surf/${hemi}.pial \
    ${fs_dir}/surf/${hemi}.sphere.reg \
    ${mesh_out} \
    ${fs_dir}/surf/${hemi}.midthickness.surf.gii \
    ${fs_dir}/surf/${hemi}.midthickness.32k_fs_LR.surf.gii \
    ${fs_dir}/surf/${hemi}.sphere.reg.surf.gii


# Get the scalar metric
for surface_info in sulc;
do

mris_convert -f ${fs_dir}/surf/${hemi}.${surface_info} ${fs_dir}/surf/${hemi}.white ${fs_dir}/surf/${hemi}.${surface_info}.func.gii # Convert to gifti    
wb_command -metric-resample \
    ${fs_dir}/surf/${hemi}.${surface_info}.func.gii \
    ${fs_dir}/surf/${hemi}.sphere.reg.surf.gii \
    ${mesh} \
    ADAP_BARY_AREA \
    ${fs_dir}/surf/${hemi}.${surface_info}.32k_fs_LR.func.gii \
    -area-surfs \
    ${fs_dir}/surf/${hemi}.midthickness.surf.gii \
    ${fs_dir}/surf/${hemi}.midthickness.32k_fs_LR.surf.gii
done


echo Finished

