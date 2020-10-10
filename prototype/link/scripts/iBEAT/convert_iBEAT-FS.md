This document describes the steps to take iBEAT files and convert them first to freesurfer-style surfaces that allow for surface reconstruction.. 

These steps are designed to be run on the cluster from the subjects directory. Make sure these files are in analysis/freesurfer/iBEAT/raw/ (should be supplied by iBEAT, albeit with different names sometimes):

subject-X-T1w.nii # Original data
subject-X-T1w_aligned.nii.gz # T1 data aligned to surfaces. May just be a duplicate of subject-T1w.nii 
subject-X-iBEAT.lh.OuterSurf.WithThickness.vtk
subject-X-iBEAT.lh.InnerSurf.WithThickness.vtk
subject-X-iBEAT.rh.InnerSurf.WithThickness.vtk
subject-X-iBEAT.rh.OuterSurf.WithThickness.vtk
subject-X-iBEAT.nii.gz # Segmented data where 1 means CSF, 2 means grey matter and 3 means white matter

To run these analyses these scripts need to have an example freesurfer directory that has finished. The surfaces don't need to be usable, but it does need to have all of the files, like brainmask.mgz and aseg.mgz.

You should run these scripts from the participant directory

0. Set some parameters

FREESURFER_NAME=petra01_brain
fs_dir=analysis/freesurfer/iBEAT/


1. Upload the iBEAT data

Upload the iBEAT data to the freesurfer folder: ${fs_dir}/raw/ (will need to make it first).
The files should have the following names:

subject-X-iBEAT.nii.gz
subject-X-T1w.nii.gz
subject-X-iBEAT.?h.InnerSurf.*.vtk
subject-X-iBEAT.?h.OuterSurf.*.vtk


2. Scaffold the FS directory and populate it

You are going to pretend that you ran freesurfer on this data. This needs a number of files, some of which will be correct but many will be inappropriate (e.g., aseg). I think that is okay, but don't trust all the files from this direcory.

This step takes data in the raw directory and fixes it. This means changing their names to be reasonable and also adding header information for the vtk files

./scripts/iBEAT/scaffold_iBEAT.sh ${fs_dir}/raw/ analysis/freesurfer/${FREESURFER_NAME}/


3. Check alignment

You want to load these files into the wb_view to check that the surfaces are aligned consistently. Open wb_view and load in the 4 surface files, the seg file and the original data uploaded.
module load ConnectomeWorkbench
wb_view ${fs_dir}/raw/${SUBJ}-T1w.nii ${fs_dir}/scratch/*h.Inner.surf.gii ${fs_dir}/scratch/*h.Outer.surf.gii

These should all be aligned and overlaid. If these are aligned then do the following:
cp ${fs_dir}/raw/${SUBJ}-T1w.nii ${fs_dir}/raw/${SUBJ}-T1w_aligned.nii
gzip ${fs_dir}/raw/${SUBJ}-T1w_aligned.nii

If these are misaligned it is usually because the dimensionality is flipped. You can use fslswapdim to fix it and flirt. 

For instance a common error will be that they are left/right flipped which can be fixed by doing:
fslswapdim $input x -y z $output

If you did do realignment, make sure to document the process and then store the resulting aligned volume as:
${SUBJ}-T1w_aligned.nii.gz


4. With the directory created, now make inflations and spheres on each hemisphere separately.
This script takes 60-90min to run so don't wait for it 

sbatch scripts/iBEAT/iBEAT_inflate_sphere.sh lh
sbatch scripts/iBEAT/iBEAT_inflate_sphere.sh rh

With the resulting outputs, you can now align any functional data to the anatomical space and view the functional data on the surface.

You can make surface files using something like:
wb_command -volume-to-surface-mapping func2highres.nii.gz ${fs_dir}/surf/lh.Inner.surf.gii  lh.func2highres.func.gii -trilinear 
OR:
wb_command -volume-to-surface-mapping func2highres.nii.gz ${fs_dir}/surf/lh.Inner.surf.gii  lh.func2highres.func.gii -ribbon-constrained ${fs_dir}/surf/${hemi}.Inner.surf.gii  ${fs_dir}/surf/${hemi}.Outer.surf.gii;

You can also use these tools to align to standard surface space (32K) and make a cifti file:

# Merge two hemispheres together
for surface_info in curv sulc; # Could be sulc or curv
do
wb_command -cifti-create-dense-scalar ${fs_dir}/surf/${surface_info}.dscalar.nii \
           -left-metric ${fs_dir}/surf/lh.${surface_info}.32k_fs_LR.func.gii \
           -right-metric ${fs_dir}/surf/rh.${surface_info}.32k_fs_LR.func.gii
done
wb_command -volume-to-surface-mapping func2highres.nii.gz ${fs_dir}/surf/lh.midthickness.32k_fs_LR.surf.gii  lh.func2highres.32k_fs_LR.func.gii -trilinear

wb_command -cifti-create-dense-scalar ${fs_dir}/surf/func2highres.dscalar.nii \
           -left-metric lh.func2highres.32k_fs_LR.func.gii \
           -right-metric rh.func2highres.32k_fs_LR.func.gii


5. Run the QC.
Run the files needed for the Enigma consortium QC. This creates an html file that can be used to check the surfaces on the anatomical image and checks for defects in the labelling of different gyri. To run this, use the following call to an interactive session:

srun --x11 --pty ./scripts/iBEAT/iBEAT_QC.sh analysis/freesurfer/iBEAT/
