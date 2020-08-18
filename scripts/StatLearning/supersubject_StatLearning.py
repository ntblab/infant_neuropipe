# Perform a supersubject analysis using the stat learning participants
# This script makes an iteration of a random shuffle in which blocks are sampled from individuals and used to make an average
# Use the script: scripts/StatLearning/run_supersubject_StatLearning.sh to run it from the command line

# Import (more than needed)
import nibabel as nib
import numpy as np
from scipy import stats
import scipy
from scipy.cluster.hierarchy import fcluster, linkage, dendrogram
from scipy.io import loadmat
import sys
import os
import nilearn.plotting
import scipy.spatial.distance as sp_distance
from scipy import stats, ndimage
from nilearn import datasets
from nilearn.input_data import NiftiMasker
import pandas as pd
import glob
from scipy.ndimage.morphology import binary_dilation
from pylab import *
import matplotlib.style
import matplotlib as mpl
import matplotlib.pyplot as plt
import matplotlib.image as mpimg
from matplotlib.colors import ListedColormap
import pandas as pd

# Get the input to determine the seed to use. If it is -1 then don't randomise
if len(sys.argv) > 1:
    input_seed = int(sys.argv[1])
else:
    input_seed = 0

# Get the participant condition if it is supplied    
if len(sys.argv) > 2:
    ppt_condition = sys.argv[2]
else:
    ppt_condition = '_all'  
    
# Do you want to get the anterior (1) or posterior (-1) ROI or all (0)
if len(sys.argv) > 3:
    posterior_anterior = int(sys.argv[3])
else:
    posterior_anterior = 0      
    
# Do you want to segment based on bilateral masks  (either 1 or 0)  
if len(sys.argv) > 4:
    bilateral_masks = int(sys.argv[4]) == 1
else:
    bilateral_masks = False
    
# Set the random seed based on the input value
if input_seed > -1:
    np.random.seed(input_seed)

    
# What is the first condition this participant saw?
def extract_first_condition(ppt, counterbalancing_condition):

    ppt_idx = np.where(df['ID'] == ppt)[0]
    
    first_condition = df['First condition'][ppt_idx]
    
    return first_condition

def segment_data(segmentation_name, functional_name, mask_name=None, bilateral_masks=False, posterior_anterior=0):
    # Segment the data using the segmentation in the mask directory and also mask this based on either the functional data or a supplied mask. This could be done easily if the masker code worked properly ( e.g. nilearn.input_data.NiftiLabelsMasker(labels_img=segmentation_name, mask_img = mask_name)) but it doesn't use mask_img
    # If bilateral_masks is true then it will collapse data for the left and right 
    functional = nib.load(functional_name).get_data()
    
    # Make 4d if necessary
    if len(functional.shape) == 3:
        functional = functional.reshape((functional.shape[0], functional.shape[1], functional.shape[2], 1))

    # If no mask name is specified then use the functional data for the mask
    if mask_name is None:

        #  Mask the data
        mask = abs(np.mean(functional, 3)) > 0
    else:
        mask = nib.load(mask_name).get_data()

    segmentation = nib.load(segmentation_name).get_data()

    # If there aren't 5 unique values (4 plus 0)
    if len(np.unique(segmentation)) != 5 and posterior_anterior == 0:
        raise ValueError('There is an incorrect number of unique values in the segmentation: %d' % len(np.unique(segmentation)))

    # Mask the segmentation according to the included functional data
    if mask.sum() > 0:
        segmentation *= mask == 1
    
    # If this is anterior then use these other ROIs, otherwise use the normal labels. This can be confusing but remember the labels for posterior sections of the hippocampus are labelled 5 and 6, and those are also the labels for the whole hippocampus
    if posterior_anterior == 1:
        roi_labels = [3, 4, 7, 8]
    else:
        roi_labels = [3, 4, 5, 6]
    
    # Preset    
    if bilateral_masks == False:
        masked_data = np.zeros((functional.shape[3], 4))    
        for mask_counter, mask_val in enumerate(roi_labels):
            
            # Make the mask of the segmentation
            masked_segmentation = segmentation == mask_val

            # Average all the voxels in the mask matching these values
            masked_data[:, mask_counter] = np.mean(functional[masked_segmentation], 0)
    else:
        # Preset
        masked_data = np.zeros((functional.shape[3], 2)) 
        
        # Combine the masks
        temp_MTL = ((segmentation == 3) + (segmentation == 4)) > 0
        temp_HPC = ((segmentation == roi_labels[2]) + (segmentation ==  roi_labels[3])) > 0

        # Average all the voxels in the mask matching these values
        masked_data[:, 0] = np.mean(functional[temp_MTL == 1], 0)
        masked_data[:, 1] = np.mean(functional[temp_HPC == 1], 0)
        
    # Return the masked data
    return masked_data


# Determine where the data is stored
base_dir = './infant_neuropipe'
data_dir = '%s/data/StatLearning/' % base_dir

# Use only the masks from this coder
Coder = 'CE'

# What blocks to use
counterbalancing_condition='seen_pairs'

# Load in the participant information
df = pd.read_csv('%s/participant_information-%s.csv' % (data_dir, counterbalancing_condition), delimiter='\t')    

# Set up the file name
if posterior_anterior == -1:
    posterior_anterior_name = '_posterior'
elif posterior_anterior == 1:
    posterior_anterior_name = '_anterior'
if posterior_anterior == 0:
    posterior_anterior_name = '' 
    
if bilateral_masks == True:
    bilateral_masks_name = '_bilateral'
    seg_num = 2
else:
    bilateral_masks_name = ''
    seg_num = 4

# What is the output name
if input_seed > -1:
    output_name = data_dir + 'supersubject_data-%s/output-%d%s%s%s.npy' % (counterbalancing_condition, input_seed, ppt_condition, bilateral_masks_name, posterior_anterior_name)
else:
    output_name = data_dir + 'supersubject_data-%s/true_results%s%s%s.npy' % (counterbalancing_condition, ppt_condition, bilateral_masks_name, posterior_anterior_name)

print('Making %s' % output_name)

# Use the secondlevel information to determine for each participant the runs and block onset times
# Currently this code conflates excluding a block with not seeing it which may or may not be valid
col_names = ['C1', 'C2', 'C3', 'C4', 'C5', 'C6']

# Specify which participants are included if there is a condition specified
if ppt_condition != '_all':
    
    # Get the participants based on condition name
    # Get the ppts that have some of both halves
    if ppt_condition == '_both_halves':
        # What participants have representation of data in blocks starting after the 4th seen one
        included_participants = df['ID']
    else:
        included_participants = df['ID']
        print('ppt condition name %s not recognized, using all participants' % ppt_condition)

# Randomly select participants, based on the seed (unless the seed is -1)
if input_seed > -1:
    rnd_ppts = np.random.choice(included_participants, len(included_participants))
else:
    print('Not randomizing')
    rnd_ppts = included_participants

summary_results = {}
for key in col_names:
    summary_results[key] = np.ones((len(rnd_ppts), seg_num)) * np.nan

print('Shuffled participants and now running:')
for ppt_counter, ppt in enumerate(rnd_ppts):
    
    print(ppt)
    
    # What segmentation are you going to use
    if posterior_anterior == 0:
        segmentation_name = glob.glob('%s/segmentations/%s-%s.nii.gz' % (data_dir, ppt, Coder))[0]
    else:
        # Load in the different segmentation for the head vs tail
        segmentation_name = glob.glob('%s/segmentations/%s-%s_head.nii.gz' % (data_dir, ppt, Coder))[0]

    # Cycle through the different run types
    for functional_run in range(1, 7):

        # Get the nifti you are using for this ppt
        nifti_name = '%s/block_regressors-%s/%s_contrast%d.nii.gz' % (data_dir, counterbalancing_condition, ppt, functional_run)

        # Segment the data    
        ppt_data = segment_data(segmentation_name, nifti_name, bilateral_masks=bilateral_masks, posterior_anterior=posterior_anterior)
        
        # Turn empty values in
        if np.any(abs(ppt_data) > 0):

            key = 'C%d' % (functional_run)
                
            # Store the data
            summary_results[key][ppt_counter, :] = ppt_data

# Save the data frame that was created
np.save(output_name, summary_results)

# Can be reloaded using: np.load(output_name).item()
    
print('Finished')
