#!/bin/bash
# 
# Transform a functional file supplied into std.141 space
#
# For instance you can use these commands:
# ./scripts/predict_retinotopy/transform_surface_2_standard.sh $proj_dir/data/Retinotopy//iBEAT/s8687_1_5/SUMA/ $proj_dir/data/predict_retinotopy//movie_1d/s8687_1_5//rh.Aeronaut.1d.dset rh $proj_dir/data/predict_retinotopy//movie_1d/s8687_1_5/ std.141. 
#
#SBATCH --output=./logs/transform_surface-%j.out
#SBATCH -p psych_day
#SBATCH -t 20:00
#SBATCH --mem 5000

source globals.sh

# Get the inputs
SUMA_folder=$1 # What SUMA folder was used for this participant. 
func_file=$2 # What is functional file that you want to transform to standard
hemisphere=$3 # What hemisphere are you using
output_dir=$4 # Where do you want to store data
output_prefix=$5 # If supplied, add a suffix to the output

FREESURFER_NAME=iBEAT # This is the name used throughout
file_root=${func_file##*/} # Get the name to output
file_root=${file_root%%.1d.dset}
file_root=${file_root%%.1D*}


# Transform this ROI into standard space needed for doing a subsidiary analysis
echo Transforming to standard space

SurfToSurf -i_fs ${SUMA_folder}/std.141.${hemisphere}.full.flat.patch.3d.asc -i_fs ${SUMA_folder}/${hemisphere}.full.flat.patch.3d.asc -prefix ${output_dir}/${output_prefix}${file_root} -data "${func_file}" -mapfile ${SUMA_folder}/std.141.${FREESURFER_NAME}_${hemisphere}.niml.M2M -output_params NearestNode

# Now remove the first columns with irrelevant details
1dcat -sel [2-$] ${output_dir}/${output_prefix}${file_root}.1D > ${output_dir}/temp_${file_root}.1D
mv ${output_dir}/temp_${file_root}.1D ${output_dir}/${output_prefix}${file_root}.1D


echo Finished
