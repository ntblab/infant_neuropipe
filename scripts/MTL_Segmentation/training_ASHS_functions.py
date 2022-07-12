# This code generates the manifest files needed to train an ASHS model in a leave-one-session out or leave-one-scan-out fashion
# Given below are four functions. The first returns the sXXXX_X_X formatted name of the participant. The second takes a tracer's segmentation and divides it into "left_volume" and "right_volume" files that are used to train ASHS. The third generates the manifest files needed to train ASHS with one tracer (e.g. CE-ASHS, JF-ASHS). The fourth generates the manifest files used for training ASHS with two tracers (e.g. Infant-Trained-ASHS). 

# NOTE: In order make this script work, edit the file path given below to go to the directory needed:

    #out_dir: The main path of the project directory (the cloned neuropipe repo)

import numpy as np
from scipy import stats
import scipy
from scipy.cluster.hierarchy import fcluster, linkage, dendrogram
from scipy.io import loadmat
import sys
import os
import nilearn.plotting
import scipy.spatial.distance as sp_distance
from scipy import stats, ndimage
from nilearn import datasets
from nilearn.input_data import NiftiMasker
import pandas as pd
import glob
from scipy.ndimage.morphology import binary_dilation
from pylab import *
import matplotlib.style
import matplotlib as mpl
import matplotlib.pyplot as plt
import matplotlib.image as mpimg
from matplotlib.colors import ListedColormap

# Setup some file paths
curr_dir = os.getcwd()
os.chdir('../../') # Move into the infant neuropipe root
base_dir = os.getcwd() + '/'
os.chdir(curr_dir) # Come back

out_dir = base_dir + '/data/MTL_Segmentations/'

# Path containing the segmentations of the participants in their native anatomical space.  
out_dir_segmentations_anatomical = '%s/segmentations_anatomical/' % out_dir

# Returns the name of the participant in the format of sXXXX_X_X
def ppt_namer(file_path):
    
    # Index the beginning and end of the name
    start_index = file_path.find('nii.gz') - 13
    end_index = file_path.find('nii.gz') - 4
    
    # Generate the name
    participant = file_path[start_index:end_index] 

    return participant

# Collect the names of the 42 participant scans using the previously made function
ppt_names = []
files_segmentations_anatomical_CE = sorted(glob.glob(out_dir_segmentations_anatomical + '*CE.nii.gz'))
for file_name in files_segmentations_anatomical_CE:
    ppt_name = ppt_namer(file_name)
    ppt_names += [ppt_name]
    
# Collect the ages of the 42 participant scans to then order the participant files about to be made
ppt_ages = []
for ppt_name in ppt_names:
    index = np.where(df['hashed_name'] == ppt_name)[0][0]
    ppt_ages += [df['Age'][index]]

# Store the paths for CE's manual data in a list and order it by age 
files_segmentations_anatomical_CE = sorted(glob.glob(out_dir_segmentations_anatomical + '*CE.nii.gz'))
ordered_files_segmentations_anatomical_CE = np.asarray(files_segmentations_anatomical_CE)[np.argsort(ppt_ages)]

# Store the paths for JF's manual data in a list and order it by age 
files_segmentations_anatomical_JF = sorted(glob.glob(out_dir_segmentations_anatomical + '*JF.nii.gz'))
ordered_files_segmentations_anatomical_JF = np.asarray(files_segmentations_anatomical_JF)[np.argsort(ppt_ages)]


# Splits a rater's volume into left and right files to then be used to train an ASHS model
def left_and_right_ppt_file_maker(ordered_files_segmentations_list, rater_name):
    
    # Loop through the segmentations of a rater
    for segmentation in ordered_files_segmentations_list:
        
        # Store the name of the participant
        ppt_name = ppt_namer(segmentation)
        
        # Load in the volume
        vol_total = nib.load(segmentation).get_data()
        
        # Make empty right and left volume shells that match the shape of the participants volume
        l_vol = np.zeros(vol_total.shape)
        r_vol = np.zeros(vol_total.shape)
        
         # Find the index of each voxel from the loaded participant volume equal to 6 (rHPC) and 4 (rMTL) and place them in their corresponding index in the right volume shell 
        r_vol[(vol_total == 6) | (vol_total == 4)] = vol_total[(vol_total == 6) | (vol_total == 4)]
        
        # Save this right volume
        nii_right = nib.Nifti1Image(r_vol, nib.load(segmentation).affine)
        file_name = out_dir + 'participant_files_ASHS/%s_%s_Right_Side.nii.gz'%(ppt_name, rater_name)
        nib.save(nii_right, file_name)

        # Find the index of each voxel from the loaded participant volume equal to 5 (lHPC) and 3 (lMTL) and place them in their corresponding index in the left volume shell 
        l_vol[(vol_total == 5) | (vol_total == 3)] = vol_total[(vol_total == 5) | (vol_total == 3)]
        
        # Save this left volume
        nii_left = nib.Nifti1Image(l_vol, nib.load(segmentation).affine)
        file_name = out_dir + 'participant_files_ASHS/%s_%s_Left_Side.nii.gz'%(ppt_name, rater_name)
        nib.save(nii_left, file_name)

        
ppt_names_not_duplicates = []
for segmentation in ordered_files_segmentations_anatomical_CE:
    segmentation = ppt_namer(segmentation)
    if segmentation[:5] not in ppt_names_not_duplicates:
        ppt_names_not_duplicates.append(segmentation[:5])
        
        
ASHS_dir = 'CE_ASHS' # Set this string equal to the name of the ASHS directory you want to extract the segmentations from, this is CE's directory as an example


# Generates the manifest files used for training ASHS with one tracer
def manifest_file_maker_one_tracer(ordered_files_segmentations, ASHS_dir, tracer_name, ASHS_dir_LOP=0, LOP=False):
    
    # Doing a leave-one-session-out approach
    if LOP == False:
        
        for loo_ppt in list(ordered_files_segmentations):
            
            loo_ppt_name = ppt_namer(loo_ppt)
            
            File_object = open(out_dir + ASHS_dir + '%s_Manifest_File.txt' %(loo_ppt_name),"w+")
            
            for ppt in list(ordered_files_segmentations):
            
            if loo_ppt != ppt:
                
                ppt_name = ppt_namer(ppt)
                
                # Make the manifest file with paths to subject ID, T1-weighted MRI scan in NIFTI format, and left/right segmentations in NIFTI format
                File_object.write('\n%s %s%s.nii.gz %s%s.nii.gz %sparticipant_files_ASHS/%s_%s_Left_Side.nii.gz %sparticipant_files_ASHS/%s_%s_Right_Side.nii.gz' %(ppt_name, out_dir_anatomicals, ppt_name, out_dir_anatomicals, ppt_name, out_dir, ppt_name, tracer_name, out_dir, ppt_name, tracer_name))

            # Close the file        
            File_object.close()
            
    # Doing a leave-one-participant-out approach
    if LOP == True:
        
        # Loop through the rater's list of segmentations
        for loo_ppt in list(ordered_files_segmentations):

            # To leave out each scan from a participant, we care about the "sXXXX" portion, and index the name of the participant accordingly
            start_index = loo_ppt.find('nii.gz') - 13
            end_index = loo_ppt.find('nii.gz') - 8

            # Open a manifest file and name it using the "sXXXX" of the left out participant 
            File_object = open(out_dir + ASHS_dir + '%s_Manifest_File.txt' %(rater_name, (loo_ppt[start_index:end_index])),"w+")

            # Loop through the rater's list of segmentations
            for ppt in list(ordered_files_segmentations):

                # Only make a manifest file for this participant scan if it is from a separate participant (i.e., its "sXXXX" is different from the other "sXXXX")
                if loo_ppt[start_index:end_index] != ppt[start_index:end_index]:

                    # Determine the full name of the participant 
                    ppt_name = ppt_namer(ppt)

                    # Make the manifest file 
                    File_object.write('\n%s %s%s.nii.gz %s%s.nii.gz %sparticipant_files_ASHS/%s_%s_Left_Side.nii.gz %sparticipant_files_ASHS/%s_%s_Right_Side.nii.gz' %(ppt_name, out_dir_anatomicals, ppt_name, out_dir_anatomicals, participant_name, out_dir, ppt_name, tracer_name, out_dir, ppt_name, tracer_name))

            # Close the file        
            File_object.close()
          
        
# Generates the manifest files used for training ASHS with two tracers     
def manifest_file_maker_two_tracers(ASHS_dir, LOP=False):       
    
    # Make lists to store ppt names
    ppt_names_CE = []
    ppt_names_JF = []
    complete_ppt_names = []
    
    # Loop through the list of segmentation files to acquire names
    for segmentation in ordered_files_segmentations_anatomical_CE:
        
        ppt_names_CE += [ppt_namer(segmentation) + '_CE']
        ppt_names_JF += [ppt_namer(segmentation) + '_JF']
    
    # Combine the two lists of names to have 84 names in total: half have a 'CE' ending string and the other half have a 'JF' ending
    complete_ppt_names = ppt_names_CE + ppt_names_JF
    
    # Doing a leave-one-session-out approach
    if LOP == False:
        
        # Loop through each of the 42 names
        for ppt in ppt_names_CE:
            
            # Open a file
            File_object = open(out_dir + ASHS_dir + '/%s_Manifest_File.txt' % (ppt[:9]),"w+")
            
            # Remove the singular ppt session from the total list of names
            complete_ppt_names.remove(ppt[:9] + '_CE')
            complete_ppt_names.remove(ppt[:9] + '_JF')
            
            # Shuffle the names to avoid ASHS overfitting
            np.random.shuffle(complete_ppt_names)
            
            # Loop through the 82 remaining names
            for ppt_name in complete_ppt_names:
                
                # Write a manifest file that contains the data from both tracers  
                if 'CE' in ppt_name:
                    File_object.write('\n%s %s%s.nii.gz %s%s.nii.gz %s/participant_files_ASHS/%s_%s_Left_Side.nii.gz %s/participant_files_ASHS/%s_%s_Right_Side.nii.gz' %(ppt_name[:9], out_dir_anatomicals, ppt_name[:9], out_dir_anatomicals, ppt_name[:9], out_dir, ppt_name[:9], 'CE', out_dir, ppt_name[:9], 'CE'))
                else:
                    File_object.write('\n%s %s%s.nii.gz %s%s.nii.gz %s/participant_files_ASHS/%s_%s_Left_Side.nii.gz %s/participant_files_ASHS/%s_%s_Right_Side.nii.gz' %(ppt_name[:9], out_dir_anatomicals, ppt_name[:9], out_dir_anatomicals, ppt_name[:9], out_dir, ppt_name[:9], 'JF', out_dir, ppt_name[:9], 'JF'))
            
            # Add the ppt names back to the list
            complete_ppt_names.append(ppt[:9] + '_CE')
            complete_ppt_names.append(ppt[:9] + '_JF')
            
            # Close the file
            File_object.close()
            
    # Doing a leave-one-participant-out approach
    else:
        
        # Loop through the 22 unique ppt names
        for not_duplicate_name in ppt_names_not_duplicates:
            
            manifest_name_list = []
            
            # Open a file
            File_object = open(out_dir + ASHS_dir + '/%s_Manifest_File.txt' % (not_duplicate_name),"w+")
               
            # Loop through all 84 names
            for name in complete_participant_names:
                
                # if the "sXXXX" portions don't match, we can add it to our list of names for training 
                if name[:5] != not_duplicate_name:

                    manifest_list += [name]
                    
            # Shuffle the names to avoid ASHS overfitting
            np.random.shuffle(manifest_list)
            
            # Loop through newly stored names with which we will use to make a manifest file 
            for ppt_name in manifest_list:

                if 'CE' in ppt_name:

                    File_object.write('\n%s %s%s.nii.gz %s%s.nii.gz %s/participant_files_ASHS/%s_%s_Left_Side.nii.gz %s/participant_files_ASHS/%s_%s_Right_Side.nii.gz' %(participant_name[:9], out_dir_anatomicals, participant_name[:9], out_dir_anatomicals, participant_name[:9], out_dir, participant_name[:9], 'CE', out_dir, participant_name[:9], 'CE'))

                else:

                    File_object.write('\n%s %s%s.nii.gz %s%s.nii.gz %s/participant_files_ASHS/%s_%s_Left_Side.nii.gz %s/participant_files_ASHS/%s_%s_Right_Side.nii.gz' %(participant_name[:9], out_dir_anatomicals, participant_name[:9], out_dir_anatomicals, participant_name[:9], out_dir, participant_name[:9], 'JF', out_dir, participant_name[:9], 'JF'))
            
            # Close the file
            File_object.close()       
        

segmentation_dir = 'segmentations_CE_ASHS' # Set this string equal to the name of the segmentation directory you want to move the segmentations to, this is CE's segmentation directory as an example

# Loop through the segmentation file lists of one of the tracers (doesn't matter which)
for segmentation in ordered_files_segmentations_anatomical_CE:
    ppt_name = ppt_namer(segmentation)
    right_output_name = '%s/%s/%s/final/%s_right_lfseg_corr_nogray.nii.gz' %(out_dir, ASHS_dir, ppt_name, ppt_name)
    left_output_name = '%s/%s/%s/final/%s_left_lfseg_corr_nogray.nii.gz' %(out_dir, ASHS_dir, ppt_name, ppt_name)
    
    # Load in the right and left segmentations
    vol_right_nii = nib.load(right_output_name)
    vol_right = vol_right_nii.get_data()
    vol_left_nii = nib.load(left_output_name)
    vol_left = vol_left_nii.get_data()
    
    # Move the segmentation volumes to their new directory 
    right_file_name = '%s/%s/%s_right.nii.gz'%(out_dir, segmentation_dir,  ppt_name)
    left_file_name = '%s/%s/%s_left.nii.gz'%(out_dir, segmentation_dir, ppt_name)
    out_nii_right = nib.Nifti1Image(vol_right, vol_right_nii.affine)
    out_nii_left = nib.Nifti1Image(vol_left, vol_left_nii.affine)
    
    # Save the data
    nib.save(out_nii_right, right_file_name)
    nib.save(out_nii_left, left_file_name)
       