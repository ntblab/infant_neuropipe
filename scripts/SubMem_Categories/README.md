# Analysis pipeline for subsequent memory

This document outlines the analyses used to study subsequent memory in infant participants. This assumes that all of the infant_neuropipe steps have been run and that all preprocessing has been completed. It also assumes that the GLM analyses (via FSL FEAT) have been run. Scipts to run this are located in `prototype/link/scripts/Subsequent_Memory_analyses`. 

Figures from the paper are generated in the jupyter notebook titled `scripts/SubMem_Categories/SubMem_Categories.ipynb`. The notebook uses files that have been stored on Dryad (link to come with published manuscript), and are assumed to be stored in a folder called `data/SubMem`. Analyses in the notebook can be replicated using these data (i.e., no other scripts need to be run if you have pulled this data). We also share more raw versions of the data on Dryad, which are not necessary for running these analyses, but could be informative. 
________________________________

If you decide to preprocess the raw data yourself, after you reach the end of the normal infant\_neuropipe procedures, you can then start the GLM analyses (including updating some of the timing files via the script `scripts/Subsequent_Memory_analyses/update_parametric_timing.py`) by running the following script from the participant folder:           
> `sbatch scripts/Subsequent_Memory_analyses/supervisor_subsequent_memory_categories.sh`

After this script finishes, copy the z-statistic files that have been registered to standard for each analysis (i.e., from the participant folder, this script will have created `zstat*_registered_standard.nii.gz` files located in `analysis/secondlevel_SubMem_Categories/default/SubMem_Categories_${analysis_type}_Z.feat/stats/`, where analysis_type is one of many different analyses you could run (e.g., "Task" or "Binary")) into the contrast maps folder in the data directory: `data/SubMem/contrast_maps`

Finally, if preprocessing the raw data, there are a few other things that are necessary to do before running the notebook:

1. Create an intersect mask with: `scripts/SubMem_Categories/generate_intersect_mask.sh`           
Takes as input an array of participant names, the analysis type (e.g., "Task"), and optionally a suffix for naming the mask (if for instance a subset of participants has been used). Creates the intersect mask across participants and stores it in `data/SubMem`.

2. Create ASHS hippocampal segmentations with: `scripts/SubMem_Categories/supervisor_run_ashs.sh`             
Takes as input an array of participant names, and runs an ASHS model to create automatic hippocampal and medial temporal lobe segmentations. Because ASHS takes up to a day to complete, this script should be run twice: once to initially submit the ASHS jobs, and then to threshold the outputs so that each ROI is stored in a separate and appropriately named nifti file. These ROIs are saved in the subject folder initially but then are transferred to `data/SubMem/segmentations` after running the script a second time (assuming ASHS has finished).

> NOTE: To create hippocampal segmentations, you will need to have downloaded the ASHS code base (v1.0.0) from [here](https://www.nitrc.org/projects/ashs/). You should also downloaded an appropriate ASHS model. We used the infant-trained ASHS model described in: Fel, J. T., Ellis, C. T., & Turk-Browne, N. B. (2023). Automated and manual segmentation of the hippocampus in human infants. *Developmental Cognitive Neuroscience, 60*, 101203. Please refer to the paper for training details and information about why this model is optimal for infant data. This infant-trained ASHS model is publicly available [here](https://datadryad.org/stash/dataset/doi:10.5061/dryad.05qfttf6z). Both the location of the ASHS code base (`ASHS_ROOT`) and the location of the infant-trained ASHS model (`ASHS_MODEL`) must be defined at the top of this script in order for it to run.

3. Create whole-brain randomise outputs with: `scripts/SubMem_Categories/run_randomise.sh`             
Takes as input an array of participant names, the analysis type (e.g., "Task" or "Binary"), the contrast number for the feat analysis (e.g., "1") and  optionally a suffix for naming the mask (if for instance a subset of participants has been used). First creates a (temporary) merged file with all of the participants that is then inputted to FSL's randomise. The outputs are the stored in `data/SubMem/randomise`.

