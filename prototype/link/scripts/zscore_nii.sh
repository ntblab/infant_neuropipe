#!/bin/bash
#
# Z scores a nifti through time. Takes as an input the name of the functional to be z scored and also then the name of the output. 
# This script shouldn't be used in most circumstances because z_score_exclude.m accounts for TRs that are excluded, but nonetheless it is still here
#
# Ellis 2/14/17	

#If there aren't to inputs then quit	
if [ $# -lt 2 ]
then
exit 1
fi

Input=$1
Output=$2

fslmaths $Input -Tstd temp.nii.gz

#Generate the normalized volume
fslmaths $Input -Tmean -sub $Input -div	temp.nii.gz -mul -1 $Output

rm -f temp.nii.gz
