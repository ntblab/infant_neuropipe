# This code generates probabilistic atlases for linear and nonlinear segmentations, for every ROI, and from each tracer, by aggregating and averaging the binarized hippocampal segmentations from infant subjects (i.e., each voxel value reports the proportion of participants for whom that voxel was labeled as hippocampus). These atlases were then thresholded at a probability of 50% and binarized to create an average infant template. This was done in a leave-one-scan-out fasion such that, on each iteration, a given participant's data were "stripped" from the probabilistic atlas before the thresholding occurred.   

# NOTE: In order make this script work, edit the file path given below to go to the directory needed:

    #out_dir: The main path of the project directory (the cloned neuropipe repo)


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

# Setup some file paths
curr_dir = os.getcwd()
os.chdir('../../') # Move into the infant neuropipe root
base_dir = os.getcwd() + '/'
os.chdir(curr_dir) # Come back

out_dir = base_dir + '/data/MTL_Segmentations/'

# Path containing the segmentations of the participants in their native anatomical space.  
out_dir_segmentations_anatomical = '%s/segmentations_anatomical/' % out_dir

# Returns the name of the participant in the format of sXXXX_X_X
def participant_namer(file_path):
    
    # Index the beginning and end of the name
    start_index = file_path.find('nii.gz') - 13
    end_index = file_path.find('nii.gz') - 4
    
    # Generate the name
    participant = file_path[start_index:end_index] 

    return participant

# Collect the ages of the 42 participant scans to then order the participant files about to be made
ppt_ages = []
for ppt_name in ppt_names:
    index = np.where(df['hashed_name'] == ppt_name)[0][0]
    ppt_ages += [df['Age'][index]]

# Store the paths for CE's manual data in a list and order it by age 
files_segmentations_anatomical_CE = sorted(glob.glob(out_dir_segmentations_anatomical + '*CE.nii.gz'))
ordered_files_segmentations_anatomical_CE = np.asarray(files_segmentations_anatomical_CE)[np.argsort(ppt_ages)]

# Store the paths for JF's manual data in a list and order it by age 
files_segmentations_anatomical_JF = sorted(glob.glob(out_dir_segmentations_anatomical + '*JF.nii.gz'))
ordered_files_segmentations_anatomical_JF = np.asarray(files_segmentations_anatomical_JF)[np.argsort(ppt_ages)]


# In order to begin to make the average infant template, we need to make proportion files for the lMTL, rMTL, lHPC, and rHPC,    
def proportion_file_maker(ordered_files_segmentations_list, name, transformation):
    
    # 3 = lMTL; 4 = rMTL; 5 = lHPC; 6 = rHPC
    ROI_values = [3,4,5,6]
    
    # Loop through each of the 4 regions
    for ROI_value in ROI_values:
        
        # Make an empty shell in the size of the standardized volume
        vol_output = np.zeros((182,218,182),int)
        
        # Loop through the participant volumes
        for segmentation in ordered_files_segmentations_list:
            
            # Load in the data 
            vol=nib.load(segmentation).get_data()
            
            # Make all the labeled voxels equal to 1 
            vol_binarize = vol == ROI_value
            
            # Store this binarized volume in the shell; Accumulate for all 42 volumes per region
            vol_output += vol_binarize

        # Divide this volume by the number of segmentations to generate proportions for each voxel — out of X number of segmentations, how many have a given voxel labeled
        vol_output = vol_output/len(ordered_files_segmentations_list)
        nii = nib.Nifti1Image(vol_output, nib.load(segmentation).affine)
        
        # Store lMTL proportions
        if ROI_value == 3:
            file_name = out_dir + '/proportion_voxels_shared/%s_%s_proportion_voxels_shared_Left_MTL.nii.gz' % (name, transformation)
            nib.save(nii, file_name)
        
        # Store rMTL proportions
        if ROI_value == 4:
            file_name = out_dir + '/proportion_voxels_shared/%s_%s_proportion_voxels_shared_Right_MTL.nii.gz' % (name, transformation)
            nib.save(nii, file_name)
          
        # Store lHPC proportions
        if ROI_value == 5:
            file_name = out_dir + '/proportion_voxels_shared/%s_%s_proportion_voxels_shared_Left_HPC.nii.gz' % (name, transformation)
            nib.save(nii, file_name)
         
        # Store rHPC proportions
        if ROI_value == 6:
            file_name = out_dir + '/proportion_voxels_shared/%s_%s_proportion_voxels_shared_Right_HPC.nii.gz' % (name, transformation)
            nib.save(nii, file_name)
            
# Generate linear and nonlinear proportion files for both raters
proportion_file_maker(ordered_files_segmentations_linear_CE, 'CE', 'linear')
proportion_file_maker(ordered_files_segmentations_nonlinear_CE, 'CE', 'nonlinear')

proportion_file_maker(ordered_files_segmentations_linear_JF, 'JF', 'linear')
proportion_file_maker(ordered_files_segmentations_nonlinear_JF, 'JF', 'nonlinear')