#!/bin/sh
# Perform registration on a feat folder. This is based closely off
# mainfeatreg but, critically, with control over what cost function to
# use for feat. This creates a registration folder in the feat directory
#
# C Ellis 081917
# 
#SBATCH --output=feat_reg-%j.out
#SBATCH -p short
#SBATCH -t 60
#SBATCH --mem 20000

# Pull out the fsl path (assumes that FSL has been loaded)
fslpath=`which feat`
fslpath=${fslpath%feat}

# Set up functions
get_opt1() {
    arg=`echo $1 | sed 's/=.*//'`
    echo $arg
}

get_arg2() {
    if [ X$2 = X ] ; then
        echo "Option $1 requires an argument" 1>&2
        exit 1
    fi
    echo $2
}

# Interpret inputs and use them to specify parameters

# Set defaults
highres_cost=normmi
standard_cost=normmi

if [ $# -eq 0 ] ; then usage; exit 0; fi
if [ $# -lt 3 ] ; then usage; exit 1; fi
niter=0;
while [ $# -ge 1 ] ; do
    niter=`echo $niter + 1 | bc`;
    iarg=`get_opt1 $1`;
    case "$iarg"
        in
        --FEAT_Folder)
            FEAT_Folder=`get_arg2 $1 $2`;
            shift 2;;
        --highres)
            highres=`get_arg2 $1 $2`;
            shift 2;;
        --standard)
            standard=`get_arg2 $1 $2`;
            shift 2;;
        --highres_cost)
            highres_cost=`get_arg2 $1 $2`;
            shift 2;;
        --standard_cost)
            standard_cost=`get_arg2 $1 $2`;
            shift 2;;
    esac
done

# Do these files exist?
if [ ! -e $FEAT_Folder ] || [ ! -e $highres ] || [ ! -e $standard ]
then
	echo "Couldn't find the files"
	echo "Feat: $FEAT_Folder"
	echo "highres: $highres"
	echo "standard: $standard"
	exit
fi

# Set up folder
/bin/mkdir -p ${FEAT_Folder}/reg

# Move into the registration directory
cd ${FEAT_Folder}/reg

${fslpath}fslmaths ../example_func example_func

${fslpath}fslmaths ${highres} highres

${fslpath}fslmaths ${standard} standard

# Reg example func to highres
${fslpath}flirt -in example_func -ref highres -out example_func2highres -omat example_func2highres.mat -cost ${highres_cost} -searchcost ${highres_cost} -dof 6 -searchrx -30 30 -searchry -30 30 -searchrz -30 30 -interp trilinear

${fslpath}convert_xfm -inverse -omat highres2example_func.mat example_func2highres.mat

${fslpath}slicer example_func2highres highres -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png 
${fslpath}pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2highres1.png ; 
${fslpath}slicer highres example_func2highres -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png ; 
${fslpath}pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2highres2.png ; 
${fslpath}pngappend example_func2highres1.png - example_func2highres2.png example_func2highres.png; 
rm -f sl?.png example_func2highres2.png

rm example_func2highres1.png

# Reg highres to standard
${fslpath}flirt -in highres -ref standard -out highres2standard -omat highres2standard.mat -cost ${standard_cost} -searchcost ${standard_cost} -dof 12 -searchrx -30 30 -searchry -30 30 -searchrz -30 30 -interp trilinear

${fslpath}convert_xfm -inverse -omat standard2highres.mat highres2standard.mat

${fslpath}slicer highres2standard standard -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png ; 
${fslpath}pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png highres2standard1.png ; 
${fslpath}slicer standard highres2standard -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png ; 
${fslpath}pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png highres2standard2.png ; 
${fslpath}pngappend highres2standard1.png - highres2standard2.png highres2standard.png; 
rm -f sl?.png highres2standard2.png

rm highres2standard1.png

${fslpath}convert_xfm -omat example_func2standard.mat -concat highres2standard.mat example_func2highres.mat

# Reg example func to standard
${fslpath}flirt -ref standard -in example_func -out example_func2standard -applyxfm -init example_func2standard.mat -interp trilinear

${fslpath}convert_xfm -inverse -omat standard2example_func.mat example_func2standard.mat

${fslpath}slicer example_func2standard standard -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png ; 
${fslpath}pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2standard1.png ; 
${fslpath}slicer standard example_func2standard -s 2 -x 0.35 sla.png -x 0.45 slb.png -x 0.55 slc.png -x 0.65 sld.png -y 0.35 sle.png -y 0.45 slf.png -y 0.55 slg.png -y 0.65 slh.png -z 0.35 sli.png -z 0.45 slj.png -z 0.55 slk.png -z 0.65 sll.png ; 
${fslpath}pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png + sli.png + slj.png + slk.png + sll.png example_func2standard2.png ; 
${fslpath}pngappend example_func2standard1.png - example_func2standard2.png example_func2standard.png; 
rm -f sl?.png example_func2standard2.png