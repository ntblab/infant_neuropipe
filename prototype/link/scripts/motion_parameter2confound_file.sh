#!/bin/bash
#
# Create a confound matrix using the parameter file supplied, as well as the fd threshold and the output file root (will use for both the metric and confound file)

# Set up file names
input_parameter_file=$1 # Full path to the parameter file used as an input
threshv=$2 # What is the fd threshold in millimeters
output_root=$3 # Full path to where you want to put both the metric and the confound file

# Additional setup files
outdir="./temp"
savefile=${output_root}_metric.txt
outfile=${output_root}_confounds.txt

# Prep the directory
mkdir ${outdir}_mc/

# Get info on the param file
tmax=`cat $input_parameter_file | wc -l`
tmax1=`echo $tmax - 1 | bc`;
col_num=`awk '{print NF}' $input_parameter_file | sort -nu | tail -n 1`

# The motion metric calculator
${FSLDIR}/bin/fslascii2img ${input_parameter_file} 1 1 $tmax $col_num 1 1 1 1 ${outdir}_mc/res_mse_par
${FSLDIR}/bin/fslroi ${outdir}_mc/res_mse_par ${outdir}_mc/res_mse_par_rot_full 0 3
${FSLDIR}/bin/fslroi ${outdir}_mc/res_mse_par ${outdir}_mc/res_mse_par_trans_full 3 3

# calculate time differences of all parameters
${FSLDIR}/bin/fslroi ${outdir}_mc/res_mse_par_rot_full ${outdir}_mc/res_mse_par_rot0 0 1 0 1 0 $tmax1
${FSLDIR}/bin/fslroi ${outdir}_mc/res_mse_par_rot_full ${outdir}_mc/res_mse_par_rot1 0 1 0 1 1 $tmax1
${FSLDIR}/bin/fslmaths ${outdir}_mc/res_mse_par_rot1 -sub ${outdir}_mc/res_mse_par_rot0 ${outdir}_mc/res_mse_par_rot
${FSLDIR}/bin/fslroi ${outdir}_mc/res_mse_par_trans_full ${outdir}_mc/res_mse_par_trans0 0 1 0 1 0 $tmax1
${FSLDIR}/bin/fslroi ${outdir}_mc/res_mse_par_trans_full ${outdir}_mc/res_mse_par_trans1 0 1 0 1 1 $tmax1
${FSLDIR}/bin/fslmaths ${outdir}_mc/res_mse_par_trans1 -sub ${outdir}_mc/res_mse_par_trans0 ${outdir}_mc/res_mse_par_trans

# multiply rots (radians) by 50mm and add up with abs translations to get FD in Power et al, 2011
${FSLDIR}/bin/fslmaths ${outdir}_mc/res_mse_par_rot -abs -mul 50 ${outdir}_mc/res_mse_par_rot
${FSLDIR}/bin/fslmaths ${outdir}_mc/res_mse_par_rot -Tmean -mul 3 ${outdir}_mc/res_mse_par_rotsum
${FSLDIR}/bin/fslmaths ${outdir}_mc/res_mse_par_trans -abs -Tmean -mul 3 ${outdir}_mc/res_mse_par_transsum
${FSLDIR}/bin/fslmaths ${outdir}_mc/res_mse_par_transsum -add ${outdir}_mc/res_mse_par_rotsum ${outdir}_mc/res_mse_diffZ
${FSLDIR}/bin/fsl2ascii ${outdir}_mc/res_mse_diffZ ${outdir}_mc/res_mse_diff.txt
grep [0-9] ${outdir}_mc/res_mse_diff.txt0* > ${outdir}_mc/res_mse_diff.txt
${FSLDIR}/bin/fslascii2img ${outdir}_mc/res_mse_diff.txt 1 1 1 $tmax1 1 1 1 1 ${outdir}_mc/res_mse_diff

# Output the metric file
$FSLDIR/bin/fsl2ascii ${outdir}_mc/res_mse_diff ${outdir}_mc/vals.txt
echo "0" > ${savefile}
cat ${outdir}_mc/vals.txt[0-9]* | grep [0-9] >> ${savefile}
rm ${outdir}_mc/vals.txt[0-9]*

# Make the thresholded outlier file
$FSLDIR/bin/fslmaths ${outdir}_mc/res_mse_diff -thr $threshv -bin ${outdir}_mc/outliers
$FSLDIR/bin/fslroi ${outdir}_mc/outliers ${outdir}_mc/one 0 1 0 1 0 1 0 1
$FSLDIR/bin/fslmaths ${outdir}_mc/one -mul 0 ${outdir}_mc/zero
$FSLDIR/bin/fslmerge -t ${outdir}_mc/outliers ${outdir}_mc/zero ${outdir}_mc/outliers

# Make the confound matrix
if [ -f $outfile ] ; then rm -f $outfile ; fi
nvals="";
n=0;
while [ $n -lt $tmax ] ; do
  $FSLDIR/bin/fslmaths ${outdir}_mc/outliers -roi 0 1 0 1 0 1 $n 1 ${outdir}_mc/stp
  val=`$FSLDIR/bin/fslstats ${outdir}_mc/stp -V | awk '{ print $1 }'`;
  if [ $val -gt 0 ] ; then
      nvals="$nvals $n";
      $FSLDIR/bin/fslmeants -i ${outdir}_mc/stp -o ${outdir}_mc/singleev;
      if [ -f $outfile ] ; then
          paste -d ' ' $outfile ${outdir}_mc/singleev > ${outfile}2
          cp ${outfile}2 $outfile
          rm -f ${outfile}2
      else
          cp ${outdir}_mc/singleev $outfile
      fi
  fi
  n=`echo "$n + 1" | bc`;
done

# Cleanup
rm -rf ${outdir}_mc
