#!/bin/sh
#
# Change the meta data of a gifti file so that it is recognized by HCP workbench
#
#SBATCH --output=./change_meta-%j.out
#SBATCH -p short
#SBATCH -t 5
#SBATCH --mem 200

# First load in the surface file that you are going to be fixing 
surf_file=$1

# What do you want to save the data as?
out_file=$2

# Which cortex is it? 
if [[ ${surf_file} == *"lh"* ]]
then 
	cortex='CortexLeft'
else 
	cortex='CortexRight'
fi

echo Looking for $cortex

# Then save out the metadata to a temporary text file
line_num=`grep -n $cortex $surf_file` 
line_num=${line_num%:*}
new_line=$((line_num+2)) # you go two lines after the Cortex data

echo Found match on line $new_line

# Add in the new lines to that temporary file

head -${new_line} $surf_file > temp_new_meta.txt
echo "		<Name><![CDATA[GeometricType]]></Name> 
		<Value><![CDATA[Anatomical]]></Value>
	</MD> 
	<MD>" >> temp_new_meta.txt

new_line=$((line_num+3)) # Increment to go to the next line
tail -n +${new_line} $surf_file >> temp_new_meta.txt

# Rename output
mv temp_new_meta.txt ${out_file}
echo Finished
