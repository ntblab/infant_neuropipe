# Analysis of awake infant fMRI

Analyses from:

Ellis, Skalaban, Yates, Bejjanki, Cordova, & Turk-Browne (in prep). *How to read a baby's mind: Redesigning fMRI for awake, behaving infants*.

To perform these analyses you need to have the data from the associated manuscript downloaded. It is recommended that you store it in '$PROJ_DIR/data/methods_data/' otherwise you will need to change paths. 

## SFNR analyses

To run the SFNR analyses, run $PROJ\_DIR/scripts/preprocessing\_exploration/Analysis\_SFNR\_gradient\_infants.m. This will perform the SFNR computation on all of the data and then should produce a plot similar to that reported (but may differ slightly due to the random sampling of voxels in the slices). This will also produce text files that contain summary information that can be analyzed using ${PROJ_DIR}/scripts/preprocessing\_exploration/sfnr\_anova.R. Note that the adult data used in this analysis is not included for comparison.

## Exploration of preprocessing analysis parameters

This code explores how different preprocessing parameters affect the magnitude of different metrics of signal. These analyses are premised on the idea that there should be a strong evoked response in visual regions when contrasting task with rest and that the pattern of activity evoked in visual regions by a stimulus should be consistent across presentations.

The jupyter notebook '$PROJ_DIR/scripts/preprocessing_exploration/preprocessing_exploration.ipynb' can recreate the plots reported in the manuscript based on the stored statistic maps. This script should only need to be edited with two paths in order to run (path to infant_neuropipe repo (AKA $PROJ_DIR) and path to where the data is stored (e.g., $PROJ_DIR/data/methods_data/)).

If you want to remake these statistic maps or to run new analyses for each participant, the directory '$SUBJ_DIR/scripts/preprocessing_exploration/' contains the necessary scripts to generate analyses at the first-level with different preprocessing parameters. There are 4 separate steps that must be performed to create the feat folders for each analysis type. The README in this directory ('$SUBJ_DIR/scripts/preprocessing_exploration/README.md') contains additional details that go into greater detail:

1. The first step is to create the motion confound files using step 7 of 'prep_raw_data'. Importantly, it doesn't overwrite the default confound files (that only happens in step 8 of prep_raw_data). This will create the motion confound files for different motion thresholds and also for cases where there are other motion parameter exclusion criteria. 
2. Next step is to run '$SUBJ_DIR/scripts/preprocessing_exploration/preprocessing_exploration.sh' which iterates through the different analysis types and generates a feat folder for each run and analysis type. To do this it first creates an fsf file, confound files and timing files for these analysis parameters. Different analysis decisions affect the timing files in different ways, for instance a stricter motion exclusion criteria will exclude more blocks. These feat analyses are then run. 
3. Next run '$SUBJ_DIR/scripts/preprocessing_exploration/preprocessing_exploration_test.sh'. This script pulls the registration information for this run and aligns the data in to standard space. It also aligns masks to this data and outputs summary statistics for the task vs rest analyses to text files in the '$PROJ_DIR/results/preprocessing_exploration/' folder. 
4. Once you have run the preprocessing on each run separately, it is possible to run '$SUBJ_DIR/scripts/preprocessing_exploration/preprocessing_exploration_concat.sh' which concatenates all of the individual runs and makes a new feat. This only uses the sliced versions of the data.



