# Find average within vs across using human boundaries 10/01/2020
# update 11/4/2020

######################################################################################
########## Step 1: Import stuff
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
    
base_dir = os.getcwd() +'/' # script is run from infant neuropipe root
roi_dir =  base_dir + 'data/EventSeg/ROIs/' 
movie_eventseg_dir =  base_dir + 'data/EventSeg/%s/' % movie
searchlight_dir = movie_eventseg_dir + 'eventseg_searchlights/'
optk_dir = movie_eventseg_dir + 'eventseg_optk/'
human_dir = movie_eventseg_dir + 'eventseg_human_bounds/'
save_plot_dir = movie_eventseg_dir+'plots/' 

######################################################################################
####### Step 1.5 - function to load in the behavioral event boundaries 
def gethumanbounds():
    #'''get the human-determined behavioral boundaries for this movie and return different forms of the data 
    #useful for running behavioral analyses'''
    # import the human labeled events
    humanlab_events_TR=np.load(movie_eventseg_dir+'behavioral_boundary_events.npy')
    num_events = (len(humanlab_events_TR[0])+1) #length of events
    #print('Number of human labeled events:',num_events)

    # Create an array of length nTRs that tells you whether event is a human labeled event
    events_fullarray = []
    event_idx = humanlab_events_TR[0]
    for idx in range(num_events):
        if idx == 0:
            nums = np.repeat(idx,event_idx[idx])
        elif idx == len(humanlab_events_TR[0]):
            nums = np.repeat(len(humanlab_events_TR[0]),(90 - event_idx[idx-1]))
        else:
            nums = np.repeat(idx,(event_idx[idx] - event_idx[idx-1]))
        events_fullarray.extend(nums) 
    #print('Events:',events_fullarray)
    #print(len(events_fullarray))

    return humanlab_events_TR[0], events_fullarray


def humanbounds_eventmat():
    #'''Create a matrix showing which timepoint pairs are within events, and the distance of these pairs from the diagonal'''
    bounds_TR, events_array = gethumanbounds()
    
    ## Step 1 -- make the matrices that tell you about distance and event status
    #add 0 and the end of the movie 
    event_aug = np.concatenate(([0],np.array(bounds_TR),[len(events_array)])) 

    #now create a matrix the same size as the data but with 1 for event 0 for outside-event
    event_mat = np.ones([len(events_array),len(events_array)])

    #fill it up
    for bound in range(len(event_aug)):
        if bound <= len(bounds_TR):
            bound=np.int(bound)
            event_mat[np.int(event_aug[bound]):np.int(event_aug[bound+1]),
                    np.int(event_aug[bound]):np.int(event_aug[bound+1])] = 2
  
    dist_mat = np.zeros([len(events_array),len(events_array)])

    #fill it up
    for time in range(len(events_array)):
        for othertime in range(len(events_array)):
            dist_mat[time,othertime] = np.abs(othertime-time)
    
    return event_mat,dist_mat 

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
coords= np.where(brain_nii.get_data())


# Get the boundary information
event_mat, dist_mat = humanbounds_eventmat()

print("Loaded event data \n")

#preset
data=[]

#only load in the data on rank 0
if rank ==0:

    stacked_data=np.load(movie_eventseg_dir+age+'_wholebrain_data.npy')
    sub_data=stacked_data[:,:,sub] # get just this subject (speeds up the analyses a lot)
    
    data_4d=brain_masker.inverse_transform(sub_data)
    data.append(data_4d.get_data()) # needs to be a list though

else:
    data += [None]

print("Loaded participant %s %d \n" % (age,sub))

######################################################################################
####### Step 3 - set up the searchlight

mask=brain_nii.get_data()
data=data
sl_rad = 3
max_blk_edge = 5
pool_size = 1
bcvar=[event_mat, dist_mat] # Give the human boundaries

# Create the searchlight object
sl = Searchlight(sl_rad=sl_rad,max_blk_edge=max_blk_edge)

# Distribute the information to the searchlights (note that data is already a list)
sl.distribute(data, mask)

sl.broadcast(bcvar)


######################################################################################
####### Step 4 - define kernel

def find_within_vs_across(data, event_mat, dist_mat):
    #'''Find the within-vs-across behavioral boundary correlations after accounting for distance to the diagonal
    #resamples correlations in the case of unbalanced distributions
    #This approach uses more time points but by not matching time point comparisons, may introduce noise'''
    
    corr_mat=np.corrcoef(data)
    
     # Where are the non events?? 
    event_mask=event_mat==2
    nonevent_mask=event_mat==1
        
    # What about the nans?
    non_nan_times=~np.isnan(corr_mat)

    possible_distances=np.unique(dist_mat[event_mat==2])
    
    differences=[]
    weights=[]    
    nPerm=1000
    for dist in possible_distances:
        dist_mask=dist_mat==dist
        
        # mask out the nans and only look at the pairs a distance away
        dist_event_mask=event_mask*dist_mask*non_nan_times
        dist_nonevent_mask=nonevent_mask*dist_mask*non_nan_times
            
        corr_evs=corr_mat[dist_event_mask] # get the correlation here if its an event
        corr_nonevs=corr_mat[dist_nonevent_mask]  # get the correlation here if its not an event 

        # preset 
        perms=np.zeros(nPerm)
        
        # permute the one that is larger 
        if len(corr_evs) > len(corr_nonevs):
            sub_group=corr_evs
        else:   
            sub_group=corr_nonevs
        
        # permute! 
        for perm in range(nPerm):        
            subsamp=np.random.choice(sub_group,size=len(sub_group))       
            perms[perm]=np.nanmean(subsamp,axis=0)
        
        # subtract within event - between event
        if len(corr_evs) > len(corr_nonevs):
            wva_dist=np.nanmean(perms)-np.nanmean(corr_nonevs)
            weight=len(corr_nonevs)
        else:   
            wva_dist=np.nanmean(corr_evs)-np.nanmean(perms)
            weight=len(corr_evs)
        
        # append the distances 
        differences.append(wva_dist)
        weights.append(weight)
              
        
    all_differences =  np.nanmean(differences)
    weighted_differences = np.nansum([differences[i]*weights[i] for i in np.arange(len(differences))])/np.nansum(weights)
            
           
    return all_differences, weighted_differences

def find_within_vs_across_alt(data, event_mat, dist_mat):
    #'''Find the within-vs-across behavioral boundary correlations for each TR and distance to the diagonal if forward and
    #backward timepoint pairs differ in whether they are within vs across an event
    #This approach is a more conservative and cleaner version of the above approach, but uses less data'''
    
    corr_mat=np.corrcoef(data)
        
    # First, let's find the correlation matrix     
    withins=[]
    acrosses=[]
    used_mat=np.zeros(corr_mat.shape) 
    
    for TR in range(corr_mat.shape[0]):
          
        for dist in range(corr_mat.shape[0]): # will break before it gets to this distance anyways
            #print('dist',dist)
            if TR+dist<corr_mat.shape[0] and TR-dist>0: # don't look too far forward is back
                forward_pair=event_mat[TR+dist,TR]
                backward_pair=event_mat[TR,TR-dist]
                #print(forward_pair,backward_pair)

                # if one of these comparisons is within event and the other is across, we continue
                # also make sure no nans in either pair, and that these timepoints have not been used before 
                if forward_pair!=backward_pair and ~np.isnan(corr_mat[TR+dist,TR]) and ~np.isnan(corr_mat[TR,TR-dist]) and used_mat[TR,TR-dist]==0 and used_mat[TR+dist,TR]==0:

                    if forward_pair>backward_pair: # forward is the within event
                        within=corr_mat[TR+dist,TR]
                        across=corr_mat[TR,TR-dist]

                    elif forward_pair<backward_pair: # backward is the within event
                        within=corr_mat[TR,TR-dist]
                        across=corr_mat[TR+dist,TR]
                        
                    used_mat[TR,TR-dist]+=1 # indicate that you've used this timepoint before
                    used_mat[TR+dist,TR]+=1

                    withins.append(within)
                    acrosses.append(across)
                        
        wvas= (np.nanmean(withins) - np.nanmean(acrosses))
                        
    return wvas
    
#What is the kernel?
def human_bound_kernel(data,sl_mask,myrad,bcvar):
    #'''Searchlight kernel that reshapes the data and decides whether there are enough voxels to run the algorithm'''
    
    event_mat=bcvar[0] # so we know what we are doing
    dist_mat=bcvar[1]
    
    # Make sure that we mask the data
    sl_mask_1d=sl_mask.reshape(sl_mask.shape[0] * sl_mask.shape[1] * sl_mask.shape[2]) # 1 dimensional sl mask
    
    #only run this operation if the number of brain voxels is greater than a certain amount
    if np.sum(sl_mask) >= 50:
        
        reshaped = data[0].reshape(sl_mask.shape[0] * sl_mask.shape[1] * sl_mask.shape[2], 
                                         data[0].shape[3]).T
        
        # Mask the data so that we only include data that is inside of the brain
        data=reshaped[:,sl_mask_1d==1]
           
        
        # Get the output (the weighted version)
        _,output =  find_within_vs_across(data, event_mat, dist_mat) # output =  find_within_vs_across_alt(data, event_mat, dist_mat)
        
    else:
        output=-1
        
    return output


#############################################################
#############################################################
#####Step 4 - go go go searchlight !!
print("Begin SearchLight in rank %s\n" % rank)
all_sl_result = sl.run_searchlight(human_bound_kernel,pool_size=pool_size)

print("End SearchLight in rank %s\n" % rank)

#save if on rank 0
if rank == 0:

    all_sl_result = all_sl_result.astype('double')
    all_sl_result[np.isnan(all_sl_result)] = 0

    # Save the results!!!
    output_name = human_dir + age+'_sub_'+str(sub)+'_humanbounds.nii.gz'
    sl_nii = nib.Nifti1Image(all_sl_result, affine_mat)
    hdr = sl_nii.header
    hdr.set_zooms((dimsize[0], dimsize[1], dimsize[2]))
    nib.save(sl_nii, output_name)  # Save

    print('Finished searchlight')
    
    
