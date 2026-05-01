# This script runs the analysis for decoding cartoon vs. live movie in searchlights across the brain 
# rather than a classification analysis, this uses pattern similarity a la Emberson 2017 PloS ONE
# 07212023 TSY 

######################################################################################
########## Step 1: Import stuff

import numpy as np
import pandas as pd
import sys
import os
from brainiak.searchlight.searchlight import Searchlight
from scipy import stats
import itertools
import nibabel as nib
from nilearn.input_data import NiftiMasker

# Now import our custom ISC code
from modified_isc import *

# Load in MPI
from mpi4py import MPI

# Pull out the MPI information, make sure the rank is called rank
comm = MPI.COMM_WORLD
rank = comm.rank
size = comm.size

age = sys.argv[1] # which age group? adults, infants, (certain age infants?) or all of the above?
test_ppt = sys.argv[2] # which subject is the held-out subject? 
movie = sys.argv[3] # which movie ?? (Cartoon or Live)
feature = sys.argv[4] # which feature? 

print("Running %s decoding analysis during %s on %s with %s as test" % (feature,movie,age,test_ppt))

# movie info
nTRs=90
tr_shift=2 # shift to align to the movie 
roi = 'intersect_mask_standard_LionKing_all' # temporary name of the mask we are going to use 
    
base_dir = os.getcwd() +'/' # script is run from infant neuropipe root
movie_dir =  base_dir+'data/Movies/LionKing_%s/' % movie # just put the results in the cartoon folder for now
output_dir = movie_dir + '%s_decode_SL/' % (feature)

######################################################################################
########## Step 2 - Load in the data

# get brain mask
brain_nii=nib.load(base_dir+'data/CartoonLive/ROIs/'+roi+'.nii.gz') 
brain_masker=NiftiMasker(mask_img=brain_nii)
test_fit=brain_masker.fit(brain_nii)
affine_mat = brain_nii.affine
dimsize = brain_nii.header.get_zooms()
coords= np.where(brain_nii.get_fdata())

# preset
data=[]
bcvar=[]

# Movie preprocessing functions 
def confound_TR_vec(confound_file, closed_file, vec_length, eye_shift=2):
    #''''Create a vector of TRs to be excluded for this half of the movie'''
    
    # "Load in the confound file and find the columns that have a value of 1 in them
    if confound_file is not '':
        confound_data = np.loadtxt(confound_file, unpack=False, dtype=float)
        confound_idxs = np.where(confound_data==1)[0]

        # Do you want to exclude epochs where their eyes are closed
        if closed_file is not '':

            # Load in the data                        
            closed_data = np.loadtxt(closed_file, delimiter=" ", unpack=False)
            
            # What TRs are excluded
            closed_eyes = np.where(closed_data==1)[0] + eye_shift # shift the eye tracking data
            
            # Update the confound idxs to be excluded
            confound_idxs = np.unique(np.append(confound_idxs, closed_eyes))
            
    else:
        confound_idxs = np.array([])

    # Preprocess the data
    if len(confound_idxs) > 0:

        # Bound the excluded TRs that are outside of the shape
        confound_idxs = confound_idxs[confound_idxs < vec_length]
        
        # Remove any that are under 0 for any reason
        confound_idxs = confound_idxs[confound_idxs >= 0]
        
    ppt_name = confound_file[confound_file.rfind('/') + 1:confound_file.rfind('.')]
    #print('%s has %d %% of TRs excluded' % (ppt_name,(len(confound_idxs)/nTRs)*100)) #, confound_idxs)
    
    return confound_idxs

def brain_2_vec(data, mask, confound_idxs=None):
    #'''Make a vector average from brain data'''
    # Take in data that is 4d and mask that is 4d. Confound idxs is a list of time points that are to be excluded
    
    # Pull out the data
    masked_data = data[mask == 1]
    masked_data = masked_data.reshape((int(mask.sum()), data.shape[3]))
    
    # Average the activity across voxels
    brain_vec = np.mean(masked_data, 0).flatten()
    
    # Turn the timepoints that aren't included into nan's
    if len(confound_idxs) > 0:
        brain_vec[confound_idxs] = np.nan
    
    # Return the vector map
    return brain_vec, masked_data

def preprocess_data(sub, movie_dir, nTRs=90):
    #'''Preprocess movie data by excluding TRs for motion and eye tracking, averaging across within-session viewings if desired'''
    sub_nifti = nib.load(movie_dir +'preprocessed_standard/nonlinear_alignment/' + sub + '_Z.nii.gz').get_fdata() 
    sub_motion_confound = movie_dir +'motion_confounds/' + sub + '.txt'
    sub_eye_confound = movie_dir +'eye_confounds/' + sub + '.txt'

    confound_idxs = confound_TR_vec(sub_motion_confound, sub_eye_confound, nTRs)

    # mask the data
    brain_vec, brain_masked = brain_2_vec(sub_nifti, brain_nii.get_fdata(), confound_idxs)

    brain_masked=brain_masked.T # transpose to be TR x vox
    brain_masked[np.isnan(brain_vec),:]=np.nan # fill nans as needed
    
    return brain_masked

# get the participant information
if age=='infants':
    df = pd.read_csv('%s/infant_participants.csv' % movie_dir)
else:
    df = pd.read_csv('%s/adult_participants.csv' % movie_dir)
         
        
# only load in the data on rank 0
if rank == 0:
    
    # first load the test subject we are analyzing
    data_2d=preprocess_data(test_ppt,'%s/data/Movies/LionKing_%s/' %(base_dir,movie)) # find timepoints to exclude (replace as NaN) for motion/gaze 
    data_2d=data_2d[tr_shift:nTRs+tr_shift] # shift data to the movie start time
    data_2d=stats.zscore(data_2d,axis=0,nan_policy='omit') # re-zscore

    # inverse transform into 4D data
    data_4d = brain_masker.inverse_transform(data_2d)

    # append
    data.append(data_4d.get_fdata())

    # Now load all of the participants who will form the group 
    # and average here so we don't have to deal with it later
    temp_data=[]
    for ppt in df.ppt:
        # remove the test participant though
        if ppt != test_ppt:
            # some minimal preprocessing 
            data_2d=preprocess_data(ppt,'%s/data/Movies/LionKing_%s/' %(base_dir,movie)) # find timepoints to exclude (replace as NaN) for motion/gaze
            data_2d=data_2d[tr_shift:nTRs+tr_shift] # shift data to the movie start time
            data_2d=stats.zscore(data_2d,axis=0,nan_policy='omit') # re-zscore

            # inverse transform into 4D data
            data_4d = brain_masker.inverse_transform(data_2d)

            # append
            temp_data.append(data_4d.get_fdata())
          
    # average and then add to the list 
    data.append(np.nanmean(temp_data,axis=0))
        
else:
    # make it length 2 because it is a list of: test subject and then average group 
    for i in np.arange(2):
        data += [None]

### Now get the feature information         
cartoonlive_regressors = pd.read_csv(base_dir+'data/CartoonLive/CartoonLive_Regressors.csv')
regressor = np.array(list(cartoonlive_regressors['%s - %s' % (feature.capitalize(),movie)]))       
        
######################################################################################
########## Step 3 - Set up the searchlight and kernel function 

mask = brain_nii.get_fdata()
sl_rad = 3
max_blk_edge = 5
pool_size = 1
bcvar = [feature,regressor]

# Create the searchlight object
sl = Searchlight(sl_rad=sl_rad,max_blk_edge=max_blk_edge)

# Distribute the information to the searchlights (note that data is already a list)
sl.distribute(data, mask)

# broadcast the feature information 
sl.broadcast(bcvar)

# Searchlight kernel for decoding
def decoding_kernel(data,sl_mask,myrad,bcvar):
    #'''Searchlight kernel that reshapes the data and decides whether there are enough voxels to run the algorithm'''

    # Make sure that we mask the data
    sl_mask_1d=sl_mask.reshape(sl_mask.shape[0] * sl_mask.shape[1] * sl_mask.shape[2]) # 1 dimensional sl mask
    
    # get the regressor ! 
    feature = bcvar[0]
    regressor = bcvar[1]
    
    # only run this operation if the number of brain voxels is greater than a certain amount
    if np.sum(sl_mask) >= 50: 
        
        # preset list of time by voxels
        data_reshaped=[]
    
        # transform data into an array of voxels
        for sub in range(len(data)):
            reshaped = data[sub].reshape(sl_mask.shape[0] * sl_mask.shape[1] * sl_mask.shape[2], 
                                         data[sub].shape[3]).T
            
            # Mask the data so that we only include data that is inside of the brain, if its on the edge
            reshaped=reshaped[:,sl_mask_1d==1]
            data_reshaped.append(reshaped)
        
        # get the values for the features 
        if feature == 'faces':
            
            # Get the average pattern of activity for this infant for the conditions
            con1_sub = data_reshaped[0][regressor=='Yes']
            con2_sub = data_reshaped[0][regressor=='No']

            # Get the average pattern of activity for all OTHER infant for the two movies 
            con1_group = data_reshaped[1][regressor=='Yes']
            con2_group = data_reshaped[1][regressor=='No']

            # run the analysis
            accuracy = mvpa_trial_decoding_avg(con1_sub,con1_group,con2_sub,con2_group)
        
        # get the values for the features 
        elif feature == 'scene':
            
            # Get the average pattern of activity for this infant for the conditions
            con1_sub = data_reshaped[0][regressor=='Close-up']
            con2_sub = data_reshaped[0][regressor=='Medium']
            con3_sub = data_reshaped[0][regressor=='Far']

            # Get the average pattern of activity for all OTHER infant for the two movies 
            con1_group = data_reshaped[1][regressor=='Close-up']
            con2_group = data_reshaped[1][regressor=='Medium']
            con3_group = data_reshaped[1][regressor=='Far']

            # run the analysis
            accuracy = mvpa_trial_decoding_3way_avg(con1_sub,con1_group,con2_sub,con2_group,con3_sub,con3_group)
    else:
        # if too few voxels, return -1 
        accuracy = -1
        
    return accuracy

def mvpa_trial_decoding_avg(con1_sub,con1_group,con2_sub,con2_group):
    #'''Function that uses pattern similarity to decode whether a given patttern of activity from an individual is more similar to the same condition from the group or the other condition'''
    
    # find the correlation between the correct vs. incorrect labels for condition 1 
    # NOTE: This assumes that the TRs are aligned across participants AND of equal length; these assumption are met in our data
    con1_con1_corr = [np.arctanh(np.corrcoef(con1_sub[tr],np.nanmean(con1_group,axis=0))[0,1]) # match TR 
                      for tr in np.arange(len(con1_sub))]
    
    con1_con2_corr = [np.arctanh(np.corrcoef(con1_sub[tr],np.nanmean(con2_group,axis=0))[0,1]) # match TR 
                      for tr in np.arange(len(con1_sub))]
    
    # Find binary accuracy for condition 1                      
    not_nans = (~np.isnan(con1_con1_corr)*~np.isnan(con1_con2_corr))
    con1_correct = np.array(con1_con1_corr)[not_nans] > np.array(con1_con2_corr)[not_nans]
    
    # find the correlation between the correct labels for condition 2
    con2_con2_corr = [np.arctanh(np.corrcoef(con2_sub[tr],np.nanmean(con2_group,axis=0))[0,1]) # match TR 
                      for tr in np.arange(len(con2_sub))]
    
    con2_con1_corr = [np.arctanh(np.corrcoef(con2_sub[tr],np.nanmean(con1_group,axis=0))[0,1]) # match TR 
                      for tr in np.arange(len(con2_sub))]
    
    # Find binary accuracy for condition 1         
    not_nans = (~np.isnan(con2_con2_corr)*~np.isnan(con2_con1_corr))
    con2_correct = np.array(con2_con2_corr)[not_nans] > np.array(con2_con1_corr)[not_nans]
    
    # combine them                     
    sub_decoding = np.hstack((con1_correct,con2_correct))

    return np.mean(sub_decoding)
def mvpa_trial_decoding_3way_avg(con1_sub,con1_group,con2_sub,con2_group,con3_sub,con3_group):
    '''Function that uses pattern similarity to decode whether a given patttern of activity from an individual is more similar to the same condition from the group or the other condition'''
    
    #find the correlation between the correct vs. incorrect labels for condition 1 
    # NOTE: This assumes that the TRs are aligned across participants AND of equal length; these assumption are met in our data
    con1_con1_corr = [np.arctanh(np.corrcoef(con1_sub[tr],np.nanmean(con1_group,axis=0))[0,1]) # match TR 
                      for tr in np.arange(len(con1_sub))]
    
    con1_con2_corr = [np.arctanh(np.corrcoef(con1_sub[tr],np.nanmean(con2_group,axis=0))[0,1]) # match TR 
                      for tr in np.arange(len(con1_sub))]
    
    con1_con3_corr = [np.arctanh(np.corrcoef(con1_sub[tr],np.nanmean(con3_group,axis=0))[0,1]) # match TR 
                      for tr in np.arange(len(con1_sub))]
    
    # Find binary accuracy for condition 1                      
    not_nans = (~np.isnan(con1_con1_corr)*~np.isnan(con1_con2_corr)*~np.isnan(con1_con3_corr))
    con1_correct = (np.array(con1_con1_corr)[not_nans] > 
                    np.array(con1_con2_corr)[not_nans])*(np.array(con1_con1_corr)[not_nans] 
                                                         > np.array(con1_con3_corr)[not_nans])
    
    # find the correlation between the correct labels for condition 2
    con2_con2_corr = [np.arctanh(np.corrcoef(con2_sub[tr],np.nanmean(con2_group,axis=0))[0,1]) # match TR 
                      for tr in np.arange(len(con2_sub))]
    
    con2_con1_corr = [np.arctanh(np.corrcoef(con2_sub[tr],np.nanmean(con1_group,axis=0))[0,1]) # match TR 
                      for tr in np.arange(len(con2_sub))]
    con2_con3_corr = [np.arctanh(np.corrcoef(con2_sub[tr],np.nanmean(con3_group,axis=0))[0,1]) # match TR 
                      for tr in np.arange(len(con2_sub))]
        
    # Find binary accuracy for condition 2                     
    not_nans = (~np.isnan(con2_con2_corr)*~np.isnan(con2_con1_corr)*~np.isnan(con2_con3_corr))
    con2_correct = (np.array(con2_con2_corr)[not_nans] > 
                    np.array(con2_con1_corr)[not_nans])*(np.array(con2_con2_corr)[not_nans] > 
                    np.array(con2_con3_corr)[not_nans])
    
    # find the correlation between the correct labels for condition 3
    con3_con3_corr = [np.arctanh(np.corrcoef(con3_sub[tr],np.nanmean(con3_group,axis=0))[0,1]) # match TR 
                      for tr in np.arange(len(con3_sub))]
    con3_con1_corr = [np.arctanh(np.corrcoef(con3_sub[tr],np.nanmean(con1_group,axis=0))[0,1]) # match TR 
                      for tr in np.arange(len(con3_sub))]
    con3_con2_corr = [np.arctanh(np.corrcoef(con3_sub[tr],np.nanmean(con2_group,axis=0))[0,1]) # match TR 
                      for tr in np.arange(len(con3_sub))]
    
    # Find binary accuracy for condition 3             
    not_nans = (~np.isnan(con3_con3_corr)*~np.isnan(con3_con1_corr)*~np.isnan(con3_con2_corr))
    con3_correct = (np.array(con3_con3_corr)[not_nans] > 
                    np.array(con3_con1_corr)[not_nans])*(np.array(con3_con3_corr)[not_nans] > 
                    np.array(con3_con2_corr)[not_nans])
    
    # combine them                     
    sub_decoding = np.hstack((con1_correct,con2_correct,con3_correct))

    return np.mean(sub_decoding)
######################################################################################
########## Step 4 - Run searchlight
print("Begin Searchlight in rank %s\n" % rank)

all_sl_result = sl.run_searchlight(decoding_kernel,pool_size=pool_size)
    
print("End Searchlight in rank %s\n" % rank)

######################################################################################
########## Step 5 - Save out the data

# save the data if on rank 0
if rank == 0:
    
    coords = np.where(mask)
    
    all_sl_result = all_sl_result[mask==1]
    
    # reshape
    result_vol = np.zeros((mask.shape[0], mask.shape[1], mask.shape[2]))  
    result_vol[coords[0], coords[1], coords[2]] = all_sl_result   
            
    # Convert the output into what can be used
    result_vol = result_vol.astype('double')
    result_vol[np.isnan(result_vol)] = 0  # If there are nans we want this
    
    # Save the average result
    output_name='%s/%s_decode_movie.nii.gz' % (output_dir,test_ppt)
    
    sl_nii = nib.Nifti1Image(result_vol, affine_mat)
    hdr = sl_nii.header
    hdr.set_zooms((dimsize[0], dimsize[1], dimsize[2]))
    nib.save(sl_nii, output_name)  # Save    

    print('Finished searchlight')
