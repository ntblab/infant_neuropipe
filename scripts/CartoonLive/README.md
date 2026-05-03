## Analysis pipeline for realistic vs. cartoon movie-watching data data

This document outlines the analyses used to study neural synchrony and feature decoding in participants who watched cartoon and realistic ('live') versions of the same movie. This assumes that all of the infant_neuropipe steps have been run on the raw data. Additionally, it assumed that the following script was run in each subject folder to align the movie data to standard space: `sbatch ./scripts/CartoonLive_analyses/supervisor_CartoonLive.sh default CartoonLive-${movie}_ ${movie} ${ppt_name} ${ppt_out_name}`

Some analyses rely on functions for intersubject correlation, which are stored at `scripts/CartoonLive/modified_isc.py` This script is nearly identical to the intersubject correlation functions in Brainiak, with minor edits to deal with missing data in infant participants. See scripts for details.

Figures from the paper are generated in the jupyter notebook titled `scripts/CartoonLive/CartoonLive.ipynb` The notebook uses files that have been stored on Dryad, and are assumed to be stored in a folder called `data/Movies/${movie}`, with files common across movies (e.g., ROIs) stored in `data/CartoonLive/`. Analyses in the notebook can be replicated using these data (i.e., no other scripts need to be run if you have pulled this data).

Many analyses are run within the main notebook. However, some searchlight analyses and statistical tests (i.e., randomise) were run using scripts that were run on a high-performance computing cluster. These scripts include:

**Multivariate decoding scripts**

> Decode features of the movie (i.e., face presence/absence and scene distance) with `./scripts/CartoonLive/run_feature_decode_SL.sh $age $test_ppt $movie $feature` where $age is the age group you are looking at (e.g., infants), $test_ppt is the ID of the subject that will be left out for testing purposes, $movie is the movie shown (e.g., LionKing_Cartoon), and $feature is the type of feature you are decoding (e.g., faces). These are given as inputs to a python script called `Feature_Decoding_Searchlight.py` that actually runs the analysis.

**Group analysis scripts**

> Calculate whole-brain statistical significance maps by running FSL's randomise with `./scripts/CartoonLive/run_randomise_vs_chance.sh "${participants[@]}" $movie $analysis $suffix` where ${participants[@]}" is the list of participants you are considering, $analysis is the analysis name (e.g., temporal_isc, faces_decode_SL, scene_decode_SL), and $suffix is the suffix you want the output files to have (usually the age group, e.g., infants). If a decoding analysis is chosen, chance values are first subtracted from each voxel before the sign-flip test. 

> Calculate whole-brain statistical significance maps for differences between conditions by running FSL's randomise using `./scripts/CartoonLive/run_randomise_paired_diff.sh "${participants[@]}" $analysis $suffix` where ${participants[@]}" is the list of participants you are considering, $analysis is the analysis (e.g., temporal_isc, faces_decode_SL, scene_decode_SL), and $suffix is the suffix you want the output files to have (usually the age group, e.g., infants). Within participant, whole-brain maps are subtracted for the Realistic ("Live") minus the Cartoon condition. 

Other relevant files in this directory include:

> generate_intersect_mask.sh: a script that combines files from the data/Movies/${movie} folder to generate the intersect of all participants' brain masks

> contrast.con: a contrast file that is needed for running FSL's randomise as a sign flip test, such that the outputs will be the positive effect and the negative effect at the group level.

> CartoonLive_Regressors.csv: a CSV file that contains information about different features of the movie at each time point (hand-coded by one of the authors), which is used for the multivariate decoding analysis. The brain data are shifted to align to the timing in this file. 

> run_generate_VGG_weights.sh and generate_VGG_weights.py: scripts that run movie frames (from a .mp4 file) through a convolutional neural network (VGG-19) to look at representations at different network layers. Outputs .npy files for each layer with all unit values within the layer. This script requires a conda environment that includes Keras and TensorFlow.

> run_analyse_VGG_weights.sh and analyse_VGG_weights.py: scripts that take the outputs from the generate VGG script to create TR by TR correlation matrices that can be used for representational similarity analyses (as used in the paper). 

> CartoonLive_VisualFeatures_Complexity.ipynb: a Jupyter notebook that runs the supplemental analysis for examining the visual features of the movie, including visualizing representations and similarity metrics from VGG-19 and calculating complexity for color, shape, and motion. This is in a separate notebook from the main script because it requires a different conda environment setup (one that has access to openCV). 

