# Set up utility functions for predicting retinotopy analyses

import nibabel as nib
from nibabel import processing
import numpy as np
import scipy
import sys
import os
from nilearn import plotting
from scipy import stats, ndimage
from scipy.io import loadmat
import pandas as pd
import glob
import brainiak
from brainiak.funcalign.srm import SRM
import matplotlib.style
import matplotlib as mpl
import matplotlib.pyplot as plt
import matplotlib.image as mpimg
from matplotlib.colors import ListedColormap

proj_dir = '/gpfs/milgram/project/turk-browne/projects/dev_neuropipe/'
Wang_atlas_dir = '/gpfs/milgram/project/turk-browne/shared_resources/atlases/ProbAtlas_v4/'

predict_dir = proj_dir + 'data/predict_retinotopy/'
plot_dir = predict_dir + 'plots/'
movies_dir = '%s/data/Movies/' % proj_dir
retinotopy_dir = '%s/data/Retinotopy/' % proj_dir

phases = 1 # What is the minimum number of phases per participant?
TR = 2 # WHat is the TR across participants

experiment_colors = {'Child_Play': 'r', 'Catepillar': 'g', 'Meerkats': 'b', 'Mouseforsale': 'm', 'Aeronaut': 'y'}
SRM_movie_names = list(experiment_colors.keys())

# Read in the Wang atlas
roi_file = '%s/ROIfiles_Labeling.txt' % Wang_atlas_dir 
Wang_rois = []
with open(roi_file, 'r') as fid:
    for line in fid:
        
        words = line.split()

        # Skip the first line
        if len(words) == 4:
            Wang_rois += [words[3]]
    
# How to convert the labels I used with the Wang atlas. 
# For manual2Wang, the keys are the names of the ROIs I defined and the number used for the label on the surface
# The codes are the ROI numbers for the Wang atlas. Relevant for both which ROI file to load and also for the max probability files
manual2Wang = {'vV1-1': [1], 'vV2-2': [3], 'vV3-3': [5], 'vV4-4': [7], 'dV1-5': [2], 'dV2-6': [4], 'dV3-7': [6], 'dV3AB-8': [16, 17]}
# For Wang2Manual, the pattern is reversed: what element of the Wang atlas (keys) corresponds to my retinotopy labels (keys)
Wang2manual = {'1': 1, '3': 2, '5': 3, '7': 4, '2': 5, '4': 6, '6': 7, '16': 8, '17': 8}

# Specify the naming convention based on whether you are using the ideal lines. This is used for file names
real_lines_name = ['ground_truth', 'ideal']

def load_1D(input_file, expected_length=198812):
    # Read in 1D or 1D.dset files into a numpy array. 
    # Will assume the data is in std.141 format so that everything is length 198812. The first column is assumed to be indexes. If they are not then the vector also has to be length 198812. 
    # Will ignore any # at the start and end
    # Can deal with sparse 1D files as well as dense ones
    # An ROI file can be converted into the appropriate format using 
    # `ROI2dataset -prefix $output -keep_separate -of 1D -input $input`

    # Load in the file ignoring comments
    vec = np.loadtxt(input_file, comments='#')
    
    # If the expected_length is set to -1 then you just return this vec anyway
    if expected_length == -1:

        return vec  
    
    # Check whether the first column already has all the indexes
    elif expected_length == len(np.unique(vec[:, 0])):

        # Just clip off this first column and go
        return vec[:, 1:]

    # If this isn't just a list of indexes but is the correct length, then also just go
    elif expected_length == vec.shape[0]:

        return vec

    # If neither of the above are true, assume this is a dense 1D file where the first column are indexes
    else:

        # What is the size of the output vector
        output_vec = np.zeros((expected_length, vec.shape[1] - 1))

        # input the data
        output_vec[vec[:,0].astype('int16'), :] = vec[:, 1:]

        return output_vec
    

# Load the roi file (this preserves the order posterior to anterior whereas other files don't).
# Each list entry includes values of all intervening nodes along a line
def load_roi(input_file):

    # Load the file
    fid = open(input_file, 'r')

    # Increment through each line
    line = fid.readline()
    trace_counter = 0
    while len(line) > 0:
        # Is this line the start of a new trace, if so then increment the counter
        if line == '# <Node_ROI\n':
            trace_counter += 1

            # If this is the first node then preset everything, otherwise append to the growing list
            if trace_counter == 1:
                trace_nodes_all = []
                trace_nodes = []
            else:
                trace_nodes_all += [trace_nodes]
                trace_nodes = []

        # Split the line into words
        words = line.split()

        # If this is a line with content then continue
        if (len(words) > 1) and (words[0] == '1'):

            # Some nodes are repeated and so this avoids that. Don't use unique because that reorders them
            if len(words) > 4:
                nodes = [int(i) for i in words[4:]] 
            else:
                nodes = [int(words[3])]

            trace_nodes += nodes

        # Read a new line
        line = fid.readline()
    
    fid.close()
    
    # Get the last set fir use
    trace_nodes_all += [trace_nodes]
    
    return trace_nodes_all


def partial_corr(x,y,covar):
    """
    Returns the sample linear partial correlation coefficients between pairs of variables in C, controlling
    for the remaining variables in C.
    """
    x = np.asarray(x)
    y = np.asarray(y)
    covar = np.asarray(covar)
    slope, intercept, r_value, p_value, std_err = stats.linregress(covar,x)
    resids_xcovar=x-(covar*slope+intercept)
    slope, intercept, r_value, p_value, std_err = stats.linregress(covar,y)
    resids_ycovar=y-(covar*slope+intercept)
    slope, intercept, r_value, p_value, std_err = stats.linregress(resids_ycovar,resids_xcovar)
    return r_value,p_value

# Compute stats
def randomise_corr(x_vals, y_vals, resample_num=10000, cov_vals=None):        
    
    # Check that the metrics aren't lists
    x_vals = np.asarray(x_vals)
    y_vals = np.asarray(y_vals)    
    
    # Resample the participants
    resample_corr = []
    for i in range(resample_num):

        # Determine what participants to use in the sample
        sub_idx = np.random.randint(0, len(x_vals), (1, len(x_vals)))
        
        if cov_vals is None:
            resample_corr += [np.corrcoef(x_vals[sub_idx], y_vals[sub_idx])[0, 1]]
        else:
            partial_corr_val, _ = partial_corr(x_vals[sub_idx], y_vals[sub_idx], cov_vals[sub_idx])
            resample_corr += [partial_corr_val]

    # Calculate the 2 way p value
    p_val = (1 - (np.sum(np.asarray(resample_corr) > 0) / (resample_num + 1))) * 2
    
    # If greater than 1 then subtract from 2
    if p_val > 1:
        p_val = 2 - p_val
    
    # return the corr p value
    return p_val


def randomise_diff(diff_data, resample_num=10000):        
    
    # Resample the participants
    resample_diff = []
    for i in range(resample_num):
        
        # Determine what participants to use in the sample
        sub_idx = np.random.randint(0, len(diff_data), (1, len(diff_data)))

        resample_diff += [np.mean(diff_data[sub_idx])]
    
    # What direction was the effect
    sign_count = np.sum((diff_data) > 0)
    
    # Calculate the 2 way p value
    p_val = (1 - ((np.sum(np.asarray(resample_diff) > 0) + 1) / (resample_num + 1))) * 2
    
    # If the value is greater than 1 then subtract 2
    if p_val > 1:
        p_val = 2 - p_val
    
    CIs =[np.percentile(resample_diff, 2.5), np.percentile(resample_diff, 97.5)]
    
    # return the difference in ROI and 
    return p_val, sign_count, CIs


def randomise_diff_2sample(data_1, data_2, resample_num=10000):        
    
    # Resample the participants
    resample_diff = []
    for i in range(resample_num):
        
        # Determine what participants to use in the sample
        sub_idx_1 = np.random.randint(0, len(data_1), (1, len(data_1)))
        
        sub_idx_2 = np.random.randint(0, len(data_2), (1, len(data_2)))

        resample_diff += [np.mean(data_1[sub_idx_1]) - np.mean(data_2[sub_idx_2])]
    
    # Calculate the 2 way p value
    p_val = (1 - ((np.sum(np.asarray(resample_diff) > 0) + 1) / (resample_num + 1))) * 2
    
    # If the value is greater than 1 then subtract 2
    if p_val > 1:
        p_val = 2 - p_val
    
    CIs =[np.percentile(resample_diff, 2.5), np.percentile(resample_diff, 97.5)]
    
    mean_diff = np.mean(data_1) - np.mean(data_2)
    
    # return the difference in ROI and 
    return p_val, mean_diff, CIs

def preprocess_vol(file_name, confound_idxs, mask=None, return_confounds=0, crop_confounds=1):
    # Take in a file name, timing file and list of confounds and produce a voxel by TR matrix that has only those TRs that are usable

    # Load the ppt and the mask
    vol = nib.load(file_name).get_data()
    
    # Make the mask if it wasn't already made
    if mask is None:
        mask = vol[:, :, :, 0] != 0
        
    vol = vol[mask, :]

    # How do you deal with errors where the lengths dont match?
    if vol.shape[1] != len(confound_idxs):

        print('Skipping %s' % file_name)
        return None
    
    # Exclude the time points
    if crop_confounds == 1:
        vol = vol[:, confound_idxs == 0]

    # Z score the volume
    vol = stats.zscore(vol, axis=1)

    # Convert NaNs
    if np.sum(np.isnan(vol)) > 0:
        print('Found %d nans' % np.sum(np.isnan(vol)))
        # Convert nans
        vol = np.nan_to_num(vol)
    
    # Return the volume and maybe the confounds
    if return_confounds == 1:
        return vol, confound_idxs
    else:
        return vol
    
    
def convert_shared_to_nii(vec_s, ref_w, ref_mask, ref_nii):
    # Take in a vector for a shared space and convert to a volume

    # Do the transformation from weights and shared to prediction
    pred_vec = ref_w.dot(vec_s)

    # Preset volume
    pred_vol = np.zeros(ref_mask.shape)

    # Insert vector values in
    pred_vol[ref_mask] = pred_vec

    # Make the nifti file
    pred_nii = nib.Nifti1Image(pred_vol.astype('float32'), ref_nii.affine)

    return pred_nii


def get_ppt_names(is_infant, retinotopy_ppt_movies_long, SRM_movie_names):
    # Get the movies that participants with retinotopy saw and also the other participants who didn't see movies

    # Pull out the movies seen for each participant that has retinotopy
    retinotopy_ppt_movies_short = {}
    for ppt in retinotopy_ppt_movies_long.keys():
        
        # Skip if this is not the group you are loooking for
        if is_infant == 1:
            if ppt[0] != 's':
                continue
        else:
            if ppt[0] == 's':
                continue
            
        long_movies = retinotopy_ppt_movies_long[ppt]
        
        # Count how many of each SRM movie there is for this participant
        movie_count = [0] * len(SRM_movie_names)
        for movie_counter, SRM_movie in enumerate(SRM_movie_names):
            for long_movie in long_movies:
                # If this word is included then increment counter. Also don't include if it is a Drop movie
                if (long_movie.find(SRM_movie) >= 0) and (long_movie.find('Drop') < 0):
                    movie_count[movie_counter] += 1
        
        # Store the abbreviated names
        retinotopy_ppt_movies_short[ppt] = list(np.asarray(SRM_movie_names)[np.asarray(movie_count) > 0])
        
    # Loop through the movies that you collected and the participants that saw the movie. Check that all of the data is usable. If so, add it to the list
    movie_ppt_dict = {}
    for movie in SRM_movie_names:

        # Preset the directory
        movie_ppt_dict[movie] = []

        file_paths = glob.glob('%s/%s/preprocessed_standard/nonlinear_alignment/*_Z.nii.gz' % (movies_dir, movie))

        for file_path in file_paths:

            ppt_name = file_path[file_path.find('alignment/') + 10:file_path.find('_Z')]
            
            # Check that it is the appropriate group of interest
            if ((is_infant == 1) and (ppt_name[0] == 's')) or ((is_infant == 0) and (ppt_name[0] != 's')):
                
                # Check if this participant finished the movie. If they didn't then don't include to avoid issues with SRM. This makes the code run slow unfortunately
                ppt_data = nib.load(file_path).get_data()
                if np.sum(np.abs(ppt_data[:, :, :, -1])) > 0:
                    movie_ppt_dict[movie] += [ppt_name]
                else:
                    print('Skipping %s because the movie was not finished' % ppt_name)

    # Return the data
    return retinotopy_ppt_movies_short, movie_ppt_dict
        



def time_segment_matching(data, # Load the data as a list of feature x time arrays
                          tst_subj, # Specify which list element you want to test on
                          win_size=10, # How big is the window for using to make the correlation
                          min_TR_per_win=5, # How many time points must be included in the window for it to be used.
                          verbose=1, # Do you want to output some description
                         ): 
    # Take in a list of participants of voxel by TR data. Also specify how big the time segment is to be matched
    # Code is based on Cameron Chen's original code from the SRM paper
    
    nsubjs = len(data)
    (ndim, nsample) = data[0].shape
    nseg = nsample - win_size 
    
    # mysseg prediction
    trn_data = np.zeros((ndim*win_size, nseg),order='f')
    
    # the training data also include the test data, but will be subtracted when calculating the average
    for m in range(nsubjs):
        for w in range(win_size):
            
            # Add the new data to the set, accounting for time points that are nan'd out
            trn_data[w*ndim:(w+1)*ndim,:] = np.nansum(np.dstack((trn_data[w*ndim:(w+1)*ndim,:], data[m][:,w:(w+nseg)])), 2)
            

    tst_data = np.zeros((ndim*win_size, nseg),order='f')
    for w in range(win_size):
        tst_data[w*ndim:(w+1)*ndim,:] = data[tst_subj][:,w:(w+nseg)]

    # Subtract the test from the training data (accounting for nans)
    temp_trn_data = np.nansum(np.dstack((trn_data, -1 * tst_data)), 2)

    # Get the z scored and non_nan'd data for analysis
    for seg in range(nseg):
        temp_trn_data[:, seg] = (temp_trn_data[:, seg] - np.nanmean(temp_trn_data[:, seg])) / np.nanstd(temp_trn_data[:, seg])
        tst_data[:, seg] = (tst_data[:, seg] - np.nanmean(tst_data[:, seg])) / np.nanstd(tst_data[:, seg])

    # Compute the correlation matrix and ignore nans (slow but accurate)
    corr_mtx = np.zeros((nseg, nseg))
    for seg_trn in range(nseg):
        for seg_tst in range(nseg):

            # What TRs are included
            included_idxs = (np.isnan(temp_trn_data[:, seg_trn]) == 0) * (np.isnan(tst_data[:, seg_tst]) == 0)

            # Determine whether there are enough TRs that are included
            if (included_idxs.sum() / ndim) >= min_TR_per_win:

                # Store the correlation value
                corr_mtx[seg_tst, seg_trn] = np.corrcoef(temp_trn_data[included_idxs, seg_trn], tst_data[included_idxs, seg_tst])[0, 1]
            else:
                corr_mtx[seg_tst, seg_trn] = -np.inf

    # Remove all time points that overlap with this time segment
    for i in range(nseg):
        for j in range(nseg):
            # exclude segments overlapping with the testing segment
            if abs(i-j)<win_size and i != j :
                corr_mtx[i,j] = -np.inf
                
    # What time points are the max fit
    max_idx =  np.argmax(corr_mtx, axis=1)
    
    # Count through each row and figure out whether they were correct and what chance. Ignore rows where there was no guess made due to exclusions
    accu = 0
    chance = 0
    included_segs = 0
    for i in range(nseg):
        
        # If this time point is not excluded then consider it for matching
        if corr_mtx[i, i] >= -1:
            accu += max_idx[i] == i
            chance += 1 / np.sum(corr_mtx[i, :] >= -1)
            included_segs += 1

    # Divide by the number of instances
    accu /= included_segs
    chance /= included_segs
    
    # Print accuracy
    if verbose == 1:
        print("Accuracy for subj %d is: %0.4f" % (tst_subj, accu))
    
    # Return relevant info
    return accu, chance, corr_mtx    



