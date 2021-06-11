# Find optimal events in a given ROI
# 11/09/2020


######################################################################################
########################import stuff##################################################
from matplotlib import pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import matplotlib.patches as patches
import numpy as np
import pandas as pd
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
import itertools

# Now import our custom Event Seg code
import event_seg_edits.Event_Segmentation

#######################   
####################### 

movie=sys.argv[1]
print('Analysing %s' % movie)

# movie info
if movie == 'Aeronaut':
    nTRs=90
    nSubj=25
    mask = 'intersect_mask_standard_firstview_all' # get just the mask of the first view participants
elif movie == 'Mickey':
    nTRs=71
    nSubj=15
    mask = 'intersect_mask_standard_all'

# Get the base directory
base_dir = os.getcwd() + '/'

# Set the event segmentation directories
roi_dir =  base_dir + 'data/EventSeg/ROIs/' 
movie_eventseg_dir =  base_dir + 'data/EventSeg/%s/' % movie
searchlight_dir = movie_eventseg_dir + 'eventseg_searchlights/'
optk_dir = movie_eventseg_dir +'eventseg_optk/'
human_dir = movie_eventseg_dir + 'eventseg_human_bounds/'
save_plot_dir = movie_eventseg_dir+'plots/' 

#######################   
####################### 

# get the ROI data from the whole brain data
def mask_roi_data(wholebrain_data,roi):
    '''Mask whole brain data using a given ROI'''
    roi_data=[]
    for sub in range(wholebrain_data.shape[2]):

        roi_nii=nib.load(roi_dir+roi+'.nii.gz')

        sub_nii=brain_masker.inverse_transform(wholebrain_data[:,:,sub])

        sub_data=sub_nii.get_data()[np.array(brain_nii.get_data()*roi_nii.get_data(),dtype=bool)]
        roi_data.append(sub_data)
    
    roi_data=np.stack(roi_data)
    return roi_data

# Inner loop that will find the log likelihood for this n value
def innerloop_ll(data,n,split):
    '''Fit and test an event segmentation model with a given K value on split halves of a set of data
    Returns the average and all log-likelihoods across different iterations'''
    stacked_data=np.stack(data)
    
    #preset
    all_test_lls = []
    
    # preset
    subjects_with_data_train=np.zeros(nTRs)
    subjects_with_data_test=np.zeros(nTRs)
    
    # what split are you doing?
    sp=np.int(split)
    kf = RepeatedKFold(sp,len(data)//sp)
    
    for train_k, test_k in kf.split(stacked_data):
        
        #Iterate through time points and figure out how many subjects have data at that time point
        for timepoint in range(stacked_data.shape[1]):

            # just use the first voxel
            subjects_with_data_train[timepoint]=stacked_data[train_k,:,:].shape[0]-sum(np.isnan(stacked_data[train_k,timepoint,0])) 
            subjects_with_data_test[timepoint]=stacked_data[test_k,:,:].shape[0]-sum(np.isnan(stacked_data[test_k,timepoint,0])) 

        
        train_mean = np.nanmean(stacked_data[train_k,:,:],axis=0) # average
        
        # Fit the event segmentation model
        ev=event_seg_edits.Event_Segmentation.EventSegment(n)
        
        modeloutput=ev.fit(subjects_with_data_train,train_mean) #fit the model on the mean of the training set
        
        # Now do the test
        test_mean = np.nanmean(stacked_data[test_k,:,:], axis = 0)
        _, test_ll = ev.find_events(subjects_with_data_test,test_mean)
        
        all_test_lls.append(test_ll)
        
    mean_ll=np.nanmean(all_test_lls,axis=0)
    
    return mean_ll, all_test_lls

#######################   
#######################  

#Inputs from sh script
age = sys.argv[2] # which age group? adults, infants, (certain age infants?) or all of the above?
roi = sys.argv[3] # what roi?

num_events=sys.argv[4] # how many events are you checking for?
num_events=np.int(num_events)

if len(sys.argv) > 5: # are you leaving someone out for the nested version?
    leftout_sub=sys.argv[5]
    leftout_sub=np.int(leftout_sub)
else:
    leftout_sub=None

loglik_split=2 # log likelihood split 

print('ROI:',roi)
print('Subject ages:', age)

if leftout_sub != None:
    print('Leaving out subject %d' % leftout_sub)

print()

# get the whole brain mask
brain_nii=nib.load(movie_eventseg_dir+mask+'.nii.gz')
brain_masker=NiftiMasker(mask_img=brain_nii)
test_sub=nib.load(movie_eventseg_dir+mask+'.nii.gz') 
test_fit=brain_masker.fit(test_sub)
affine_mat = test_sub.affine
dimsize = test_sub.header.get_zooms()
coords= np.where(brain_nii.get_data())

# get the brain data for this roi!
stacked_data=np.load(movie_eventseg_dir+age+'_wholebrain_data.npy')    
data=mask_roi_data(stacked_data,roi)    
    
# then reshape it to be sub x time x vox
data=data.transpose(0,2,1)
print('Shape of data:',data.shape)

# remove the leftout sub if you need to do so 
if leftout_sub != None:
    train_index=np.delete(np.arange(len(data)),leftout_sub)
    data=data[train_index,:,:]
    
# Run the algorithm!
print('Running for events:',num_events)
mean_ll, logliks = innerloop_ll(data,num_events,loglik_split)  
print('Mean LL:',mean_ll)

# Save the results accordingly! 
if leftout_sub != None:
    np.save(optk_dir+'/%s_%s_%d_events_leftout_%d_loglik' % (age,roi,num_events,leftout_sub),logliks)
else:    
    np.save(optk_dir+'/%s_%s_%d_events_cb_method_loglik_%s' % (age,roi,num_events,loglik_split),logliks)

print('Finished')
