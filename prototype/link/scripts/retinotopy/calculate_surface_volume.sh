#!/bin/bash
# 
# Take a freesurfer directory, a hemisphere, and a niml file from a participants ROI tracing and create text files that have the volume at each node (for wm and pial separately).
# This can then be used by $PROJ_DIR/scripts/retinotopy/Retinotopy.ipynb to calculate the volume per ROI and plot the results
# For instance you can use these commands:
# ./scripts/retinotopy/calculate_surface_volume.sh iBEAT rh rh.manual
#
#SBATCH --output=./logs/calculate_surface_volume-%j.out
#SBATCH -p short
#SBATCH -t 4:00:00
#SBATCH --mem 20000

# Get the inputs
FREESURFER_NAME=$1 # What is the name of the freesurfer directory being loaded. Must be in analysis/freesurfer/
hemisphere=$2 # What hemisphere are you using
niml_name=$3 # What is the prefix of the ROI you saved

# Move in to the participant directory
cd analysis/freesurfer/${FREESURFER_NAME}/SUMA/

# Make the roi file into a dataset, separating all of the ROIs
surf_input=${niml_name}.niml.roi
rm -f $niml_name.1D.dset # In case it exists
ROI2dataset -prefix $niml_name -keep_separate -of 1D -input $surf_input

columns=`awk '{print NF}' ${niml_name}.1D.dset | sort -nu | tail -n 1` # How many columns are there
columns=`echo $columns - 1 | bc` # Subtract one since zero indexing

# Find out how many nodes there are that need padding
SurfaceMetrics -coords -i ${hemisphere}.full.flat.patch.3d.asc -prefix temp_${niml_name}
padded_nodes=`grep -o '^[^#]*' temp_${niml_name}.coord.1D.dset | wc -l`
padded_nodes=`echo $padded_nodes - 1 | bc`
rm -f temp_${niml_name}.coord.1D.dset

# Do the padding
ConvertDset -o_1D -input ${niml_name}.1D.dset -prefix ${niml_name}_padded -pad_to_node ${padded_nodes} -node_index_1D ${niml_name}.1D.dset[0]

# Transform this ROI into standard space (not needed here, but might as well do it)
rm -f std.141.${hemisphere}.manual.1D
SurfToSurf -i_fs std.141.${hemisphere}.full.flat.patch.3d.asc -i_fs ${hemisphere}.full.flat.patch.3d.asc -prefix std.141.${hemisphere}.manual -data "${niml_name}_padded.1D.dset" -mapfile std.141.${FREESURFER_NAME}_${hemisphere}.niml.M2M -output_params NearestNode

# Now remove the first columns with irrelevant details
1dcat -sel [2-$] std.141.${hemisphere}.manual.1D > temp_${niml_name}.1D
mv temp_${niml_name}.1D std.141.${hemisphere}.manual.1D

mkdir ROI_${niml_name} # Make a directory to put results

# Cycle through columns but know that each column doesnt necessarily correspond to an ROI, hence you need to actually read the numbers
for col_idx in `seq 1 $columns`
do

# What ROI are you considering (i.e. what number is in this column)
1dcat -sel [$col_idx] ${niml_name}.1D.dset > temp_${niml_name}.1D
ROI_idx=`cat temp_${niml_name}.1D | tr ' ' '\n' | sort -u | tr '\n' ' ' | awk '{print $NF}'`
rm -f temp_${niml_name}.1D

# Computing statistics from each ROI

echo "Computing area for ROI $ROI_idx"

rm -f ROI_${niml_name}/${hemisphere}_area_${ROI_idx}.1D # In case this already exists
 
 # Do the computation of wm and pial area for this ROI
SurfMeasures \
-nodes_1D "${niml_name}.1D.dset[0]" \
-cmask "-a ${niml_name}.1D.dset[${col_idx}] -expr (ispositive(a-0.1))" \
-spec ${FREESURFER_NAME}_${hemisphere}.spec \
-sv ${FREESURFER_NAME}_SurfVol+orig \
-surf_A ${hemisphere}.smoothwm \
-surf_B ${hemisphere}.pial \
-func n_area_A \
-func n_area_B \
-out_1D ROI_${niml_name}/${hemisphere}_area_${ROI_idx}.1D

# Check that the output file was actually made
file_length=`cat ROI_${niml_name}/${hemisphere}_area_${ROI_idx}.1D | wc -l`
if [ $file_length -gt 2 ]
then

# Clean up the file so that it can be used for summing the values
tmpfile=$(mktemp /tmp/calculate_surface_volume.XXXXXX)
tail -n +3 ROI_${niml_name}/${hemisphere}_area_${ROI_idx}.1D > ${tmpfile}
awk '{ print $2 }' ${tmpfile} > ROI_${niml_name}/${hemisphere}_area_${ROI_idx}_wm.txt
awk '{ print $3 }' ${tmpfile} > ROI_${niml_name}/${hemisphere}_area_${ROI_idx}_pial.txt
rm -f ${tmpfile}

else
echo No ROI $ROI_idx found
rm -f ROI_${niml_name}/${hemisphere}_area_${ROI_idx}.1D
fi


done

echo Finished
