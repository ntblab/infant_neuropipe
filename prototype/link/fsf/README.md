# fsf directory

Put fsf files (the templates for setting FSL FEAT parameters) in this directory. You likely want to change the fsf file for each participant (e.g. to specify the participant name in the file path) and you can do that here by setting up the files appropriately.  

fsf files have the following structure:  

>\# $COMMENT  
>set $FMRI_PARAMETER $PARAMETER_VALUE

Where each parameter is specified seperately. Naming and format must be exact or else the FEAT code will crash with hard to follow errors. However, you can add additional parameter values with different names and there are no consequences.  

To set up an fsf file to be templated, start with the default parameters you want to set and won't want to change between participants (e.g. alignment parameters). Copy the fsf file with these parameters to this directory. Then for every parameter you want to change, replace the parameter with something like:  

>\<?= $PARAMETER_VALUE ?\>  

Then, in the $PROJ_DIR/prototype/link/scripts/render-fsf-templates.sh script you need to edit the lines with the form:  

>\| sed "s:\<?= \\$PARAMETER_VALUE ?\>:$parameter_value:g"  

This basically does a find-replace for the section of text interested in the fsf file.  

By default the $PROJ_DIR/prototype/link/scripts/render-fsf-templates.sh script references the template called firstlevel.fsf.template but if you want to specify a different one to be used by this script, specify that as the fourth input variable.
