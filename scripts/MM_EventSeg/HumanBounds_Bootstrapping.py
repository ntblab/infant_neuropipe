# Run bootstrapping to find the z-stats of the human bounds analysis to then be able to do cluster correction 

from brainiak import image, io
from scipy.stats import stats
import nibabel as nib
import numpy as np
import pandas as pd
import os
import sys
from nilearn.input_data import NiftiMasker, NiftiLabelsMasker
from nilearn import plotting
from scipy import stats
from scipy.stats import norm, zscore, pearsonr, spearmanr, mode
from scipy.signal import gaussian, convolve
import time
import glob

age=sys.argv[1] # which age group?

# The movie we are using is Aeronaut 
movie='Aeronaut'
print('Analysing %s' % movie)

# movie info
if movie == 'Aeronaut':
    nTRs=90
    nSubj=24
    roi = 'intersect_mask_standard_firstview_all' # get just the mask of the first view participants
elif movie == 'Mickey':
    nTRs=71
    nSubj=15
    roi = 'intersect_mask_standard_all'
    
base_dir = os.getcwd() +'/' # script is run from infant neuropipe root
roi_dir =  base_dir + 'data/EventSeg/ROIs/' 
movie_eventseg_dir =  base_dir + 'data/EventSeg/%s/' % movie
searchlight_dir = movie_eventseg_dir + 'eventseg_searchlights/'
optk_dir = movie_eventseg_dir + 'eventseg_optk/'
human_dir = movie_eventseg_dir + 'eventseg_human_bounds/'
save_plot_dir = movie_eventseg_dir+'plots/' 

# get brain mask
brain_nii=nib.load(movie_eventseg_dir+roi+'.nii.gz')
brain_masker=NiftiMasker(mask_img=brain_nii)
test_sub=nib.load(movie_eventseg_dir+roi+'.nii.gz') 
test_fit=brain_masker.fit(test_sub)
affine_mat = test_sub.affine
dimsize = test_sub.header.get_zooms()
coords= np.where(brain_nii.get_data())


# Get the data files created using the HumanBounds_Searchlight.py script 
file_location=human_dir+'/*%s*sub*bounds.nii.gz' % (age)
print(glob.glob(file_location))
data_files=glob.glob(file_location)

# Load the data
brain_data=[]
for file in data_files:
    nii=nib.load(file)
    data=brain_masker.fit_transform(nii)[0]
    brain_data.append(data)
    
brain_data=np.stack(brain_data)

# Calulate the zstat as the distance of the bootstrapped distribution from 0
nPerm=1000

z_scores=[]
for vox in range(brain_data.shape[1]):
    vox_dist=[]
    for perm in range(nPerm):
        sampidx=np.random.choice(np.arange(brain_data.shape[0]),brain_data.shape[0],replace=True)
        randomsamp=brain_data[sampidx,vox]
        mean=np.mean(randomsamp)
        vox_dist.append(mean)
            
    z=np.mean(vox_dist)/np.std(vox_dist) 
    z_scores.append(z)

z_nii=brain_masker.inverse_transform(np.array(z_scores))

# Save!! 
output_name=human_dir+'%s_avg_zscores.nii.gz' % age
nib.save(z_nii,output_name)
