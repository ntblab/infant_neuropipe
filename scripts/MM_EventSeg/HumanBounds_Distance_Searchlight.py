# This script runs the analysis for finding the correlation between the distance to a behavioral boundary and the similarity of adjacent timepoints (run separately for each subject)
# V1 03162022 TSY 
# Simplify how we are calculating the distance 04222022 TSY

######################################################################################
########## Step 1: Import stuff
import warnings
warnings.filterwarnings('ignore') # so deprecation warnings do not fill up the log file 

# not all of these are used
from matplotlib import pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import matplotlib.patches as patches
import numpy as np
import pandas as pd
import itertools
import sys
import os
from brainiak.fcma.util import compute_correlation
import brainiak.funcalign.srm
from scipy import stats
from scipy.stats import pearsonr, mode
from sklearn import decomposition, preprocessing
from sklearn.model_selection import LeaveOneOut, RepeatedKFold
import nibabel as nib
from nilearn.input_data import NiftiMasker
from brainiak.searchlight.searchlight import Searchlight
import time 

# Now import our custom Event Seg code
import event_seg_edits.Event_Segmentation

# Load in MPI
from mpi4py import MPI

# Pull out the MPI information, make sure the rank is called rank
comm = MPI.COMM_WORLD
rank = comm.rank
size = comm.size

# The movie we have behavioral data from is Aeronaut
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
    
base_dir = base_dir = os.getcwd() +'/' # script is run from infant neuropipe root
roi_dir =  base_dir + 'data/EventSeg/ROIs/' 
movie_eventseg_dir =  base_dir + 'data/EventSeg/%s/' % movie
searchlight_dir = movie_eventseg_dir + 'eventseg_searchlights/'
optk_dir = movie_eventseg_dir + 'eventseg_optk/'
human_dir = movie_eventseg_dir + 'eventseg_human_bounds/'
save_plot_dir = movie_eventseg_dir+'plots/' 

######################################################################################
####### Step 1.5 - function to load in the behavioral event boundaries 
def gethumanbounds(nTRs):
    #'''Get the human-determined behavioral boundaries for this movie (already shifted and aligned to TRs) 
    #and return different forms of the data useful for running behavioral analyses'''
    
    # import the human labeled events
    humanlab_events_TR=np.load(movie_eventseg_dir+'behavioral_boundary_events.npy')
    num_events = (len(humanlab_events_TR[0])+1) #length of events

    # Create an array of length nTRs that tells you whether event is a human labeled event
    events_fullarray = []
    event_idx = humanlab_events_TR[0]
    for idx in range(num_events):
        if idx == 0:
            nums = np.repeat(idx,event_idx[idx])
        elif idx == len(humanlab_events_TR[0]):
            nums = np.repeat(len(humanlab_events_TR[0]),(nTRs - event_idx[idx-1]))
        else:
            nums = np.repeat(idx,(event_idx[idx] - event_idx[idx-1]))
        events_fullarray.extend(nums) 

    return humanlab_events_TR[0], events_fullarray

def getdistancebounds(nTRs):
    #''' Find the distance to the behavioral boundaries for adjacent timespoints '''
    behav_bounds,events_array=gethumanbounds(nTRs)

    event_dist_diag=np.zeros(len(events_array)-1) # preset

    # cycle through TRs
    for t in range(len(events_array)-1):

        # find the smallest distance to a behavioral boundary for adjacent TRs
        smallest_dist=np.min([np.min(abs(t-behav_bounds)),np.min(abs((t+1)-behav_bounds))])

        event_dist_diag[t]=smallest_dist
    
    return event_dist_diag

######################################################################################
####### Step 2 - load in the data

age=sys.argv[1] #which age group? adults, infants, (certain age infants?) or all of the above?
sub=sys.argv[2] #which subject in this group?
sub=int(sub)

# get brain mask
brain_nii=nib.load(movie_eventseg_dir+roi+'.nii.gz')
brain_masker=NiftiMasker(mask_img=brain_nii)
test_sub=nib.load(movie_eventseg_dir+roi+'.nii.gz') 
test_fit=brain_masker.fit(test_sub)
affine_mat = test_sub.affine
dimsize = test_sub.header.get_zooms()
coords= np.where(brain_nii.get_fdata())

# Get the boundary information
event_dist_diag = getdistancebounds(nTRs)

print("Loaded event data \n")

#preset
data=[]

#only load in the data on rank 0
if rank ==0:

    stacked_data=np.load(movie_eventseg_dir+age+'_wholebrain_data.npy')
    sub_data=stacked_data[:,:,sub] # get just this subject (speeds up the analyses a lot)
    
    data_4d=brain_masker.inverse_transform(sub_data)
    data.append(data_4d.get_fdata()) # needs to be a list though

else:
    data += [None]

print("Loaded participant %s %d \n" % (age,sub))

######################################################################################
####### Step 3 - set up the searchlight

mask=brain_nii.get_fdata()
data=data
sl_rad = 3
max_blk_edge = 5
pool_size = 1
bcvar=[event_dist_diag] # Give the distance to boundaries

# Create the searchlight object
sl = Searchlight(sl_rad=sl_rad,max_blk_edge=max_blk_edge)

# Distribute the information to the searchlights (note that data is already a list)
sl.distribute(data, mask)

sl.broadcast(bcvar)

######################################################################################
####### Step 4 - define kernel
def corr_timeshift_diagonal(data, event_dist_diag):
    
    # transpose the data
    sub_data = data.T
    
    # get the timepoint by timepoint correlation (for just adjacent times) for this subject
    pattern_sim_adjacent=np.array([np.corrcoef(sub_data[:,x],sub_data[:,x+1])[0,1] 
                                       for x in np.arange(sub_data.shape[1]-1)])
    
    # find the pearson correlation between sub data and distance to boundary (mask out any possible NaNs)
    mask=~np.isnan(event_dist_diag)*~np.isnan(pattern_sim_adjacent)
    corr,pval=stats.pearsonr(event_dist_diag[mask],pattern_sim_adjacent[mask])
   
    return corr

#What is the kernel?
def human_bound_kernel(data,sl_mask,myrad,bcvar):
    #'''Searchlight kernel that reshapes the data and decides whether there are enough voxels to run the algorithm'''
    
    event_dist_diag=bcvar[0] # so we know what we are doing - get the distance to event boundary
    
    # Make sure that we mask the data
    sl_mask_1d=sl_mask.reshape(sl_mask.shape[0] * sl_mask.shape[1] * sl_mask.shape[2]) # 1 dimensional sl mask
    
    #only run this operation if the number of brain voxels is greater than a certain amount
    if np.sum(sl_mask) >= 0:
        
        reshaped = data[0].reshape(sl_mask.shape[0] * sl_mask.shape[1] * sl_mask.shape[2], 
                                         data[0].shape[3]).T
        
        # Mask the data so that we only include data that is inside of the brain
        data=reshaped[:,sl_mask_1d==1]
           
        # Get the output
        output =  corr_timeshift_diagonal(data, event_dist_diag) 
        
    else:
        output=-1
        
    return output

######################################################################################
########## Step 4 - Run searchlight
print("Begin SearchLight in rank %s\n" % rank)
all_sl_result = sl.run_searchlight(human_bound_kernel,pool_size=pool_size)

print("End SearchLight in rank %s\n" % rank)

#save if on rank 0
if rank == 0:

    all_sl_result = all_sl_result.astype('double')
    all_sl_result[np.isnan(all_sl_result)] = 0

    # Save the results!!!
    output_name = '%s/%s_sub_%s_humanbounds_distance.nii.gz' %(human_dir,age,str(sub))
    sl_nii = nib.Nifti1Image(all_sl_result, affine_mat)
    hdr = sl_nii.header
    hdr.set_zooms((dimsize[0], dimsize[1], dimsize[2]))
    nib.save(sl_nii, output_name)  # Save

    print('Finished searchlight')
    
    
