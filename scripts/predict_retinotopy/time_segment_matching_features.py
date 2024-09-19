# Compute the time segment matching accuracy for each movie that the participant contributed
# An SRM model is first fit on all other participants with this movie, then the held out participants weights are learned
# Time segment matching is then performed
# This script assumes whether the ID provided is an infant or adult based on teh name
#
# To run this script, use run_time_segment_matching_features.sh

import nibabel as nib
import numpy as np
import sys
import os
from nilearn import plotting
from scipy import stats, ndimage
import pandas as pd
import glob
import brainiak
from brainiak.funcalign.srm import SRM
import matplotlib.style
import matplotlib as mpl
import matplotlib.pyplot as plt
import matplotlib.image as mpimg
from matplotlib.colors import ListedColormap
from utils import *

ID = sys.argv[1] # What is the participant you want to make

features = int(sys.argv[2]) # How many features will you fit?

is_infant_ref = int(sys.argv[3]) # If you want to use infants for training the SRM then set this to 1, if you want to use adults then set this to 0

# What mask do you want to use (can be occipital or Wang)
if len(sys.argv) > 4:
    mask_type = sys.argv[4] 
else:
    mask_type = 'occipital'

TR = 2
n_iter = 20  # How many iterations of fitting will you perform
min_ppts = 5 # How many SRM participants is the minimum for inclusion
buffer = 5 # How much buffer on either side of half are you using for training and testing the signal reconstruction
phases = 1 # What is the minimum number of phases per participant?
training_proportion = 0.5 # What proportion of data will you use for training
crop_confounds = 0 # Do you want to remove the confounds from the LOO participant from the SRM?

# Do you want to use SRM or just use the raw data? If features is set to -1 then it will use this
if features == -1:
    use_SRM = 0
else:
    use_SRM = 1
    
# Get the directory of the left out participant (the target; based on the name, assumed to start with 'sXXXX' and 'adult')
if ID[0] == 's':
    is_infant_loo = 1
    loo_group = 'infant'
else:
    is_infant_loo = 0
    loo_group = 'adult'

# Are the infants or adults held out
if is_infant_ref == 1:
    ref_group = 'infant'
else:
    ref_group = 'adult'
    
# Where do you want to put the output    
output_dir = predict_dir

# Store the output data in a text file
if use_SRM == 1:
    output_name = '%s/time_segment_matching/time_segment_matching_results_%s_f-%d.txt' % (output_dir, mask_type, features)
else:
    output_name = '%s/time_segment_matching/time_segment_matching_results_%s_raw.txt' % (output_dir, mask_type)
print('Outputting to %s' % output_name)

# Get the data frames
ref_df = pd.read_csv('%s/%s_participants.csv' % (predict_dir, ref_group))
loo_df = pd.read_csv('%s/%s_participants.csv' % (predict_dir, loo_group))

# For each participant, what movie did they see. Include the long version of this name
retinotopy_ppt_movies = {}

fid = open('%s/data/predict_retinotopy/retinotopy_ppts_movies.txt' % proj_dir)
line = fid.readline()
while len(line) > 0:
    # Get the movies the participants watched?
    splt_line = line.split('\t')
    retinotopy_ppt_movies[splt_line[0]] = splt_line[1:-1]
    line = fid.readline()
fid.close()

# Get the participants with movie data
loo_movies_short, movie_loo_dict = get_ppt_names(is_infant_loo, retinotopy_ppt_movies, SRM_movie_names)
ref_movies_short, movie_ref_dict = get_ppt_names(is_infant_ref, retinotopy_ppt_movies, SRM_movie_names)

print('\n\nTesting %s' % ID)

# What are the movies that this participant saw
movies = loo_movies_short[ID]

for movie in movies:
    
    if movie in movie_loo_dict:

        # Get all the participants that saw this movie in the reference group
        SRM_names = list(np.copy(movie_ref_dict[movie]))

        # Remove participant from the list you are using if they are in this list
        if is_infant_loo == is_infant_ref:
            SRM_names.remove(ID)

        print('Found %d %s for training SRM of %s' % (len(SRM_names), ref_group, movie))

        # Check there are enough participants
        if len(SRM_names) < min_ppts:
            print('Skipping because too few participants')
            continue

        # Get the data for the ref
        loo_ppt = '%s/%s/preprocessed_native/linear_alignment/%s_Z.nii.gz' % (movies_dir, movie, ID)
        loo_nii = nib.load(loo_ppt)
        
        # Get header, needed for later
        hdr = loo_nii.get_header()
        
        # Load the occipital mask for this participant.
        mask_name = '%s/masks/%s_%s.nii.gz' % (predict_dir, ID, mask_type)
        
        # Rescale the mask to be in the dimensions of the functional data
        mask_nii = nib.load(mask_name)
        highres_nii = nib.load(mask_name)
        mask_nii = processing.conform(mask_nii, out_shape=loo_nii.shape[:3], voxel_size=hdr.get_zooms()[:3])
        mask = mask_nii.get_data() > 0.5
        
        # Identify time points with motion
        confound_file = '%s/%s/motion_confounds/%s.txt' % (movies_dir, movie, ID)

        # Get the indexes of confounds
        confound_mat = np.loadtxt(confound_file)
        if len(confound_mat.shape) == 1:
            confound_idxs_orig = confound_mat == 1
        else:
            confound_idxs_orig = np.sum(confound_mat, 1) == 1

        # Get the preprocessed volume and the updated confound idxs
        loo_vol, confound_idxs = preprocess_vol(loo_ppt, confound_idxs_orig, mask=mask, return_confounds=1, crop_confounds=crop_confounds)

        # What is half the number of TRs available
        training_TR = int(loo_vol.shape[1] * training_proportion)
        print('Training size %d' % (training_TR - buffer))

        # Cycle through participants
        train_data = []
        test_data = []
        excluded_ppts = []
        ref_masks = []
        for ref_ppt in SRM_names:

            # Load data and exclude TRs that aren't useable
            ref_file_name = '%s/%s/preprocessed_native/linear_alignment/%s_Z.nii.gz' % (movies_dir, movie, ref_ppt)
            
            # Make the mask
            wholebrain_mask = nib.load(ref_file_name).get_data()[:, :, :, 0] != 0
            
            # Get the mask of the occ
            ref_mask_name = '%s/masks/%s_%s.nii.gz' % (predict_dir, ref_ppt, mask_type)
            ref_mask_nii = nib.load(ref_mask_name)
            
            # Reshape the mask so that it is the size of the functional data
            ref_mask_nii = processing.conform(ref_mask_nii, out_shape=wholebrain_mask.shape, voxel_size=hdr.get_zooms()[:3])
            ref_mask = ref_mask_nii.get_data() > 0.5
            
            # Mask the reference mask so that you can use it
            ref_mask *= wholebrain_mask
            
            # Get the preprocessed volume and the updated confound idxs
            ref_vol = preprocess_vol(ref_file_name, confound_idxs, mask=ref_mask, crop_confounds=crop_confounds)

            # Break the loop if this participant has a None
            if ref_vol is None:
                excluded_ppts += [ref_ppt]
                continue
    
            # Store this mask for later
            ref_masks += [ref_mask]
            
            # Store the SRM data
            train_data += [ref_vol[:, :training_TR - buffer]]
            test_data += [ref_vol[:, training_TR + buffer:]]

        # Remove the ppt from the list (do it after otherwise as you are iterating things get messed up)
        for excluded_ppt in excluded_ppts:
            SRM_names.remove(excluded_ppt)

        # Fit SRM data to group, learn the transform to participant data and then store the transform
        try:
            if use_SRM == 1:
                
                # Create the SRM object
                srm = SRM(n_iter=n_iter, features=features)
                
                print('Fitting SRM')
                srm.fit(train_data)

                # Get weights for reference participant
                loo_w = srm.transform_subject(loo_vol[:, :training_TR - buffer])

                # Now do time segment matching
                print('Now doing time segment matching')

                # Transform the data into shared space
                s_data_all = srm.transform(test_data)

                # Transform held out data into shared space
                s_loo = loo_w.T.dot(loo_vol[:, training_TR + buffer:])

                # Append the data (make the held out participant first
                ts_data = [s_loo] + s_data_all
            else:
                print('Not fitting SRM, using raw data')
                ts_data = [loo_vol[:, training_TR + buffer:]] + test_data
                
            # Do the time segment matching
            accu, chance, _ = time_segment_matching(ts_data, 0)

        except:
            # If it crashed (probably because too few TRs) then make this nan
            accu = np.nan
            chance = np.nan
    
        # Write the output of this function for each movie
        fid = open(output_name, "a") 
        fid.write('%s %s %s: %0.3f %0.3f\n' % (ID, ref_group, movie, accu, chance))
        fid.close()
    else:
        print('Zero %s in the left out group saw %s, skipping' % (ref_group, movie))

print('Finished')