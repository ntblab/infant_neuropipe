#!/bin/bash
#
# Generate a report
#
# Provide a path name to some images  in some participant's folders. Wild cards are okay. 
# It will then aggregate all of those pictures into a single html file.
# 
# Run this from the root directory ($PROJ_DIR)
#
# Created by C Ellis 5/21/17

# What is the path to be found (wild cards are okay)
input_path=$1

source globals.sh

# Make sure you are in the root
root=$PROJ_DIR

# Where is the root relative to the output (do relative paths so that this will work if called from my computer)
output2root_path="../../"

# Where is the template stored
report_template="${root}/analysis/report.template"

# Convert the string, dealing with slashes, * and question marks
converted_path=${input_path////_}
converted_path=${converted_path//\*/-star-}
converted_path=${converted_path//\?/-qm-}
converted_path=${converted_path%.png}.html

# What is the file name
output_template="${root}/analysis/report/report_${converted_path}"

echo -e "\nOutputting: ${output_template}\n\nRead on mounted cluster at: file:///Volumes/dev02/analysis/report/report_${converted_path}\n\n"

# Input the command to be used and create the template file
cat $report_template | sed "s:<?= \$PATH_NAME ?>:$input_path:g"	> $output_template 

# Cycle through the subject directories
oldtext="<hr><b>Participants<\/b><p>"
participants=`ls subjects/`
for participant in $participants
do

# Add a header for the text
Line1="<hr><b>${participant}<\/b><p>"
newtext="\n\n${Line1}"
sed -i "s/${oldtext}/${oldtext}${newtext}/" $output_template
oldtext=$Line1

# Make the images in this path.
images=`ls subjects/${participant}/$input_path`

# Iterate through all the images in this path
for image in $images
do

# pull out the image and escape the forward slash
image=${output2root_path////\\/}${image////\\/}

Line1="<p> ${image}"
Line2="<a><IMG BORDER=0 SRC=${image}><\/a>"
newtext="\n\n${Line1}\n\t${Line2}"
sed -i "s/${oldtext}/${oldtext}${newtext}/" $output_template
oldtext=$Line2

done

done