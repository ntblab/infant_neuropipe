## Create functional connectivity map for a given subjet 
# 01/27/2022
# Update to filter out the response to motion in this script
# 04/04/2022
# Clean it up 
# 01/11/2023

####### load the packages needed to analyze the data
import numpy as np
import os
import sys
import glob
import scipy
from scipy import stats
from scipy.io import loadmat
import pandas as pd
from sklearn.linear_model import LinearRegression
import nibabel as nib
from nilearn import plotting
from nilearn.input_data import NiftiMasker, NiftiLabelsMasker
from nilearn import datasets
import itertools
import pydicom as dicom
import warnings
warnings.filterwarnings('ignore')

####### Set up 
base_dir = os.getcwd() +'/' # script is run from infant neuropipe root

## Take in the inputs 
ppt=sys.argv[1] # subject name
group_name=sys.argv[2] # name of the group (e.g., 'Infant_Sleep' 'or 'Infant_Aeronaut')
motion_thresh=sys.argv[3] # what type of motion threshold do you want to use? (e.g., '_fslmotion_thr3' '_fslmotion_thr0.2')
parcellation=sys.argv[4] # name of parcellation (e.g., 'schaefer')
n_rois=int(sys.argv[5]) # how many ROIs do you want to use in the parcellation? (e.g., 100)
gaze_confound=1 # do you want to remove time points where kids weren't looking (during movies)? 1 or 0

# If the motion threshold is 3mm, then it is the default
if motion_thresh=='_fslmotion_thr3':
    suffix='';
else:
    suffix=motion_thresh
    
## Get the brain mask
mask = 'intersect_mask_standard' # load in the intersect mask 
brain_nii=nib.load('%s/data/RestingState/%s.nii.gz' %(base_dir,mask))
brain_masker=NiftiMasker(mask_img=brain_nii)
test_sub=nib.load('%s/data/RestingState/%s.nii.gz' %(base_dir,mask)) 
test_fit=brain_masker.fit(test_sub)
affine_mat = test_sub.affine
dimsize = test_sub.header.get_zooms()

## Get the parcellation
if parcellation=='schaefer':
    atlas = datasets.fetch_atlas_schaefer_2018(n_rois=n_rois)
    atlas_filename = atlas.maps

# Make the parcellation masker
parcellation_masker = NiftiLabelsMasker(labels_img=atlas_filename,mask_img=brain_nii)

## Now set the relevant paths
aligned_data_dir='%s/data/RestingState/%s/preprocessed_standard/nonlinear_alignment/' %(base_dir,group_name)
confounds_dir='%s/data/RestingState/%s/motion_confounds/' %(base_dir,group_name)
timing_dir='%s/data/RestingState/%s/raw_timing/' %(base_dir,group_name)
gaze_confound_dir='%s/data/RestingState/%s/eye_confounds/' %(base_dir,group_name)
output_dir='%s/data/RestingState/%s/connectivity_maps/' %(base_dir,group_name)

# get the subject nifti files (allow there to be more than one in case they had multiple functional runs)
files=glob.glob('%s/%s*%s_Only.nii.gz' %(aligned_data_dir,ppt,suffix))

# if it's a subject like mov_16 which has a second session (mov_16_2) then we need to get rid of all '_2' files
if len(ppt.split('_'))==2:
    files=[f for f in files if '%s_2' %ppt not in f]
    
# if we use the default suffix, get rid of the files that say fslmotion    
if 'fslmotion' not in suffix:
    files=[f for f in files if 'fslmotion' not in f]
    
####### Run the analysis 
for aligned in files:
    
    # What was the functional run?
    funcrun=aligned.split(ppt+'_')[-1].split('%s_Only' % suffix)[0]

    print(ppt,funcrun)

    # Transform data using the brain mask
    bold_masked = brain_masker.fit_transform(aligned)
    
    # what number of TRs is there?
    nTRs=bold_masked.shape[0]
    
    # Get the confounds file
    overall_confounds=np.loadtxt('%s/%s_%s%s.txt' %(confounds_dir,ppt,funcrun,suffix))     
        
    # This subject had two viewings in the same run but only one of them was actually useable 
    # (the first one was shown without projecting on the screen -- oops) 
    if ppt=='mov_16':
        # get the timing just for the block we want 
        timing=np.loadtxt('%s/%s_%s.txt' %(timing_dir,ppt,funcrun))
        timing=timing[1,:] # the second viewing 
        start_time=int(timing[0]//2)
        end_time=int(start_time+timing[1]//2+3)

        # just use these confounds 
        overall_confounds=overall_confounds[start_time:end_time]
        overall_confounds=np.array(overall_confounds)[:,[sum(overall_confounds[:,i])!=0 for i in range(overall_confounds.shape[1])]]
    
    # This subject had two viewings in the same run but only the first was actually useable 
    elif ppt=='s0687_1_2':
        # get the timing just for the block we want 
        timing=np.loadtxt('%s/%s_%s.txt' %(timing_dir,ppt,funcrun))
        timing=timing[0,:] # the first viewing 
        start_time=int(timing[0]//2)
        end_time=int(start_time+timing[1]//2+3)

        # just use these confounds 
        overall_confounds=overall_confounds[start_time:end_time]
        overall_confounds=np.array(overall_confounds)[:,[sum(overall_confounds[:,i])!=0 for i in range(overall_confounds.shape[1])]]
        
        # don't forget to mask the functional data!!
        bold_masked=bold_masked[start_time:end_time]
        
    # some infants also saw other MM movies (besides Aeronaut) in the same functional run, so only grab the timing you need 
    elif ppt in ['s8687_1_7','s6607_1_2']:
        
        # get the timing just for the block we want 
        timing=np.loadtxt('%s/%s_%s.txt' %(timing_dir,ppt,funcrun))
        start_time=int(timing[0]//2)
        end_time=int(start_time+timing[1]//2+3)

        # just use these confounds 
        overall_confounds=overall_confounds[start_time:end_time]
        overall_confounds=np.array(overall_confounds)[:,[sum(overall_confounds[:,i])!=0 for i in range(overall_confounds.shape[1])]]
        
        # don't forget to mask the functional data!!
        bold_masked=bold_masked[start_time:end_time]
        
    print('Shape of confounds file:',overall_confounds.shape)
    
    # Get the motion params (if it was an excluded timepoint, the time axis will sum to 1)
    motion_params=overall_confounds[:,np.sum(overall_confounds,axis=0)!=1]

    # Get the confound TRs
    confound_trs=np.where(overall_confounds==1)[0]
    
    # add the gaze confound TRs if you told us to
    if gaze_confound==1:
        try:
            
            # load the file and find the confound TRs
            eye_close_data=np.loadtxt('%s/%s_%s.txt' %(gaze_confound_dir,ppt,funcrun))
            eye_close_trs=np.where(eye_close_data==1)[0]+2 # shift two TRs for eye closures 
            
            print('adding %d additional gaze confound TRs' %(len(eye_close_trs)))
            
            # add the unique ones to the confound list 
            confound_trs=np.unique(np.concatenate((confound_trs, eye_close_trs)))
            
        except:
            print('no eye closure file for, so not including as confounds')
            
    # Z-score the data over time 
    bold_zscored = stats.zscore(bold_masked,axis=0)
        
    # Regress out the motion parameters for each voxel in the brain
    regressed_data=np.zeros(bold_zscored.shape)
    for vox in range(bold_zscored.shape[1]):
        
        # what are the motion parameters 
        x=motion_params
            
        y=bold_zscored[:,vox]

        # in case it fails
        try:
            reg = LinearRegression().fit(x, y)
            resid=y-reg.predict(x)

            regressed_data[:,vox]=resid
        except:
            regressed_data[:,vox]=np.zeros(bold_zscored.shape[0])*np.nan
    
    # Set the confound TRs to NaNs
    for tr in confound_trs:
        regressed_data[tr,:]=np.nan
    
    # Now, transform the voxelwise data into parcels 
    regressed_parcels = parcellation_masker.fit_transform(brain_masker.inverse_transform(regressed_data))
    
    # Get the correlation matrix (using Pandas because this allows for NaNs)
    corr_mat = np.array(pd.DataFrame(regressed_parcels).corr())
    np.fill_diagonal(corr_mat,np.nan)

    # save the data
    print('Saving out %s/%s_%s%s_%s%d.npy' %(output_dir,ppt,funcrun,suffix,parcellation,n_rois))
    np.save('%s/%s_%s%s_%s%d.npy' %(output_dir,ppt,funcrun,suffix,parcellation,n_rois),corr_mat)


