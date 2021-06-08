# Uses the most optimal event structure from one age group to assess the fit for individuals of another age group 


from matplotlib import pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import matplotlib.patches as patches
import numpy as np
import pandas as pd
import sys
import os
from brainiak import isfc
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
    nSubj=25
    num_events=np.arange(2,22)
    mask = 'intersect_mask_standard_firstview_all' # get just the mask of the first view participants
elif movie == 'Mickey':
    nTRs=71
    nSubj=15
    num_events=np.arange(2,19)
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

def get_bestk_roi(age,roi,num_events,split=2):
    '''Pull the numpy file that has information on the best K and maximum log likelihood for a given age group
    the split variable tells you how the data was divided during the inner loop training (we used split half, so
    defaults to a split value of 2)'''
    all_ll_loops=np.zeros((len(num_events),nSubj//split*split))

    for n in range(len(num_events)):
        loglik=np.load('%s/%s_%s_%d_events_cb_method_loglik_%d.npy' % (optk_dir,age,roi,num_events[n],split))
        all_ll_loops[n,:]=loglik

    mean_ll=np.nanmean(all_ll_loops,axis=1)
    ll_idx=np.argmax(mean_ll)
    bestk=np.array(num_events)[ll_idx]
    
    return bestk
                
# roll the data randomly or using a given shift value to create a permutation 
def create_roll(data,determined_shift=0):
    '''Shifts data either a random value (when determined_shift: 'None') or shifts the given amount'''
    rolled_data=data.copy()
    for sub in range(len(data)):
        if determined_shift==None:
            shift=np.random.randint(1,data.shape[1])
        else:
            shift=determined_shift
        #print('sub: %d shift: %d' %(sub,shift))

        rolled_data[sub,:,:]=(np.roll(data[sub,:,:],shift,axis=1))
        
    return rolled_data

#######################   
####################### 

#Inputs from sh script
train_age = sys.argv[2] #which age group? adults, infants, (certain age infants?) or all of the above?
test_age=sys.argv[3]

# Set up the ROIs
rois=['EVC_standard','LOC_standard','AG_standard','PCC_standard','Precuneus_standard',
      'mPFC_standard','Hippocampus_standard','EAC_standard']

# get the whole brain mask
brain_nii=nib.load(movie_eventseg_dir+mask+'.nii.gz')
brain_masker=NiftiMasker(mask_img=brain_nii)
test_sub=nib.load(movie_eventseg_dir+mask+'.nii.gz') 
test_fit=brain_masker.fit(test_sub)
affine_mat = test_sub.affine
dimsize = test_sub.header.get_zooms()
coords= np.where(brain_nii.get_data())

# get the brain data for the two age groups
data_train=np.load(movie_eventseg_dir+train_age+'_wholebrain_data.npy')  
data_test=np.load(movie_eventseg_dir+test_age+'_wholebrain_data.npy')    

zstat_all_rois=[]

for r,roi in enumerate(rois):
    print(roi)
    
    # What was the best K for the train data in this ROI? 
    bestk=get_bestk_roi(train_age,roi,num_events,split=2)
    print('Best k:',bestk)
    
    # Get the data for the "train age"
    data=mask_roi_data(data_train,roi)    
   
    # then reshape it to be sub x time x vox
    data=data.transpose(0,2,1)
    
    # fit the model
    ev=event_seg_edits.Event_Segmentation.EventSegment(np.int(bestk))

    mean_data = np.nanmean(data,axis=0) # average the data

    subjects_with_data=np.zeros(mean_data.shape[0]) #preset

    # Iterate through time points and figure out how many subjects have data at that time point
    for timepoint in range(mean_data.shape[0]):

        # just use the first voxel
        subjects_with_data[timepoint]=len(data)-sum(np.isnan(np.stack(data)[:,timepoint,0])) 

    # Give the subjects with data and the average neural datant
    modeloutput=ev.fit(subjects_with_data,mean_data)
    
    # Get the data for the "test age"
    data_2=mask_roi_data(data_test,roi)    
   
    # then reshape it to be sub x time x vox
    data_2=data_2.transpose(0,2,1)
    
    # preset
    zstat_values=[]
    
    # cycle through participants
    for sub in range(len(data_2)):
        
        sub_with_data=1-np.array(np.isnan(data_2[sub][:,0]),dtype='int')
        actual_seg,actual_ll=ev.find_events(sub_with_data,data_2[sub]) # fit with the other age group data
        
        leftout_data_3d=np.expand_dims(np.stack(data_2)[sub,:,:],axis=0) # extend dim for permuting
        
        # how does this compare to permutations
        perm_lls=np.zeros(nTRs)
        for p in range(nTRs):
            rolled_data=create_roll(leftout_data_3d, p)
            rolled_data=rolled_data[0]
            
            sub_with_data=1-np.array(np.isnan(rolled_data[:,0]),dtype='int')
            
            rolled_seg,rolled_ll=ev.find_events(sub_with_data,rolled_data)

            perm_lls[p]=rolled_ll
        
        zstat=(actual_ll-np.nanmean(perm_lls))/np.nanstd(perm_lls)
        zstat_values.append(zstat)
        
    zstat_all_rois.append(zstat_values)

df=pd.DataFrame(zstat_all_rois)

np.save(optk_dir+'%s_bounds_in_%s' %(train_age,test_age),df)
