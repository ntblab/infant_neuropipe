# Uses the best K value on an inner loop iteration to find out the reliability of the event segmentation in a completely held out subject 
# v1 10/03/2019 
# complete revamp 08/14/2020

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
import itertools
import nibabel as nib
from nilearn.input_data import NiftiMasker

# Now import our custom Event Seg code
import event_seg_edits.Event_Segmentation

#######################   
####################### 

movie=sys.argv[1]
print('Analysing %s' % movie)

# movie info
if movie == 'Aeronaut':
    nTRs=90
    nSubj=24
    mask = 'intersect_mask_standard_firstview_all' # get just the mask of the first view participants
elif movie == 'Mickey':
    nTRs=71
    nSubj=15
    mask = 'intersect_mask_standard_all'

base_dir = os.getcwd() +'/' # script is run from infant neuropipe root
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
    #'''Mask whole brain data using a given ROI'''
    roi_data=[]
    for sub in range(wholebrain_data.shape[2]):

        roi_nii=nib.load(roi_dir+roi+'.nii.gz')

        sub_nii=brain_masker.inverse_transform(wholebrain_data[:,:,sub])

        sub_data=sub_nii.get_data()[np.array(brain_nii.get_data()*roi_nii.get_data(),dtype=bool)]
        roi_data.append(sub_data)
    
    roi_data=np.stack(roi_data)
    return roi_data

# roll the data randomly or using a given shift value to create a permutation 
def create_roll(data,determined_shift=None):
    #'''Shifts data either a random value (when determined_shift: 'None') or shifts the given amount'''
    rolled_data=data.copy()
    for sub in range(len(data)):
        if determined_shift==None:
            shift=np.random.randint(1,data.shape[1])
        else:
            shift=determined_shift
        #print('sub: %d shift: %d' %(sub,shift))

        rolled_data[sub,:,:]=(np.roll(data[sub,:,:],shift,axis=1))
        
    return rolled_data

# test reliability of optK found from inner loop
def testreliability_ll(data,leftout_sub,k,nTRs):
    #'''Fit an event segmentation model with a given K value on a set of data, while holding out one participant for testing
    #Returns the log-likelihood for the held out participants' actual data and z-statistic noting the distance
    #between the actual log-likelihood and the permutation distribution'''
    stacked_data=np.stack(data)
    
    train_ids=np.delete(np.arange(len(data)),leftout_sub)
    train_data=stacked_data[train_ids,:,:]
    
    subjects_with_data_train=np.zeros(nTRs)
    
    for timepoint in range(stacked_data.shape[1]):
        subjects_with_data_train[timepoint]=train_data.shape[0]-sum(np.isnan(train_data[:,timepoint,0])) 
    
    # where does this subject have missing time points? 
    sub_with_data=1-np.array(np.isnan(stacked_data[leftout_sub,:,0]),dtype='int')
    
    # Fit for the train
    ev=event_seg_edits.Event_Segmentation.EventSegment(k)
 
    modeloutput=ev.fit(subjects_with_data_train,np.nanmean(train_data,axis=0))
    
    # Run the actual test
    segments, test_ll = ev.find_events(sub_with_data,stacked_data[leftout_sub,:,:])
    
    # Expand the dimensions to allow for rolling
    leftout_data_3d=np.expand_dims(stacked_data[leftout_sub,:,:],axis=0)
     
    perm_lls=np.zeros(nTRs)
        
    for p in range(nTRs):
        rolled_data=create_roll(leftout_data_3d,p)
        rolled_data=rolled_data[0]
        
        sub_with_data=1-np.array(np.isnan(rolled_data[:,0]),dtype='int')
        rolled_seg,rolled_ll=ev.find_events(sub_with_data,rolled_data)
            
        perm_lls[p]=rolled_ll
        
    # Then finally calculate the z-statistic
    zstat=(test_ll-np.nanmean(perm_lls))/np.nanstd(perm_lls)
    
    return test_ll, zstat

#######################   
####################### 

#Inputs from sh script
age = sys.argv[2] #which age group? adults, infants, (certain age infants?) or all of the above?
roi = sys.argv[3] #what roi?


max_number_events=sys.argv[4] # what was the max number of events that we tested? 
max_number_events=np.int(max_number_events)

leftout_sub=sys.argv[5] # who was left out ?
leftout_sub=np.int(leftout_sub)

split=2 # doing split half analyses 

# Which events were tested?
tested_events=np.arange(2,max_number_events)

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

# preset
all_ll_loops=[]

for n in tested_events:
    ll_vals=np.load(optk_dir+'/%s_%s_%d_events_leftout_%d_loglik.npy' % (age,roi,n,leftout_sub))   
    all_ll_loops.append(np.nanmean(ll_vals)) # get the average across folds
    
all_ll_loops=np.stack(all_ll_loops)
    
# Find which one was the highest
best_ll_idx=np.argmax(all_ll_loops)
best_k=tested_events[best_ll_idx]

print('Best inner loop number of events was %d (mean LL: %f)' % (best_k,all_ll_loops[best_ll_idx]))
print("*Now testing this event number on the other held out subject*")
    
test_ll, zstat = testreliability_ll(data,leftout_sub,best_k,nTRs)
    
# put the results in one place
save_data=np.array((best_k,test_ll,zstat))

print("Reliability Results for Subj %s: Actual LL= %f; Zstat vs perm LL = %f" %(str(leftout_sub), test_ll, zstat)) #print the output
    
# save!!     
np.save(optk_dir+'/%s_%s_relsub_%d_bestk_loglik' % (age,roi,leftout_sub),save_data)
 
print('Finished')