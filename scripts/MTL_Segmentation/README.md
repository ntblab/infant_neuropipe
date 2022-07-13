# Analysis pipeline for MTL segmentation

This document outlines the analyses used in the manuscript titled "Automated and manual segmentation of the hippocampus in human infants," in which we assess how well manual segmentations of the infant hippocampus can be predicted from average templates and automated segmentations. Figures from the paper are generated in the jupyter notebook titled `scripts/MTL_Segmentation/MTL_Segmentation.ipynb`. The notebook uses files that are assumed to be stored in a folder called `data/MTL_Segmentations`. Analyses in the notebook can be replicated using these data (i.e., no other scripts need to be run if you have pulled this data). 

If you wish to run the notebook and reproduce the results from the paper, then the code here is sufficient. However, to generate new segmentations with our existing ASHS models or generate your own, you will need the ASHS software. For an overview, refer to this [website](https://sites.google.com/site/hipposubfields/building-an-atlas) written by the original creators of ASHS. 

The first step is to download the latest release of the [ASHS software package](https://github.com/pyushkevich/ashs/tree/fastashs), making sure to clone the fast-ashs package. We recommend this Github method, rather than alternatives, because this guarantees the latest version. We used the version from XX/XX/XX for the analyses reported here.

________________________________


## Code noteboook

The jupyter notebook titled `scripts/MTL_Segmentation/MTL_Segmentation.ipynb` contains all the code necessary to execute and recreate the results reported in the manuscript. The figures generated should be identical to the ones that appear in the paper, and as long as all the cells are run in order the statistics will be identical.

In order to run the script successfully, ensure that the *out_dir* file path is edited to point to the directory needed (i.e., the cloned neuropipe repo). Once *out_dir* is properly set up, then you should be able to run all cells, which consist of:

>1. Setup.

This portion of the notebook sets up the modules, defines the file paths containing the necessary data, stores segmentation file paths into appropriate variables, and defines every function.  

>2. Hippocampal Analyses.  

- Plot Hippocampal Segmentations  

    - Loads in each manual HPC segmentation and overlays them on the anatomical images for each participant (CE is in blue and JF is in purple)

- Hippocampal IRR

    - Calculates the Dice values between the 42 corresponding participants that CE and JF segmented, generating a hippocampal IRR metric

- Repeat Analysis 

    - Runs a repeat analysis, comparing segmentations from the same participant aligned both linearly and nonlinearly to standard space

- Average Template Hippocampal Analyses

    - Analyzes the performance of average infant anatomical templates, constructed via linearly and nonlinearly aligning infant data to standard space, along with an adult anatomical template in predicting the manual hippocampal data of the two raters

- FreeSurfer Hippocampal Analyses

    - Assess the ability of FreeSurfer to predict the manual infant segmentations from both tracers 

- ASHS Hippocampal Analyses

    - Analyses assessing (1) an ASHS model trained on segmenting the adult hippocampus from T1 scans (Adult-Pretrained-ASHS), which can be found [here](https://sites.google.com/view/ashs-dox/mri-data/ashs-pmc-t1-atlas-requirements?authuser=0); (2) an ASHS model trained on CE's infant hippocampal data (CE-ASHS); (3) an ASHS model trained on JF's infant hippocampal data (JF-ASHS); (4) an ASHS model trained on both CE and JF's infant hippocampal data (infant-trained-ASHS)

- Intersect Hippocampal Analyses

    - Determining the degree to which the segmentations generated from the three trained ASHS models matched an optimal representation of what was shared across tracers — an intersection of the manual segmentations from CE and JF
    
-  Bland-Altman Plots 

    - Generates the bias plots used to quantify the extent to which the volume of the hippocampus volume was over- or under-estimated by FreeSurfer and the trained ASHS models
    
>3. Supplementary Data

- Plot MTL Segmentations 

    - Loads in each manual MTL segmentation and overlays them on the anatomical images for each participant (CE is in blue and JF is in purple)
    
- MTL IRR

    - Calculates the Dice values between the 42 corresponding participants that CE and JF segmented, generating a MTL IRR metric
    
- Repeat vs Control Analysis
 
    - A fully-fleshed out version of the repeat analysis discussed above, in which we compare our repeat Dice values (HPC and MTL) acquired from both linearly and nonlinearly aligned participants with control Dice values
    
- Average Infant Template MTL Analysis

    - Analyzes the performance of an average infant anatomical template in predicting the manual MTL data of the two raters (no adult MTL data was made avaialble to us by Harvard-Oxford)
    
- ASHS MTL Analyses

    - Analyses assessing (1) an ASHS model trained on CE's infant MTL data (CE-ASHS); (3) an ASHS model trained on JF's infant MTL data (JF-ASHS); (4) an ASHS model trained on both CE and JF's infant MTL data (infant-trained-ASHS)

- LOPO-ASHS Hippocampal and MTL Analyses 

    - This code contains the set of analyses assessing how well models trained in a leave-one-participant-out (LOPO) fashion predict the HPC/MTL segmentations of the participant it did not see
    
- LOPO-ASHS Bland-Altman Plots 
    
    - Generates the bias plots used to quantify the extent to which the volume of the hippocampus was over- or under-estimated by the LOPO-ASHS models
________________________________


## Running an ASHS model

To run the model (i.e., have the ASHS pipeline segment a participant), run the command `scripts/MTL_Segmentation/run_ashs.sh`. This script wraps the *ashs_main.sh* function that is downloaded with fast-ashs. In addition to running this script, you must also supply a set of required options:

    -I provides the ID for the subject, which will be included in the output filenames
    -a points to the location of the atlas package. These can be one that we have already made, like `data/MTL_Segmentations/infant_trained_ASHS/`
    -g supplies the T1-weighted MRI scan
    -f supplies the T2-weighted MRI scan (our study emplopyed only T1-weighted scans and so this path was identical to the one prior)
    -w gives the working directory where the ASHS output will reside

Here is an example of what an sbatch command will look like:

> sbatch run_ashs.sh -I s0057_1_3 -a data/MTL_Segmentations/infant_trained_ASHS/ -g data/MTL_Segmentations/anatomicals_standard/s0057_1_3.nii.gz -f data/MTL_Segmentations/anatomicals_standard/s0057_1_3.nii.gz -w data/MTL_Segmentations/segmentations_infant_trained_ASHS/

________________________________

## Training an ASHS model

If you wish to train your own ASHS model, we provide code to support this, although feel free to follow the instructions on the ASHS website. For training ASHS, you will need to create the following files:

1. Data manifest file (required).

The data manifest file consists of a text file that describes the participant data used to build the ASHS model, with each row of text containing 5 entries, separated by spaces. The entries are:

> Subject ID (the participant names in our study) has the form sXXXX_Y_Z, where sXXXX describes the unique family ID, the \_Y that follows is the sibling ID, and the final \_Z is the session number)
> Path to T1-weighted MRI in NIFTI format
> Path to T2-weighted MRI in NIFTI format (our study emplopyed only T1-weighted scans and so this path was identical to the one prior) 
> Path to the Left MTL segmentation in NIFTI format
> Path to the Right MTL segmentation in NIFTI format

The script `scripts/MTL_Segmentation/training_ASHS_functions.py` contains four functions that we used to generate the manifest files needed to train an ASHS model in a leave-one-session out or leave-one-scan-out fashion. The first returns the sXXXX_X_X formatted name of the participant. The second takes a tracer's segmentation and divides it into "left_volume" and "right_volume" files. The third generates the manifest text files themselves needed to train ASHS with one tracer (e.g. CE-ASHS, JF-ASHS). The fourth generates the manifest files used for training ASHS with two tracers (e.g. Infant-Trained-ASHS). Take care to edit the file paths contained in this script to go to the desired directory. 

2. Label description file (required).

This text file is used to specify the names of the anatomical labels used in your protocol. To see the label description file employed in this current study, refer to `scripts/MTL_Segmentation/label_description_test.txt`.

3. Configuration file (optional).

This file allows a user to tune ASHS performance to his or her own data. While providing your own configuration file is not required when building an ASHS model, we made additional modifications to the ASHS configuration file (i.e., increasing the search iterations) to assist the pipeline and achieve successful template alignment. The particular config file we used can be found under `scripts/MTL_Segmentation/ashs_config.sh`, and our modifications are as follows:  

> ASHS_TSE_ISO_FACTOR=“100x100x100%”. This parameter refers to the resampling factor to make data isotropic. While the data does not have to be exactly isotropic, the original creators of ASHS suggest keeping all numbers multiples of 100.  

> ASHS_TEMPLATE_ITER=“120x40x0”. This parameter affects the number of iterations when registering ASHS_MPRAGE to the template and is the only whole-brain registration performed by ASHS.  

> ASHS_PAIRWISE_DEFORM_ITER=“120x120x40”. This parameter affects the number of Greedy iterations for running pairwise registration.  

> ASHS_PAIRWISE_T1_WEIGHT=0.0. This parameter marks the relative weight given to the T1 image in the pairwise registration. Setting this equal to 0 makes the registration only use the ASHS_TSE images. The original creators of ASHS recommend that this variable be set to a floating point number between 0 and 1.  

To train the model, run the command *ashs_train.sh*. The original creators of ASHS recommend writing a small bash script file that will run the command such that you can re-run *ashs_train.sh* later without having to retype all the parameters. Refer to `scripts/MTL_Segmentation/run_train_ashs.sh` for the script that we used. This script runs the program with the minimal set of required options:

    -D specifies the manifest file
    -L specifies the label description file
    -w gives the working directory where the model will be created

plus an additional option:

    -C gives the configuration file

to provide your own configuration. 

________________________________


## Miscellaneous

- `scripts/MTL_Segmentation/align_freesurfer.sh`: 

    - Aligns a hippocampal segmentation from FreeSurfer to native space

- `scripts/MTL_Segmentation/align_standard_ants.sh`:

    - Aligns a segmentations to nonlinear standard space using ANTs

- `scripts/MTL_Segmentation/proportion_voxels_shared_file_maker.py`: 

    - This code generates probabilistic atlases for linear and nonlinear segmentations, for every ROI, and from each tracer, by aggregating and averaging the binarized hippocampal segmentations from infant subjects (i.e., each voxel value reports the proportion of participants for whom that voxel was labeled as hippocampus). These atlases then are thresholded at a probability of 50% and binarized to create an average infant template. This was done in a leave-one-scan-out fasion such that, on each iteration, a given participant's data were "stripped" from the probabilistic atlas before the thresholding occurred. 

- `scripts/MTL_Segmentation/construct_intersects.py`: 

    - This code generates segmentations that are the intersection of the manual segmentations from the two tracers (i.e., segmentations that represent the voxels shared between tracers). These were considered "optimal" segmentations in the manuscript because every voxel in the intersection is by definition guaranteed to match between tracers, ensuring a maximally high IRR while still maintaining a high within-tracer reliability. 


