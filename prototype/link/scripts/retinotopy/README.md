# Analysis pipeline for retinotopy

This outlines the analysis pipeline for running retinotopy analyses. This assumes that the normal infant\_neuropipe steps have been completed.

1. Run retinotopy GLMs.
Use **sbatch ./scripts/retinotopy/supervisor_retinotopy.sh** to run the necessary GLMs to compare high and low spatial frequency, horizontal and vertical meridians, and the F-test of all conditions.


2. Create a Freesurfer directory that you can use for surface reconstruction.
This directory can be created with FreeSurfer or by adapting iBEAT. To use Freesurfer you can use `scripts/run_recon.sh` as a script for launching the job. If using iBEAT then follow the steps described in the `convert_iBEAT-FS.md` README. This freesurfer directory must be able to have SUMA created from it.


3. Make the cuts in the inflated surface using tksurfer
With the freesurfer directory set up you can run tksurfer to make cuts of the inflated surface. Where you should make the cuts is outlined here: https://surfer.nmr.mgh.harvard.edu/fswiki/FreeSurferOccipitalFlattenedPatch

It might be possible to run this on the cluster but you probably want to pull it locally to keep your sanity. Regardless I am assuming that you are in a subject directory and that there is a folder called `./analysis/freesurfer/iBEAT/`. Once in the participant directory run these commands, once for each hemisphere. This command creates a gifti file that can be used to help guide the cut, and then loads it in to tksurfer. It assumes you have a file called `meridian_zstat3_aligned.nii.gz` in the director which is created by the GLM in step (1) or alternatively can be found in the data release in the `contrast_maps` folder:

```
SUBJECTS_DIR=$(pwd)/analysis/freesurfer/
export SUBJECTS_DIR
hemi=lh
wb_command -volume-to-surface-mapping meridian_zstat3_aligned.nii.gz analysis/freesurfer/iBEAT/surf/${hemi}.midthickness.surf.gii analysis/freesurfer/iBEAT/surf/${hemi}.meridian_zstat3_aligned.func.gii -trilinear
tksurfer iBEAT $hemi inflated -o analysis/freesurfer/iBEAT/surf/${hemi}.conv.gii -fthresh 0.1 -o analysis/freesurfer/iBEAT/surf/${hemi}.meridian_zstat3_aligned.func.gii -fminmax 0 3
```


4. Flatten the cut surfaces
If working on files locally, move them back on to the cluster to the `analysis/freesurfer/iBEAT/surf/` folder. Then use those newly created files to cut and flatten the surface using these scripts (takes about an hour):

```
sbatch scripts/retinotopy/run_mris_flatten.sh lh iBEAT
sbatch scripts/retinotopy/run_mris_flatten.sh rh iBEAT
```


5. Make the SUMA files
You need to make SUMA spec files so that they can be opened in AFNI.

cd analysis/freesurfer/iBEAT/
@SUMA_Make_Spec_FS -sid iBEAT

Also move any files that you want into that SUMA folder, make sure the volumes are aligned to the SAME highres as the surfaces are

6. Load data into SUMA

Plot the data on the flat map using SUMA. Again, this might be possible on the cluster but you probably want to do this locally. There are two main options, the first uses AFNI and SUMA, the second uses just SUMA. Like the results published using this data, you likely want to use the 95\% range for the color axis to give a good dynamic range from which to start.  

## Option 1: AFNI plus SUMA

To launch AFNI and SUMA run the following command.

`afni -niml & suma -spec $(pwd)/SUMA/${SUBJ}_both.spec -sv $(pwd)/SUMA/${SUBJ}_SurfVol+orig.BRIK -ah 127.0.01`

This should load in a volume and the reconstructed surfaces. Put the cursor over the SUMA window and press 't' to link SUMA and AFNI so that they show the same coordinates and overlays. Also while the cursor is in the window, press the ',' and '.' keys to cycle through the different views/surfaces of the brain. Use the arrow keys (shift and arrow keys to translate) or mouse to rotate the brain. Z and shift+Z are for zooming. Press b to hide the background

Look at the attached image called AFNI\_SUMA\_navigation.png: the circled locations with the associated numbers are labelled with stars in the following text. In the AFNI menu click the 'overlay' key (1) and select the volume you want to overlay on to the map (the contrast maps that were transferred into the SUMA directory). In the Define Overlay tab (2) you want to set up the colors.

When you are looking at contrast maps you will first want to check that the range of values (3) is set according to what you want. You can check any single value at (4). Unclick autoRange (8) and set the max of the (9, what 1.0 corresponds to on the color map).

## Option 2: SUMA alone

The above approach is flexible, but not efficient when wanting to look at specific data quickly. Instead you can make files specifically for SUMA and just load those in. 

Do the following to make a 1D file that SUMA recognizes

```
hemi=lh
func=meridian_zstat3 # Name of a functional file in the SUMA folder
prefix="" # Could be "" or "std.141."
spec_file=SUMA/${prefix}iBEAT_${hemi}.spec # What spec do you want to use (could be in standard space or not)
vol_file=SUMA/${func}_aligned.nii.gz
out_file=SUMA/${prefix}${func}.${hemi}.1D.dset
3dVol2Surf -spec ${spec_file} -sv ${vol_file} -out_1D $out_file -surf_A smoothwm -grid_parent ${vol_file} -map_func mask
```

You can then append these files using 1dcat (e.g. 1dcat -sel '[6]' file.1d.dset file.1d.dset > out.1d.dset)  and piping the output. To use them for the purpose of thresholding, you put the functional of interest in the 'I' metric (e.g. `sf_zstat3`) and then the 'T' metric to use for thresholding (e.g. `task_zstat7.nii.gz`)

7. Draw the regions

To draw in SUMA, go to Tools, then 'draw ROI' to open a dialog box. Set a label for what you are drawing, and give it an intensity value. Intensity labels are as follows:
vV1=1
vV2=2
vV3=3
vV4=4
dV1=5
dV2=6
dV3=7
dV3AB=8

If there is a hint of a region but it is not clear then add 10 to these numbers (e.g., vV2 becomes 12) to signal the uncertainty

To trace a path outlining the region, click on the surface (don't drag). Undo works well, even when reloading a tracing in. You don't want to draw the ROIs to the foveal confluence since you will lack precision there.

When you have looped back to your starting point, click join. Now, click in the middle of the ROI to fill it in. The color should change, then click finish. Once finished, you can change the label/intensity and start drawing the next one. Once this is all done, save the output. You will need to save before you switch hemispheres since there should be one file per hemisphere. The file name should be `${hemi}.manual`

The full details for how to trace these ROIs is outside of the scope of this document but Arcaro et al 2009 and Wandell et al 2007 are very useful. In general, the goal of tracing the ROIs is to look for alternations in the sensitivity across the posterior to anterior extent of the regions. These alternations may not be consistent across the whole region and may not show full sign changes, but that is part of the judgment call.

Here are some niche tips for tracing the ROIs from meridian mapping:

Don't be afraid to make V4/V3AB curvier than the other boundaries
When you show the F-stat map, there should be a ventral fork into VO and PHC
The lateral boundary of the regions can be determined by the F-stat
Threshold the data based on the condition relevant F-stat if unsure whether voxels with zero difference are noise or strongly representing both
To know where vV4 is, look for the collateral sulcus on the uninflated surface and then switch back
Often there is a blob anterior to ventral V4 that is sensitive to horizontal that should be ignored and drawn around


8. Tke efficient screenshots of the regions

Make 1D files that can be used to take pictures of individual hemispheres of the data. In particular, this makes a 1D file with functional data (e.g., SF or meridian) and the traced regions in a single data file that can be loaded on the brain

```
func=meridian_zstat3 # Name of a functional file in the SUMA folder
vol_file=SUMA/${func}_aligned.nii.gz
for hemi in lh rh; do 
	out_file=SUMA/${prefix}${func}.${hemi}.1D.dset; 
	spec_file=SUMA/${prefix}iBEAT_${hemi}.spec; 
	3dVol2Surf -spec ${spec_file} -sv ${vol_file} -out_1D $out_file -surf_A smoothwm -grid_parent ${vol_file} -map_func mask;  
	1dcat -sel '[6]' $out_file > temp.txt; # Convert the functional into a 1D file
	mv temp.txt $out_file # Rename (doesn't work to store with this name if it already exists)
	ROI2dataset -prefix SUMA/${hemi}.manual_rois -input SUMA/${hemi}.manual_rois.niml.roi # The name of the ROIS created is used here
	suma -i SUMA/${prefix}${hemi}.full.flat.patch.3d.asc -input SUMA/${prefix}${func}${hemi}.1D.dset SUMA/${hemi}.manual_rois.niml.dset -sv $(pwd)/SUMA/iBEAT_SurfVol+orig.BRIK -ah 127.0.01; 
done
```


9. Trace the lines within the regions

In order to trace lines on the regions, use the 1D file created above for viewing the areas, but **critically** hide the horizontal versus vertical statistic map. This is necessary to remain blind. 

There are two types of lines to draw, ones that are perpendicular to the region boundaries and ones that are parallel to the region boundaries. The perpendicular lines are drawn starting at the most posterior point of the surface (can be a little tricky since you will be clicking near the edge) and then extend to the anterior edge of the regions you labelled. Once you have drawn a line, click Finish, and then start the next. You should draw 5 equally spaced lines across the lateral extent of the regions. These will all be named `${dorsal_or_ventral}${hemi}` (e.g. vlh) and have an intensity of 1. THis means you should have separately traced lines for left and right, as well as ventral and dorsal (4 files per participant). These lines should be saved as: `{dorsal_or_ventral}${hemi}.lines`. 

The parallel lines also need to be drawn using a similar procedure except that the lines will start from the medial/foveal edge and emanate laterally. Two lines should be drawn per region, approximately dividing the region into 3 equally sized slices, and each line will be labeled with the appropriate region name (e.g. vV1) and have an intensity of 1. This will again be done separately for left and right, as well as dorsal and ventral regions These files should be saved as: `{dorsal_or_ventral}${hemi}.ortho_lines`



