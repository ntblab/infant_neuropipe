# This script runs the analysis for finding the log likelihood for held out data for a given K value in searchlights across the brain 
# V1 01202020 TSY 

######################################################################################
########## Step 1: Import stuff

# not all of these are used
from matplotlib import pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import matplotlib.patches as patches
import numpy as np
import pandas as pd
import sys
import os
from brainiak.fcma.util import compute_correlation
import brainiak.funcalign.srm
from brainiak.searchlight.searchlight import Searchlight
from scipy import stats
from scipy.stats import pearsonr, mode
from sklearn import decomposition, preprocessing
from sklearn.model_selection import LeaveOneOut, RepeatedKFold
import itertools
import nibabel as nib
from nilearn.input_data import NiftiMasker

# Now import our custom Event Seg code
import event_seg_edits.Event_Segmentation

# Load in MPI
from mpi4py import MPI

# Pull out the MPI information, make sure the rank is called rank
comm = MPI.COMM_WORLD
rank = comm.rank
size = comm.size

movie=sys.argv[1]
print('Analysing %s' % movie)

# movie info
if movie == 'Aeronaut':
    nTRs=90
    nSubj=24
    roi = 'intersect_mask_standard_firstview_all' #'intersect_mask_standard_nonlinear_all' # get just the mask of the first view participants
elif movie == 'Mickey':
    nTRs=71
    nSubj=15
    roi = 'intersect_mask_standard_all'
    
base_dir = os.getcwd() +'/' # script is run from infant neuropipe root
roi_dir =  base_dir + 'data/EventSeg/ROIs/' 
movie_eventseg_dir =  base_dir + 'data/EventSeg/%s/' % movie
searchlight_dir = movie_eventseg_dir + 'eventseg_searchlights/' #'eventseg_searchlights_nonlinear/'
optk_dir = movie_eventseg_dir +'eventseg_optk/'
human_dir = movie_eventseg_dir + 'eventseg_human_bounds/'
save_plot_dir = movie_eventseg_dir+'plots/' 


######################################################################################
########## Step 2 - Load in the data

age=sys.argv[2] #which age group? adults, infants, (certain age infants?) or all of the above?
num_events=sys.argv[3]  #how many events are we trying?

loglik_split = 2 # do a split half analysis

print("Running event segmentation with %s events on %s" % (num_events,age))

# get brain mask
brain_nii=nib.load(movie_eventseg_dir+roi+'.nii.gz')
brain_masker=NiftiMasker(mask_img=brain_nii)
test_sub=nib.load(movie_eventseg_dir+roi+'.nii.gz') 
test_fit=brain_masker.fit(test_sub)
affine_mat = test_sub.affine
dimsize = test_sub.header.get_zooms()
coords= np.where(brain_nii.get_data())

# preset
data=[]
bcvar=[]

# only load in the data on rank 0
if rank ==0:
    
    stacked_data=np.load(movie_eventseg_dir+age+'_wholebrain_data.npy') # '_wholebrain_data_nonlinear.npy')
    
    #Now put them in a 4d output
    for sub in range(stacked_data.shape[2]):
        
        data_4d=brain_masker.inverse_transform(stacked_data[:,:,sub])
        data.append(data_4d.get_data())
else:
     for sub in range(nSubj):
        data += [None]

######################################################################################
########## Step 3 - Set up the searchlight

mask=brain_nii.get_data()
data=data
sl_rad = 3
max_blk_edge = 5
pool_size = 1
bcvar=[np.int(num_events),loglik_split] # Give the number of events and the log likelihood choice

# Create the searchlight object
sl = Searchlight(sl_rad=sl_rad,max_blk_edge=max_blk_edge)

# Distribute the information to the searchlights (note that data is already a list)
sl.distribute(data, mask)

sl.broadcast(bcvar)


######################################################################################
########## Step 4 - Define kernel

# Inner loop that will find the mean log likelihood for this n value
def innerloop_ll(data_viewing_averaged,n,split):
    #'''Fit and test an event segmentation model with a given K value on split halves of a set of data
    #Returns the average and all log-likelihoods across different iterations'''
    stacked_data=np.stack(data_viewing_averaged)
    
    # preset
    all_test_lls = []
    
    # preset
    subjects_with_data_train=np.zeros(nTRs)
    subjects_with_data_test=np.zeros(nTRs)
    
    # what split are you doing?
    sp=np.int(split)
    kf = RepeatedKFold(sp,len(data)//sp)

    # run several iterations of the analysis
    for train_k, test_k in kf.split(stacked_data):
        
        # iterate through time points and figure out how many subjects have data at that time point
        for timepoint in range(stacked_data.shape[1]):

            # just use the first voxel
            subjects_with_data_train[timepoint]=stacked_data[train_k,:,:].shape[0]-sum(np.isnan(stacked_data[train_k,timepoint,0])) 
            subjects_with_data_test[timepoint]=stacked_data[test_k,:,:].shape[0]-sum(np.isnan(stacked_data[test_k,timepoint,0])) 

        
        train_mean = np.nanmean(stacked_data[train_k,:,:],axis=0) # Average the data
        
        # set up the event segmentation model
        ev=event_seg_edits.Event_Segmentation.EventSegment(n)
        
        modeloutput=ev.fit(subjects_with_data_train,train_mean) #fit the model on the mean of the training set
        
        # now do the test
        test_mean = np.nanmean(stacked_data[test_k,:,:], axis = 0)
        _, test_ll = ev.find_events(subjects_with_data_test,test_mean)
        
        all_test_lls.append(test_ll)
        
    mean_ll=np.nanmean(all_test_lls,axis=0)
    
    return all_test_lls

# Searchlight kernel
def optk_kernel(data,sl_mask,myrad,bcvar):
    #'''Searchlight kernel that reshapes the data and decides whether there are enough voxels to run the algorithm'''
        
    num_events=bcvar[0] # so we know what we are doing
    loglik_split=bcvar[1]
        
    nTRs=data[0].shape[3] # we will need to know the number of TRs 
 
    # Make sure that we mask the data
    sl_mask_1d=sl_mask.reshape(sl_mask.shape[0] * sl_mask.shape[1] * sl_mask.shape[2]) # 1 dimensional sl mask
    
    # only run this operation if the number of brain voxels is greater than a certain amount
    if np.sum(sl_mask) >= 50:
        
        # preset list of time by voxels
        data_viewing_averaged=[]
    
        # transform data into an array of voxels
        for sub in range(len(data)):
            reshaped = data[sub].reshape(sl_mask.shape[0] * sl_mask.shape[1] * sl_mask.shape[2], 
                                         data[sub].shape[3]).T
            
            # Mask the data so that we only include data that is inside of the brain, if its on the edge
            reshaped=reshaped[:,sl_mask_1d==1]
            
            data_viewing_averaged.append(reshaped)

        output = innerloop_ll(data_viewing_averaged,num_events,loglik_split)  
        
    else:
        output=-1
        
    return output


######################################################################################
########## Step 4 - Run searchlight
print("Begin SearchLight in rank %s\n" % rank)
all_sl_result = sl.run_searchlight(optk_kernel,pool_size=pool_size)

print("End SearchLight in rank %s\n" % rank)

# save the data if on rank 0
if rank == 0:
    
    coords = np.where(mask)
    
    all_sl_result = all_sl_result[mask==1]
    all_sl_result = [nSubj*[0] if not n else n for n in all_sl_result] # replace all None
    
    # The average result
    avg_vol = np.zeros((mask.shape[0], mask.shape[1], mask.shape[2]))  
    
    temp_len=nSubj//loglik_split *loglik_split # how many iterations were there?
        
    # Loop over iterations
    for ll_iter in range(temp_len):
        sl_result = [r[ll_iter-1] for r in all_sl_result]
        
        # reshape
        result_vol = np.zeros((mask.shape[0], mask.shape[1], mask.shape[2]))  
        result_vol[coords[0], coords[1], coords[2]] = sl_result   
            
        # Convert the output into what can be used
        result_vol = result_vol.astype('double')
        result_vol[np.isnan(result_vol)] = 0  # If there are nans we want this
            
        # Add the processed result_vol into avg_vol
        avg_vol += result_vol
        
        # Save the volume
        output_name='%s/%s_%s_events_%s_iter_%s_lls.nii.gz' % (searchlight_dir,age,'all',num_events,ll_iter)
        
        sl_nii = nib.Nifti1Image(result_vol, affine_mat)
        hdr = sl_nii.header
        hdr.set_zooms((dimsize[0], dimsize[1], dimsize[2]))
        nib.save(sl_nii, output_name)  # Save

    # Save the average result
    output_name='%s/%s_%s_events_%s_average_lls.nii.gz' % (searchlight_dir,age,'all',num_events)
    
    sl_nii = nib.Nifti1Image(avg_vol/temp_len, affine_mat)
    hdr = sl_nii.header
    hdr.set_zooms((dimsize[0], dimsize[1], dimsize[2]))
    nib.save(sl_nii, output_name)  # Save    

    print('Finished searchlight')
