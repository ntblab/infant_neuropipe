# Repository for running the predict_retinotopy analyses

This directory contains the scripts necessary to produce the figures and results from the paper "Movies reveal the fine-grained organization of infant visual cortex" by Ellis, Yates, Arcaro, & Turk-Browne.  

The primary script to refer to is `predict_retinotopy.ipynb`, a jupyter notebook that aggregates the data and outputs of other functions to produce the statistics and figures from the paper. To be able to run this script, you will need to have all of the data downloaded into the `data/` directory. Specifically, you need the [retinotopy data](https://doi.org/10.5061/dryad.7h44j0ztm) and the preprocessed movie data (Dryad link to come). 

The only change to the scripts that you must make in order to run the code is the path specified in `utils.py`.

The notebook should run without further edits; however, some cells in the notebook will take a long time to run as they are generating files. Ruunning the notebook will allow you to replicate the results from the paper, although some statistics might differ slightly based on random seeds.  

You will not be able to run the scripts `SRM_predict_retinotopy` and `time_segment_matching_features` because they call on data from the `data/Movie/` directory. This data is too large to upload, so instead the outputs of the scripts are uploaded with the data release. The same logic applies to the adult data which is also uploaded in only its preprocessed form.

The command to run the ICA was: `melodic -i analysis/secondlevel_${MOVIE}/default/NIFTI/func2highres_${MOVIE}_Z.nii.gz -o analysis/secondlevel_${MOVIE}/default/func2highres_${MOVIE}_Z.ica -v --nobet --bgthreshold=1 --tr=2 -d 0 --mmthresh=0.5 --report --guireport=analysis/secondlevel_${MOVIE}/default/func2highres_${MOVIE}_Z.ica/report.html`. This was run in each participant's directory with `${MOVIE}` set to either `MM` or `ChildPlay`. The `melodic_IC.nii.gz` output was taken from this directory and used for these analyses.

In the SRM scripts (`SRM_predict_retinotopy` and `time_segment_matching_features`), there are two groups that are specified with shorthand names. One is the group that the target participant, whose data is being predicted, belongs to: this group is labeled ‘loo’ (short for ‘leave one out’. This terminology is akin to machine learning uses, where it means this participant isn't included in fitting). The other group is the group that is used to fit the SRM: this group is labeled ‘ref’ (short for ‘reference’). 

Additional functions in this folder:  

>`run_SRM_predict_retinotopy.sh`: Shell script to launch the prediction of retinotopy using a shared response model. This takes five inputs:  
>> `ID`:  Participant ID for the one that is being left out of the SRM and whose retinotopy data is being predicted.   
>> `features`: Number of features that are used when training the SRM. Must be an integer  
>> `is_infant_ref`:  Do you want to use infants for training the SRM (1) or the adults (0)  
>> `mask_type`:  What mask do you want to use (e.g., 'occipital')  
>> `is_control`:  Do you want to flip the data when fitting the SRM, so that the learned mapping is meaningless (i.e., this is a control analysis)   
    
>`SRM_predict_retinotopy.py`: Use a reference group to fit a shared response model, map retinotopy data from that reference group into the SRM and then predict a held out participant's map  

>`run_time_segment_matching_features.sh`: Shell script to launch time segment matching  
>> `ID`:  Participant ID for the one that is being left out of the SRM and whose movie data is being predicted.   
>> `features`: Number of features that are used when training the SRM. Must be an integer  
>> `is_infant_ref`:  Do you want to use infants for training the SRM (1) or the adults (0)  
>> `mask_type`:  What mask do you want to use (e.g., 'occipital')  

>`time_segment_matching_features.py`: Use a reference group to fit a shared response model and fit a held out participant's data into that space. Hold out a segment of movie data (10 TRs) from that participant and try and predict when in the movie it comes from by using the reference participants.   

>`transform_surface_2_standard.sh`: Shell script to realign surface data into standard space (Buckner 40 template). This can be used for the functional data or a statistics map   
>> `SUMA_folder`: What SUMA folder was used for this participant. 
>> `func_file`: What is functional file that you want to transform to standard
>> `hemisphere`: What hemisphere are you using (lh or rh)
>> `output_dir`: Where do you want to store data
>> `output_prefix`: If supplied, add a prefix to the output (e.g., std.141.)

>`utils.py`: Sets up the necessary paths and functions to be used in the scripts described here   
