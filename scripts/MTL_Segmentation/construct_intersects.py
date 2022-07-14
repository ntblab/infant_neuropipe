# This code generates segmentations that are the intersection of the manual segmentations from CE and JF (i.e., segmentations that represent the voxels shared between tracers). These were considered "optimal" segmentations in the manuscript because every voxel in the intersection is by definition guaranteed to match between tracers, ensuring a maximally high IRR while still maintaining a high within-tracer reliability.    

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

# Path containing the segmentations of the participants in standard space.  
out_dir_segmentations_anatomical = '%s/segmentations_nonlinear/' % out_dir

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

# Contruct intersect segmentations by looping through CE and JF's data
for CE_segmentation, JF_segmentation in zip(ordered_files_segmentations_anatomical_CE, ordered_files_segmentations_anatomical_JF):
    
    # Obtain the participant name 
    ppt_name = participant_namer(CE_segmentation)
    
    # Load in the data for each tracer
    vol_CE = nib.load(CE_segmentation).get_data()
    vol_JF = nib.load(JF_segmentation).get_data()
    
    # Set the shape of the intersect file equal to anatomical shape of one of the tracer's files
    vol_shared = np.zeros(vol_CE.shape)
    
    # Make a mask containing only the voxels shared between the two tracers
    vol_mask = vol_CE == vol_JF
    
    # Use the mask to set voxels in the intersect file equal to the values of only the shared intersect voxels  
    vol_shared[vol_mask] = vol_CE[vol_mask]
    
    # Save these data in a file
    nii = nib.Nifti1Image(vol_shared, nib.load(CE_segmentation).affine)
    file_name = '%s/segmentations_intersect/%s_intersect.nii.gz'%(out_dir, ppt_name)
    nib.save(nii, file_name)
