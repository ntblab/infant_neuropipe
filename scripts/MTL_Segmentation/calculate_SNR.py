# This code calculates the signal-to-noise ratio (SNR) for each of our 42 anatomical scans as the mean intensity signal of hippocampal voxels on a centroid axial slice divided by the standard deviation of all non-brain voxels contained within that same slice 

# NOTE: This script will not run on its own because the file path for the highres anatomicals is not defined. These anatomcials necessarily contained face data so they could not be uploaded. 

import nibabel as nib
import numpy as np
from scipy import stats
import scipy
from scipy.io import loadmat
import sys
import os
import nilearn.plotting
import pandas as pd
import glob

# Setup some file paths
curr_dir = os.getcwd()
os.chdir('../../') # Move into the infant neuropipe root
base_dir = os.getcwd() + '/'
os.chdir(curr_dir) # Come back

out_dir = base_dir + '/data/MTL_Segmentations/'

def SNR_func(ppt):
    
    # Path for unmasked anatomical; 
    highres_nii_path = 'INSERT OWN PATH' # File path containing highres anatomical images

     # Path for masked anatomical containing non-brain voxels
    nonbrain_mask_nii_path = '%s/SNR_files/%s_brain.nii.gz' % (out_dir, ppt)

    # Load it in and get the data
    highres_nii = nib.load(highres_nii_path)
    img_data = highres_nii.get_fdata()

    # Load in mask
    brain_mask_nii = nib.load(brain_mask_nii_path)
    brain_mask = brain_mask_nii.get_fdata() == 0

    # Load in a hippocampal mask
    mask_nii = nib.load('%s/segmentations_anatomical/%s-CE.nii.gz' % (out_dir, ppt))

    # Where is the centroid of the r_HPC
    r_HPC_mask = mask_nii.get_fdata() == 6 

    # Get the coords for the centroid and extract it, as well as the center hpc slice
    np_coords = np.round(scipy.ndimage.measurements.center_of_mass(r_HPC_mask)).astype('int')

    centroid_slice_HPC = img_data[:, :, np_coords[2]]
    centroid_slice_nonbrain = img_data[:, :, np_coords[2]]

    centroid_hpc_slice = r_HPC_mask[:, :, np_coords[2]]
    centroid_brain_slice = brain_mask[:, :, np_coords[2]]

    hpc_voxels = centroid_slice_HPC[centroid_hpc_slice]
    nobrain_voxels = centroid_slice_nonbrain[centroid_brain_slice]

    # Calculate the mean and stdev. 
    hpc_mean = np.mean(hpc_voxels)

    stdev_nonbrain = stdev(nobrain_voxels)

    # Calculate SNR for this ppt 
    SNR = hpc_mean/stdev_nonbrain
    
    return SNR