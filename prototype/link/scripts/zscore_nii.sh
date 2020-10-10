#!/bin/bash
#
# Z scores a nifti through time. Takes as an input the name of the functional to be z scored and also then the name of the output. 
# This script shouldn't be used in most circumstances because z_score_exclude.m accounts for TRs that are excluded, but nonetheless it is still here.
# It can be useful if you just want to z score a single volume
#
# Ellis 2/14/17	

#If there aren't to inputs then quit	
if [ $# -lt 2 ]
then
exit 1
fi

Input=$1
Output=$2

# Get the number of volumes
n_vols=`fslnvols $Input`

if [ $n_vols -gt 1 ]
then

fslmaths $Input -Tstd temp.nii.gz

#Generate the normalized volume
fslmaths $Input -Tmean -sub $Input -div	temp.nii.gz -mul -1 $Output

else

echo Found one volume, zscoring within volume

mean_val=`fslstats $Input -M`
sd_val=`fslstats $Input -S`

fslmaths $Input -sub $mean_val -div $sd_val $Output

# Mask the data
fslmaths $Input -abs -bin temp.nii.gz
fslmaths $Output -mas temp.nii.gz $Output

fi

# Delete temporary volume
rm -f temp.nii.gz
