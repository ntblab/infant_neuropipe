# Predict retinotopy for held out participants
# An SRM model is first fit on all other participants with this movie, then the held out participants weights are learned
# The shared response for individual participants is used for the participants with retinotopy data to then transfer between the group to the individual
#
# To figure out if the loo is an infant or adult, we assume that infants start with 's'. Hence, this might not transfer to your use 
#
# You can also do a control analysis. The idea for the control analysis is that the fitting of the left out participant's data to SRM is jumbled so that the fit to the shared space is noise. The retinotopy data uses that fit so it should be bad too.
#
# To run this script, use run_SRM_predict_retinotopy.sh

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

is_infant_ref = int(sys.argv[3]) # Do you want to use adults for the reference for training the SRM and predicting the left out participant? If it is 1 then you will use infants, if it is 0, you will use adults

# What mask do you want to use (can be occipital or Wang)
if len(sys.argv) > 4:
    mask_type = sys.argv[4] 
else:
    mask_type = 'occipital'

# Do you want to do a control analysis in which you 
if len(sys.argv) > 5:
    is_control = int(sys.argv[5])
else:
    is_control = 0

TR = 2
n_iter = 20  # How many iterations of fitting will you perform
min_ppts = 5 # How many SRM participants is the minimum for inclusion
phases = 1 # What is the minimum number of phases per participant?

# Do you want to remove the confounds from the LOO participant from the SRM?
crop_confounds = 0 

# Do you want to save the data in highres (probably not since it will then be huge)
save_highres = 0 

# Does the participant name start with s? If so, assume the left out participant is an infant
if ID[0] == 's':
    loo_group = 'infant'
    is_infant_loo = 1
else:
    loo_group = 'adult'
    is_infant_loo = 0    

# Get the directory for the reference participants
if is_infant_ref == 1:
    ref_group = 'infant'
else:
    ref_group = 'adult'

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
ref_movies_short, movie_ref_dict = get_ppt_names(is_infant_ref, retinotopy_ppt_movies, SRM_movie_names)
loo_movies_short, movie_loo_dict = get_ppt_names(is_infant_loo, retinotopy_ppt_movies, SRM_movie_names)

# Make the directory that data will go in to
if os.path.exists(predict_dir + 'SRM_prediction/' + ID) == 0:
    os.mkdir(predict_dir + 'SRM_prediction/' + ID)

# What is the name for the control analysis to be stored
if is_control == 1:
    control_name = '_control'
    print('Doing a control analysis, so making junk files')
else:
    control_name = ''

print('\n\nTesting %s with %d features from %s for the %s mask' % (ID, features, ref_group, mask_type))
movies = loo_movies_short[ID]

for movie in movies:
    
    if movie in movie_ref_dict:

        # Get all the participants that saw this movie
        SRM_names = list(np.copy(movie_ref_dict[movie]))

        # Remove participant from the list you are using
        if is_infant_ref == is_infant_loo:
            SRM_names.remove(ID)

        print('Found %d %s for training SRM of %s' % (len(SRM_names), ref_group, movie))

        # Check there are enough participants
        if len(SRM_names) < min_ppts:
            print('Skipping because too few participants')
            continue

        # Get the data for the loo
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

        # Make the mask
        wholebrain_mask = loo_nii.get_data()[:, :, :, 0] != 0
        mask *= wholebrain_mask
        
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

        # Cycle through participants
        train_data = []
        ref_masks = []
        print('Cycling through participants')
        for ref_ppt in SRM_names:
            
            print('Using %s' % ref_ppt)
            
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
            
            # Mask the reference so that you can use it
            ref_mask *= wholebrain_mask
            
            # Get the preprocessed volume and the updated confound idxs
            ref_vol = preprocess_vol(ref_file_name, confound_idxs, mask=ref_mask, crop_confounds=crop_confounds)

            # Break the loop if this participant has a None
            if ref_vol is None:
                continue
    
            # Store this mask for later
            ref_masks += [ref_mask]
            
            # Store the SRM data
            train_data += [ref_vol]

        # Create the SRM object
        srm = SRM(n_iter=n_iter, features=features)

        # Fit SRM data to group
        srm.fit(train_data)

        # Get weights for left out participant
        if is_control == 0:
            loo_w = srm.transform_subject(loo_vol)
        else:
            
            # Flip the volume so that the weights that are learned are gibberish
            print('Flipping the time course so that the learned weights do not reflect the shared response')
            loo_vol = np.fliplr(loo_vol)
            
            loo_w = srm.transform_subject(loo_vol)

        # Now that you have a final list of participants who were included figure out which also had retinotopy
        # Which indexes in this list are names of participants with retinotopy
        retinotopy_ppts = np.intersect1d(list(ref_movies_short.keys()), SRM_names)
        print('Found %d participants with retinotopy' % (len(retinotopy_ppts)))

        retinotopy_idxs = []
        for retinotopy_ppt in retinotopy_ppts:
            retinotopy_idxs += [SRM_names.index(retinotopy_ppt)] # Add the indexes of the participants with retinotopy

        # Get the meridian and sf volume for the loo participant. You need to reshape it since this is in 1mm voxel size aligned to anatomical
        loo_meridian_nii = nib.load('%s/contrast_maps/%s_meridian_zstat3.nii.gz' % (retinotopy_dir, ID))
        loo_meridian_nii = processing.conform(loo_meridian_nii, out_shape=loo_nii.shape[:3], voxel_size=hdr.get_zooms()[:3])
        loo_meridian = loo_meridian_nii.get_data()
        
        loo_sf_nii = nib.load('%s/contrast_maps/%s_sf_zstat3.nii.gz' % (retinotopy_dir, ID))
        loo_sf_nii = processing.conform(loo_sf_nii, out_shape=loo_nii.shape[:3], voxel_size=hdr.get_zooms()[:3])
        loo_sf = loo_sf_nii.get_data()
        
        # Mask the volumes
        loo_meridian = loo_meridian[mask]
        loo_sf = loo_sf[mask]

        # Cycle through possible retinotopy participants to produce results
        meridian_s_all = np.zeros((features, )) # Preset
        sf_s_all = np.zeros((features, )) # Preset
        for retinotopy_idx in retinotopy_idxs:

            # Get the retinotopy data from an SRM participant
            retinotopy_ppt = SRM_names[retinotopy_idx]
            
            # Get the mask for these participants
            retinotopy_mask = ref_masks[retinotopy_idx]
            
            # Get the data in the appropriate shape
            meridian_nii = nib.load('%s/contrast_maps/%s_meridian_zstat3.nii.gz' % (retinotopy_dir, retinotopy_ppt))
            meridian_nii = processing.conform(meridian_nii, out_shape=retinotopy_mask.shape, voxel_size=hdr.get_zooms()[:3])
            meridian_vol = meridian_nii.get_data()
  
            sf_nii = nib.load('%s/contrast_maps/%s_sf_zstat3.nii.gz' % (retinotopy_dir, retinotopy_ppt))
            sf_nii = processing.conform(sf_nii, out_shape=retinotopy_mask.shape, voxel_size=hdr.get_zooms()[:3])
            sf_vol = sf_nii.get_data()
            
            meridian_vol = meridian_vol[retinotopy_mask]
            sf_vol = sf_vol[retinotopy_mask]

            # Get the weights for this transformation
            retinotopy_w = srm.w_[retinotopy_idx]

            # Convert the data to shared space
            meridian_s = retinotopy_w.T.dot(meridian_vol)
            sf_s = retinotopy_w.T.dot(sf_vol)

            # Store the shared responses for later
            meridian_s_all += meridian_s
            sf_s_all += sf_s

            # Use the loo weights to get a predicted meridian and sf volume
            pred_meridian_nii = convert_shared_to_nii(meridian_s, loo_w, mask, loo_nii)
            pred_sf_nii = convert_shared_to_nii(sf_s, loo_w, mask, loo_nii)

            # save niftis
            if save_highres == 1:
                pred_meridian_nii = processing.conform(pred_meridian_nii, out_shape=highres_nii.shape, voxel_size=hdr.get_zooms()[:3])

            nib.save(pred_meridian_nii, predict_dir + 'SRM_prediction/%s/meridian_f-%d_%s_%s_%s%s.nii.gz' % (ID, features, retinotopy_ppt, movie, mask_type, control_name))
            
            if save_highres == 1:
                pred_sf_nii = processing.conform(pred_sf_nii, out_shape=highres_nii.shape, voxel_size=hdr.get_zooms()[:3])
            
            nib.save(pred_sf_nii, predict_dir + 'SRM_prediction/%s/sf_f-%d_%s_%s_%s%s.nii.gz' % (ID, features, retinotopy_ppt, movie, mask_type, control_name))

            # Compute the correlation and save it to the output text file
            pred_meridian = loo_w.dot(meridian_s)
            pred_sf = loo_w.dot(sf_s)

            corr_meridian = np.corrcoef(loo_meridian, pred_meridian)[0, 1]
            corr_sf = np.corrcoef(loo_sf, pred_sf)[0, 1]

            # Save with the format: ref name first, loo name second
            fid_meridian = open('%s/SRM_prediction/predicting_meridian_f-%d_%s%s.txt' % (predict_dir, features, mask_type, control_name), 'a+')
            fid_sf = open('%s/SRM_prediction/predicting_sf_f-%d_%s%s.txt' % (predict_dir, features, mask_type, control_name), 'a+')
            fid_meridian.write('%s %s %s predicts %s: %0.3f\n' % (retinotopy_ppt, movie, ref_group, ID, corr_meridian))
            fid_sf.write('%s %s %s predicts %s: %0.3f\n' % (retinotopy_ppt, movie, ref_group, ID, corr_sf))
            fid_meridian.close()
            fid_sf.close()

        # Average the data (since before you were just summing)
        meridian_s_avg = meridian_s_all / len(retinotopy_idxs)
        sf_s_avg = sf_s_all / len(retinotopy_idxs)

        # Use the loo weights to get a predicted meridian and sf volume
        pred_meridian_nii = convert_shared_to_nii(meridian_s_avg, loo_w, mask, loo_nii)
        pred_sf_nii = convert_shared_to_nii(sf_s_avg, loo_w, mask, loo_nii)
        
        # Did you want to save the data in highres?
        if save_highres == 1:
            pred_meridian_nii = processing.conform(pred_meridian_nii, out_shape=highres_nii.shape, voxel_size=hdr.get_zooms()[:3])
        nib.save(pred_meridian_nii, predict_dir + 'SRM_prediction/%s/meridian_f-%d_%s_avg_%s_%s%s.nii.gz' % (ID, features, ref_group, movie, mask_type, control_name))
        
        if save_highres == 1:
            pred_sf_nii = processing.conform(pred_sf_nii, out_shape=highres_nii.shape, voxel_size=hdr.get_zooms()[:3])
        nib.save(pred_sf_nii, predict_dir + 'SRM_prediction/%s/sf_f-%d_%s_avg_%s_%s%s.nii.gz' % (ID, features, ref_group, movie, mask_type, control_name))    

        # Compute the correlation and save it to the output text file
        pred_meridian = loo_w.dot(meridian_s_avg)
        pred_sf = loo_w.dot(sf_s_avg)

        corr_meridian = np.corrcoef(loo_meridian, pred_meridian)[0, 1]
        corr_sf = np.corrcoef(loo_sf, pred_sf)[0, 1]

        # Save with the format: ref name first, loo name second
        fid_meridian = open('%s/SRM_prediction/predicting_meridian_f-%d_%s%s.txt' % (predict_dir, features, mask_type, control_name), 'a+')
        fid_sf = open('%s/SRM_prediction/predicting_sf_f-%d_%s%s.txt' % (predict_dir, features, mask_type, control_name), 'a+')
        fid_meridian.write('All %s %s predicts %s: %0.3f\n' % (movie, ref_group, ID, corr_meridian))
        fid_sf.write('All %s %s predicts %s: %0.3f\n' % (movie, ref_group, ID, corr_sf))
        fid_meridian.close()
        fid_sf.close()
    else:
        print('Zero %s in the reference group saw %s, skipping' % (ref_group, movie))
    
print('Finished')
