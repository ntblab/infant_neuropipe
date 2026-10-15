# Bootstrap resampling 

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
import pickle

# Load in MPI
from mpi4py import MPI

# Pull out the MPI information, make sure the rank is called rank
comm = MPI.COMM_WORLD
rank = comm.rank
size = comm.size

# Get the base directory
curr_dir = os.getcwd()
os.chdir('../../') # Move into the infant neuropipe root
base_dir = os.getcwd() + '/'
os.chdir(curr_dir) # Come back

# load the hash ID dictionary linking to participant IDs
with open("hash_id_dict.pkl", "rb") as file:
    hash_id_dict = pickle.load(file)

######################################################################################
####### Step 1.5 - bootstrap function 
def bootstrap_dist(data,null_vall=0,nPerm=1000):
    '''Bootstrap resampling for the mean of the data'''
    
    perm_dist=[]
    for perm in range(nPerm):
        sampidx=np.random.choice(np.arange(len(data)),len(data),replace=True)
        randomsamp=np.array(data)[sampidx]
        perm_dist.append(np.mean(randomsamp))
    
    return perm_dist

def get_cond_labels(ppt,feat_name):

    # First, get the names of the z-statistics. This is consistent across participants, so it is okay to use for both
    # get the FSF file that was used in this analysis to determine conditions 
    fsf_file='/%s/subjects/%s/analysis/secondlevel_Saycam/default/%s/design.fsf' %(base_dir,hash_id_dict[ppt],FEAT)

    # Using readlines()
    file1 = open(fsf_file, 'r')
    Lines = file1.readlines()

    # info that is needed here .. 
    timing_start = 'set fmri(custom'
    line_count = 0
    zstat_count=0

    # preset 
    zstat_conds = []

    # Strips the newline character
    for line in Lines:
        line_count += 1

        #print("Line{}: {}".format(line_count, line.strip()))
        if timing_start in line.strip():
            zstat_count+=1

            condition=line.strip().split('Saycam-Condition_')[1].split('.txt')[0]
            zstat_conds.append(condition)

    # name of the conditions for the zstats
    zstat_conds=np.array(zstat_conds)
    
    return zstat_conds


######################################################################################
####### Step 2 - load in the data

ppt=sys.argv[1] # three_yo or nine_yo 
condition=sys.argv[2] # Real, RV, PC
half=sys.argv[3] #first15s, last15s

feat_name='Saycam_IND_15s_inc_contrasts_Z' # name of the FEAT file that was used 

zstat_conds = get_cond_labels(ppt,feat_name)

# get brain mask (whole brain in native space) --- can just binarize the FEAT output zstat 
example_zstat=nib.load('%s/subjects/%s/analysis/secondlevel_Saycam/default/%s.feat/stats/zstat1.nii.gz' %(base_dir,hash_id_dict[ppt],feat_name))
brain_mask = np.zeros(example_zstat.shape)
brain_mask[np.abs(example_zstat.get_fdata())>0]=1
brain_mask = nib.Nifti1Image(brain_mask,example_zstat.affine)
brain_masker= NiftiMasker(brain_mask)
brain_masker.fit_transform(brain_mask)
affine_mat = brain_mask.affine
dimsize = brain_mask.header.get_zooms()

#preset
data=[]
self_other_label=[]

#only load in the data on rank 0
if rank ==0:
    
    # preset
    self_funcs=[]
    other_funcs= []
    
    if ppt =='three_yo':
        # get the idxs (add 1 because FEAT is not zero-indexed!)
        self_idxs = [i+1 for i in range(len(zstat_conds)) if '%s_%s_%s' %(hash_id_dict[ppt].split('_')[1],condition,half) in zstat_conds[i]]
        other_idxs= [i+1 for i in range(len(zstat_conds)) if '%s_%s_%s' %(hash_id_dict['nine_yo'].split('_')[1],condition,half) in zstat_conds[i]]
    
    elif ppt=='nine_yo':
         # get the idxs (add 1 because FEAT is not zero-indexed!)
        self_idxs = [i+1 for i in range(len(zstat_conds)) if '%s_%s_%s' %(hash_id_dict[ppt].split('_')[1],condition,half) in zstat_conds[i]]
        other_idxs= [i+1 for i in range(len(zstat_conds)) if '%s_%s_%s' %(hash_id_dict['three_yo'].split('_')[1],condition,half) in zstat_conds[i]]

    # cycle through zstats from the 'self' condition
    for zstat in self_idxs:
        subject_dir = base_dir + 'subjects/' + hash_id_dict[ppt]
        data_dir = '%s/analysis/secondlevel_Saycam/default' % subject_dir
        feat_dir =f"{data_dir}/{feat_name}.feat/stats"

        # get the zstat data (and reshape)
        functional_name=f"{feat_dir}/zstat{zstat}.nii.gz"
        data_4d = nib.load(functional_name).get_fdata()
        self_funcs.append(data_4d) # append data
        self_other_label.append(1) # append label
    
    # cycle through zstats from the 'other' condition
    for zstat in other_idxs:
        subject_dir = base_dir + 'subjects/' + hash_id_dict[ppt]
        data_dir = '%s/analysis/secondlevel_Saycam/default' % subject_dir
        feat_dir =f"{data_dir}/{feat_name}.feat/stats"

        # get the zstat data (and reshape)
        functional_name=f"{feat_dir}/zstat{zstat}.nii.gz"
        data_4d = nib.load(functional_name).get_fdata()
        other_funcs.append(data_4d) # append data
        self_other_label.append(0) # append label
        
    # stack the data 
    data.append(np.vstack((self_funcs,other_funcs)).transpose(1,2,3,0))
else:
    data += [None]

print("Loaded participant %s \n" % (ppt))

######################################################################################
####### Step 3 - set up the searchlight (note: not a real searchlight, just useful for parallelizing) 

mask=brain_mask.get_fdata()
data=data
sl_rad = 1 
max_blk_edge = 5
pool_size = 1
bcvar=[self_other_label] # Give the self/other labels 

# Create the searchlight object
sl = Searchlight(sl_rad=sl_rad,max_blk_edge=max_blk_edge)

# Distribute the information to the searchlights (note that data is already a list)
sl.distribute(data, mask)

sl.broadcast(bcvar)

######################################################################################
####### Step 4 - define kernel
    
#What is the kernel?
def bootstrap_kernel(data,sl_mask,myrad,bcvar):
    #'''Searchlight kernel that reshapes the data and decides whether there are enough voxels to run the algorithm'''
    
    cond_labels=bcvar[0] # so we know what we are doing
     
    # get the center voxel values ONLY -- since we are running this voxelwise
    self_vals = data[0][1,1,1,np.array(cond_labels)==1] # self
    other_vals = data[0][1,1,1,np.array(cond_labels)==0] # other
  
    # set a random seed
    np.random.seed(0)
    
    # bootstrap resample over distributions for self and other, separately 
    self_bs_dist= np.array(bootstrap_dist(self_vals))
    other_bs_dist= np.array(bootstrap_dist(other_vals))

    # transform to a z-score as the mean of the difference divided by the standard deviation of the difference 
    zscore = np.mean(self_bs_dist - other_bs_dist)/np.std(self_bs_dist - other_bs_dist)

    return zscore

#############################################################
#############################################################
#####Step 4 - go go go searchlight !!
print("Begin SearchLight in rank %s\n" % rank)
all_sl_result = sl.run_searchlight(bootstrap_kernel,pool_size=pool_size)

print("End SearchLight in rank %s\n" % rank)

#save if on rank 0
if rank == 0:

    all_sl_result = all_sl_result.astype('double')
    all_sl_result[np.isnan(all_sl_result)] = 0

    # Save the results!!!
    output_name = '%s/scripts/Saycam/niftis/%s_selfvsother_%s_%s.nii.gz' % (base_dir,hash_id_dict[ppt],condition,half)
    sl_nii = nib.Nifti1Image(all_sl_result, affine_mat)
    hdr = sl_nii.header
    hdr.set_zooms((dimsize[0], dimsize[1], dimsize[2]))
    nib.save(sl_nii, output_name)  # Save

    print('Finished searchlight')
    