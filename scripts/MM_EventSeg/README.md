# Analysis pipeline for event segmentation

This document outlines the analyses used to study event segmentation in movie-watching participants. This assumes that all of the infant_neuropipe steps have been run and that all movie-watching preprocessing has been completed. The scripts for movie preprocessing are located in`prototype/link/scripts/MM_analyses` for the Aeronaut movie, and `prototype/link/scripts/PlayVideo_analyses` for the Mickey movie. 

Our analyses rely on functions for intersubject correlation and neural event segmentation modeling, which are stored in separate .py files in the folder `scripts/MM_EventSeg/event_seg_edits`. These scripts are nearly identical to the intersubject correlation and event segmentation functions in [Brainiak](https://brainiak.org/docs/), with minor edits to deal with missing data in infant participants.

Figures from the paper are generated in the jupyter notebook titled `scripts/MM_EventSeg/Event_Segmentation.py`. The notebook uses files that have been stored on Dryad (LINK), and are assumed to be stored in a folder called `data/EventSeg/${Movie_name}`. Analyses in the notebook can be replicated using these data (i.e., no other scripts need to be run if you have pulled this data). We also share more raw versions of the data on Dryad (LINK), which are not necessary for running these analyses, but could be informative. These files are assumed to be stored in a folder called `data/Movies/${Movie_name}`. Interested researchers may try different preprocessing steps before running the event segmentation analyses. If this is the case for you, you will need to save preprocessed data to the folder `data/Movies/${Movie_name}/preprocessed_standard/${preprocessing_name}`. You would then run `scripts/Movies/generate_intersect_mask.sh` with the inputs of the movie name (e.g., 'Aeronaut') and the preprocessing folder name to create a new whole-brain intersect mask. Finally, you would need to run the cells under the ''Create input data'' section of the notebook to create a numpy file of whole-brain subject data before running the scripts described below. 

Some analyses, including intersubject correlation, are run within the main notebook. However many of the analyses require extra computing resources and are run on a high-performance cluster. Below is a list of the bash scripts that should be run before the notebook will be able to load in the appropriate data for visualization (again, this is only necessary if you are not using the downloaded data from Dryad). It is advised that these scripts are run in the order that they are described.

*Inside the infant neuropipe project directory* 

**Whole brain Optimal K**
- `scripts/MM_EventSeg/run_findoptk_searchlight.sh`
    - Takes as input the movie name (e.g., 'Aeronaut'), age (e.g., 'adults'), and a K value (e.g., '2') to submit a slurm job that finds the optimal K for searchlights through the brain by running the script `scripts/MM_EventSeg/FindOptK_Searchlight.py`

**ROI Optimal K**
- `scripts/MM_EventSeg/run_findoptk_roi.sh`
    - Takes as input the movie name (e.g., 'Aeronaut'), age (e.g., 'adults'), roi (e.g., '`EVC_standard`'), and a number of events (e.g., '2') to submit a slurm job that fits an event segmentation model with K number of events and finds the log likelihood for that ROI and K value by running the script `scripts/MM_EventSeg/FindOptK_ROI.py`
    - By running this script on all possible event numbers you are considering (e.g., 2 through 22), you can find the most optimal number of events with functions inside the notebook
    - Takes as an optional 5th input a subject number (between 0 and the number of subjects minus 1) to hold completely out of the analysis -- this is for running the inner loop of the nested analysis
    
**Nested Results**  
- NOTE: Before the outer loop for a particular held out subject can be run, the inner loop for all possible numbers of events needs to have been completed. This means running the above script with the fourth input visiting each possible event number (e.g., 2 through 22) and the fifth input being for that held out subject
- `scripts/MM_EventSeg/run_findoptk_outerloop.sh`    
    - Takes as input the movie name (e.g., 'Aeronaut'), age (e.g., 'adults'), roi (e.g., 'V1_standard'), maximum number of events considered in the inner loop (e.g., '22'), and heldout subject number (e.g., '0') to submit a slurm job that finds the optimal K in the inner loop to test for reliability in the heldout subject by running the script `scripts/MM_EventSeg/FindOptK_Outer.py` This script will crash if the inner loops have not finished running for the held out subject you are testing. Make sure that the maximum number of events provided is consistent with what was inputted into the inner loop.

**Across Age Groups**
- NOTE: Before this analysis can be run, you need to have found the optimal number of events for every ROI (second step described in this list)
- `scripts/MM_EventSeg/run_across_group.sh`    
    - Takes as input the movie name (e.g., 'Aeronaut'), the age group whose optimal event structure is being used (e.g., 'adults'), and the age group who is being fit into this event structure (e.g., 'adults') to submit a slurm job that assesses the across-group fit by running the script `scripts/MM_EventSeg/Across_Groups_Analysis.py`

**Behavioral Boundaries**
- NOTE: These scripts require that behavioral boundaries were collected and saved to a file in the EventSeg data folder called `behavioral_boundary_events.py` This file is assumed to be a numpy array (or could be a list) consisting of the indexes for event boundaries in seconds (not TRs).
- `scripts/MM_EventSeg/run_humanbounds_searchlight.sh`    
    - Takes as input the age group being used (e.g., 'adults'), and the subject id (e.g., '0') to submit a slurm job that finds the fit of the behavioral boundaries in searchlights in the brain by running the script `scripts/MM_EventSeg/final_scripts/HumanBounds_Searchlight.py`
- `scripts/MM_EventSeg/run_humanbounds_bootstrapping.sh`    
     - Takes as input the age group being used (e.g., 'adults') and bootstraps the results found in the previous analysis by running the script `scripts/MM_EventSeg/HumanBounds_Bootstrapping.py` to determine regions that are significant








