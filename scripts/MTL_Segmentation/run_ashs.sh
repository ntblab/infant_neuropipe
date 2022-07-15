#!/bin/bash
#
# Run atlas execution from ashs script as a batch job
#
# Example:
# sbatch run_ashs.sh -I subj01_ID -a /ashsdirpath/myashsdir -g  subj01_T1.nii.gz -f  subj01_T2.nii.gz.nii.gz -w /workdir/subj01/
#
#SBATCH --output=./logs/atlas_ashs-%j.out
#SBATCH -p psych_day
#SBATCH -t 24:00:00
#SBATCH --mem 40000

# Get all of the inputs
for input in "$@"
do
        if [ ! -z "$input_str" ]
        then
                input_str=`echo ${input_str} ${input}`
        else
                input_str=${input}
        fi
done

# Run the command
echo $ASHS_ROOT/bin/ashs_main.sh $input_str
$ASHS_ROOT/bin/ashs_main.sh $input_str
