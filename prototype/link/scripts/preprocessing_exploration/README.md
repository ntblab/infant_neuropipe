# Preprocessing parameter exploration code for individual participants

In this folder is the code for running the parameter exploration for a single participant. These analyses were central to the manuscript from the manuscript:

Ellis, Skalaban, Yates, Bejjanki, Cordova, & Turk-Browne (in prep). *How to read a baby's mind: Redesigning fMRI for awake, behaving infants*.

These analyses are premised on the idea that there should be a strong evoked response in visual regions when contrasting task with rest and that the pattern of activity evoked in visual regions by a stimulus should be consist across presentations.

## Script details

The main scripts that should be run in a sequence (can be run for multiple runs simultaneously):

`prep_raw_data_explore.sh`: Creates all of the files needed to explore the parameters specified
When running FEAT with the non-standard parameters (e.g. translational motion threshold equals 1mm) then you need to create the confound files that will make this possible. This script uses tools available from the `prep_raw_data.m` script to achieve this without overwriting the defaults.
Specifically this makes parameters for all combinations of the following motion thresholds: 0.5mm, 1mm, 3mm, 6mm and 12mm, as well as these zipper detection thresholds: p=0.05, IQR and none (this is a legacy algorithm that attempts to detect 'zipper' artefacts that come from intraframe motion. It is ). These values are described in the variables `fslmotion_thresholds` and `PCA_thresholds`, respectively. 

*Input/s*: functional run. e.g. `sbatch ./scripts/preprocessing_exploration/prep_raw_data_explore.sh 01`
*Output/s*: Confound files in $SUBJ_DIR/analysis/firstlevel/Confounds/ for different preprocessing parameters of a run

`preprocessing_exploration.sh`: Performs a FEAT analysis for all of the parameters specified.
For each different type of preprocessing setting (listed in the variable `analysis_types`) this performs a FEAT analysis. A set of default parameters are defined (starting in the section `Set the default values`) and each analysis changes parameters relative to those parameters. The `default` analyses are those with no parameters changed are reported in text as the chosen parameters. These parameters are then used to create fsf files with the appropriate parameters and then the FEAT analysis is run.  
For some parameters you can change the value with the provided functionality (e.g. smoothing could be changed to any value fsl recognizes) but for adding new types of parameter searches you might need to create a new if statement in the section starting `# Change the parameters`.
This performs the analysis two ways, it first runs the analysis with the data for a run or pseudorun as is and then second reruns it with a sliced version. The sliced data is created by `slice_data.m` which takes the timing file and creates new functional data, confound files and timing data for only the included blocks plus rest. This type of analysis is more equivalent to the way that analyses are ultimately run in the infant_neuropipe. Hence this is the analysis used as the default and is what is reported in the text.

*Input/s*: functional run e.g. `sbatch ./scripts/preprocessing_exploration/preprocessing_exploration.sh 01`
*Output/s*: FEAT directories for a run in $SUBJ_DIR/analysis/firstlevel/Exploration/preprocessing_exploration/, as well as timing files, fsf files and confound files in that same directory 

`preprocession_exploration_test.sh`: Report summary statistics of each run.
For each of the different preprocessing parameters in the previous analyses that were created for a run, compute the summary statistics.  The most important thing this script does is create the aligned to standard data so that you can do ROI analyses. This performs a number of steps that are now legacy (e.g. computing the SFNR of the data) but are included for reference. This also outputs the summarized data to a text file which is legacy because the jupyter notebook can do the masking and averaging step fast enough that you don't need to recreate all of the parameters like this script requires.

*Input/s*: functional run. e.g. `sbatch ./scripts/preprocessing_exploration/preprocessing_exploration.sh 01`
*Output/s*: Z statistic maps aligned to standard and text outputs summarizing the ROI analyses of a run

`preprocessing_exploration_concat.sh`: Aggregates the sliced functional data across runs and performs the specified analysis on it
This script aligns the sliced data for each run to anatomical space and performs z-scoring on the functional, then concatenates all runs. It then also combines the timing files and motion confounds. Next, an fsf file is created for this specific analysis type and the FEAT is run. Once this is run the FEAT is re-run using the z-scored data (necessary to prevent masking issues). Finally, the summary statistics for these FEATs is reported by masking it according to the specified masks
To run this on all runs, you *must* have finished running `preprocessing_exploration.sh` on these runs first.
By default, this will only run if the run has at least 2 included blocks (set in the variable `min_blocks`).

*Input/s*: analysis type e.g. `sbatch ./scripts/preprocessing_exploration/preprocessing_exploration_concat.sh default`
*Output/s*: FEAT directories in $SUBJ_DIR/analysis/firstlevel/Exploration/preprocessing_exploration/, as well as timing files, fsf files and confound files in that same directory
