# Analysis pipeline for repetition narrowing

This document outlines the analyses used to study face processing in infant participants tested before and after the COVID-19 lockdowns. This assumes that all of the infant_neuropipe steps have been run and that all preprocessing has been completed. The scripts for preprocessing are located in `prototype/link/scripts/RepetitionNarrowing` with details in the README in that folder. 

Figures from the paper are generated in the jupyter notebook titled `scripts/RepetitionNarrowing/RepetitionNarrowing.ipynb`. The notebook uses files that have been stored on Dryad (link to come with published manuscript), and are assumed to be stored in a folder called `data/RepetitionNarrowing`. Analyses in the notebook can be replicated using these data (i.e., no other scripts need to be run if you have pulled this data). We also share more raw versions of the data on Dryad (link to come with published manuscript), which are not necessary for running these analyses, but could be informative. 
________________________________

If you decide to preprocess the raw data yourself, be sure to apply the GLM analysis types as input when running FunctionalSplitter. In other words, in the participant folder, after running Post-PreStats, you will need to run:                   
> `sbatch scripts/run_FunctionalSplitter.sh 'default' 'human_pairs'`            
> `sbatch scripts/run_FunctionalSplitter.sh 'default' 'sheep_pairs'`          
> `sbatch scripts/run_FunctionalSplitter.sh 'default' 'scene_face'`             

After you reach the end of the normal infant\_neuropipe procedures, you can then start the GLM analyses (including combining VPC and Star timing files via the script `scripts/RepetitionNarrowing_analyses/add_repnarrow_vpc_timing.m`) by running the following script from the participant folder:           
> `sbatch scripts/RepetitionNarrowing_analyses/supervisor_RepetitionNarrowing`

Finally, there are two scripts in the current folder that would be necessary before running the notebook:

1. `scripts/RepetitionNarrowing/generate_intersect_mask.sh`           
Takes as input an array of participant names, the analysis type (i.e., the secondlevel folder for a particular GLM analysis, likely "human\_pairs"), and optionally a suffix for naming the masks. Creates the intersect mask across participants and for each of the ROIs and stores them in `data/RepetitionNarrowing/ROIs`.

2. `scripts/RepetitionNarrowing/merge_leave_one_out_zstats.sh`             
Takes as input an array of participant names, the analysis type (i.e., the secondlevel folder for a particular GLM analysis, likely "scene\_face"), and the zstat number for the files you are combining (likely, "1" for the contrast of scene blocks > human novel blocks). Creates the merged zstat files for the leave-one-out fROI analysis and stores them in `data/RepetitionNarrowing/LOO_contrast_maps`.
