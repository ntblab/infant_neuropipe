## Create the functions needed to run participant_summary.ipynb
# Various functions are defined herein that preprocess information generated throughout the pipeline in order to facilitate viewing.

# Edited TY 04032020

import numpy as np
import os
import glob
import nibabel
import matplotlib.pyplot as plt
import matplotlib.image as mpimg
from scipy import stats
from scipy.io import loadmat
import matplotlib
import nilearn.plotting as plotting
matplotlib.rcParams['figure.dpi'] = 100

# Generate the descriptives for this run
def generate_descriptives(func_run):
    
    # Get the functional name (do it differently if it is a pseudorun)
    if len(func_run) == 2:
        func_name = glob.glob('data/nifti/*_functional%s.nii.gz' % func_run)
    else:
        func_name = glob.glob('analysis/firstlevel/pseudorun/*_functional%s.nii.gz' % func_run)
    
    # Get the number of TRs per run 
    nii = nibabel.load(func_name[0])
    
    print('Functional run %s has %d TRs' % (func_run, nii.shape[3]))
    
    # Extract the sfnr from the QA
    QA_Filename = glob.glob('data/qa/qa_events_*_functional%s.bxh.xml' % func_run);
    
    if len(QA_Filename) > 0:
        
        # Open the file and find the secions that define SNR and SFNR
        fid = open(QA_Filename[0], 'r')
        lines = fid.readlines()

        for line in lines:
            if line.find('mean_snr_middle_slice') > -1:
                print('QA SNR: %s' % line[line.find('>') + 1:line.find('</')])
            elif line.find('mean_sfnr_middle_slice') > -1:
                print('QA SFNR: %s' % line[line.find('>') + 1:line.find('</')])

        fid.close()
    else:
        print('No QA file found')
    
    # Extract the number of Confound TRs
    confound_file_name = 'analysis/firstlevel/Confounds/MotionConfounds_functional%s.txt' % func_run 
    
    if os.path.isfile(confound_file_name):
        confound_mat = np.loadtxt(confound_file_name)
        
        if len(confound_mat.shape) == 1:
            confound_mat = confound_mat.reshape((len(confound_mat), 1))
        
        confound_TRs = np.sum(confound_mat,1) > 0
        print('%d time points are excluded (Proportion=%0.2f)' % (np.sum(confound_TRs), np.mean(confound_TRs)))
        
        # Plot the excluded TRs
        Excluded_TR_files = glob.glob('analysis/firstlevel/Confounds/Excluded_TRs_functional%s_*.png' % func_run) 

        file_num = len(Excluded_TR_files)
        
        if file_num > 0: 
            plt.figure()
            for file_counter, Excluded_TR_file in enumerate(Excluded_TR_files):
                plt.subplot(np.ceil(np.sqrt(file_num)), np.ceil(np.sqrt(file_num)), file_counter + 1)

                # Load in the image
                img = mpimg.imread(Excluded_TR_file)

                # Show the image
                plt.imshow(img)
                plt.axis('off')

    else:
        print('No Confound file found')
        
    confound_folder = 'analysis/firstlevel/Confounds/'
    
    # Plot the motion metric data
    motion_metric_file = '%s/MotionMetric_fslmotion_3_functional%s.png' % (confound_folder, func_run)
    if os.path.isfile(motion_metric_file):
        
        plt.figure()
        
        # Load in the image
        img = mpimg.imread(motion_metric_file)

        # Show the image
        plt.imshow(img)
        plt.axis('off')
    else:
        print('Can''t find %s' % motion_metric_file)
    
    centroid_TR_file = '%s/MotionPosition_functional%s.png' % (confound_folder, func_run)
    if os.path.isfile(centroid_TR_file):
        plt.figure()
        
        # Load in the image
        img = mpimg.imread(centroid_TR_file)

        # Show the image
        plt.imshow(img)
        plt.axis('off')
    else:
        print('Can''t find %s' % centroid_TR_file)
    
    
# Look at the feat folder and report summary information    
def summarise_firstlevel(func_run):
       
    feat_folder = 'analysis/firstlevel/functional%s.feat/' % func_run

    # Check if it was excluded    
    if os.path.isfile('analysis/firstlevel/functional%s_excluded_run.fsf' % func_run):
        print('This run was excluded!')
        
    # Cycle through the timing files for this run and output how many blocks and how many were excluded
    timing_files = glob.glob('analysis/firstlevel/Timing/functional%s_*.txt' % func_run)

    for timing_file in timing_files:
        
        # Ignore event or condition files
        if timing_file.find('Event') == -1 and timing_file.find('Condition') == -1:
            
            # When does the name start and end
            start_idx = timing_file.find('functional') + 11 + len(func_run)
            end_idx = timing_file.find('.txt')
            
            block_name = timing_file[start_idx:end_idx]

            # Load timing file and fix its dim if it is wrong
            timing_mat = np.loadtxt(timing_file)

            if len(timing_mat.shape) == 1:
                timing_mat = timing_mat.reshape((1, 3))

            print('%s has %d included blocks and %d excluded blocks' % (block_name, np.sum(timing_mat[:,2] == 1), np.sum(timing_mat[:,2] == 0)))
        
    if len(timing_files) == 0:
        print('No timing files found for this run')
    
    # Look through the feat folder 
    if os.path.isdir(feat_folder):
        
        print('Looking through %s' % feat_folder)

        # Load in the sfnr data and mask to show what was excluded
        sfnr_mask_file = feat_folder + 'sfnr_mask_prefiltered_func_data_st.nii.gz'
        sfnr_map_file  = feat_folder + 'sfnr_prefiltered_func_data_st.nii.gz'    
        
        if os.path.isfile(sfnr_mask_file):

            # Load the files
            sfnr_mask = nibabel.load(sfnr_mask_file).get_data()
            sfnr_map = nibabel.load(sfnr_map_file).get_data()

            # Make slices
            slice_idx = sfnr_mask.shape[2] // 2
            sfnr_mask_slice = np.squeeze(sfnr_mask[:, :, slice_idx])
            sfnr_map_slice = np.squeeze(sfnr_map[:, :, slice_idx])
                        
            # Overlay the slices
            print('SFNR Mean=%0.2f, STD=%0.2f, Max=%0.2f' % (sfnr_map_slice[sfnr_mask_slice == 1].mean(), sfnr_map_slice[sfnr_mask_slice == 1].std(), sfnr_map_slice.max()))
            
            # Set the range 
            sfnr_mask_slice /= sfnr_mask_slice.max()
            sfnr_map_slice /= sfnr_map_slice.max()

            plt.figure()
            plt.title('SFNR volume with masked voxels')
            overlay_slices(sfnr_map_slice, sfnr_mask_slice)
            
        else:
            print('Couldn''t find %s' % sfnr_mask_file)
        
        # Read the output of the log file of the ICA
        ica_dir = feat_folder + 'filtered_func_data.ica/'
        ev_file = ica_dir + 'report/EVplot.png'
        if os.path.isfile(ev_file):
            
            # Load the variance explained
            img = mpimg.imread(ev_file)
            plt.figure()
            plt.imshow(img)
            plt.axis('off')
            plt.show()
            
            # Checking whether any components were found with ICA and then if any were excluded
            component_num = len(glob.glob(ica_dir + 'report/IC_*_prob.png'))

            ica_file = glob.glob(feat_folder + 'feat_ICA-*.out')
            if len(ica_file) > 0:
                # Read the log file
                fid = open(ica_file[0])
                lines = fid.readlines()

                # Walk through the lines 
                Excluded_components=''
                for line in lines:
                    if line.find('Components=') > -1:
                        idx_start = line.find('Components=') + 11
                        idx_end = line.find('\n')
                        Excluded_components = line[idx_start:idx_end]

                print('MELODIC summary\nGenerated %d components, regressing out the following components: %s' % (component_num, Excluded_components))

            else:
                print('MELODIC summary\nGenerated %d components, couldn''t find how many were regressed out' % component_num)
        else:
            print('MELODIC folder not found')
        
        # Load the functional data in and compare voxels between the raw, mcf temporally filtered and filtered_func
        
        func_raw_file = feat_folder + 'prefiltered_func_data_raw.nii.gz'
        func_mc_file = feat_folder + 'prefiltered_func_data_mcf.nii.gz'
        func_intnorm_file = feat_folder + 'prefiltered_func_data_intnorm.nii.gz'
        func_final_file = feat_folder + 'filtered_func_data.nii.gz'
        
        # Pull out the data
        func_raw = nibabel.load(func_raw_file).get_data()[32, 32, 18, :]
        func_mc = nibabel.load(func_mc_file).get_data()[32, 32, 18, :]
        func_intnorm = nibabel.load(func_intnorm_file).get_data()[32, 32, 18, :]
        func_final = nibabel.load(func_final_file).get_data()[32, 32, 18, :]
        
        plt.figure()
        plt.plot(func_raw)
        plt.plot(func_mc)
        plt.plot(func_intnorm)
        plt.plot(func_final)
        plt.ylabel('MR value')
        plt.title('Example voxel time course')
        
        plt.figure()
        plt.plot(stats.zscore(func_raw))
        plt.plot(stats.zscore(func_mc))
        plt.plot(stats.zscore(func_intnorm))
        plt.plot(stats.zscore(func_final))
        plt.legend(('Raw', 'Motion corrected', 'Temporally filtered', 'filtered_func'))
        plt.ylabel('Z score')
        plt.title('Example voxel time course z scored')
        
        # Create the registration plots
        
        #First check manual registration
        manual_reg_file=feat_folder+'reg/Manual_Reg/'
        
        if os.path.isdir(manual_reg_file):
            print('functional%s was manually aligned' % func_run)
        else:
            print('!#!#!#!#!#!#!#! functional%s was not manually aligned !#!#!#!#!#!#!#!' % func_run)
        
        
        example_func_file = feat_folder + 'reg/example_func2highres.nii.gz'
        highres_file = feat_folder + 'reg/highres.nii.gz'
        
        # Load the files
        if os.path.isfile(example_func_file):
            example_func = nibabel.load(example_func_file).get_data()
            highres = nibabel.load(highres_file).get_data()
            
            # Set the range 
            highres /= highres.max()
            example_func /= example_func.max()
        
            # Get slice idxs
            saggital_idx = highres.shape[0] // 2
            coronal_idx = highres.shape[1] // 2
            axial_idx = highres.shape[2] // 2

            plt.figure(figsize=(10,5))
            print('example_func2highres')
            plt.subplot(1, 3, 1)
            example_func_slice = np.squeeze(example_func[saggital_idx, :, :])
            highres_slice = np.squeeze(highres[saggital_idx, :, :])
            overlay_slices(highres_slice, example_func_slice)

            plt.subplot(1, 3, 2)
            example_func_slice = np.squeeze(example_func[:, coronal_idx, :])
            highres_slice = np.squeeze(highres[:, coronal_idx, :])
            overlay_slices(highres_slice, example_func_slice)

            plt.subplot(1, 3, 3)
            example_func_slice = np.squeeze(example_func[:, :, axial_idx])
            highres_slice = np.squeeze(highres[:, :, axial_idx])
            overlay_slices(highres_slice, example_func_slice)
        else:
            print('No registration data found')
    else:
        print('%s not found, skipping' % feat_folder)
    
    
# Read in the univariate file    
def summarise_univariate(func_run):
    
    # Load the feat folder
    feat_folder = 'analysis/firstlevel/Exploration/functional%s_univariate.feat/' % func_run 

    # Check the feat folder
    if os.path.isdir(feat_folder):

        # Load the design matrix
        img = mpimg.imread(feat_folder + 'design.png')
        plt.figure(figsize=(10, 5))
        plt.imshow(img)
        plt.axis('off')
        
        img = mpimg.imread(feat_folder + 'Motion_TaskCorrelation.png')
        plt.figure()
        plt.imshow(img)
        plt.axis('off')
        
        # Open the file
        zstat_file = feat_folder + 'stats/zstat1.nii.gz'
        
        # Load the nifti file
        nii = nibabel.load(zstat_file)
        
        # Load the z stat
        zstat = nii.get_data()
        idx = zstat.shape[2] // 2
        
        # Plot the z stat
        plt.figure()
        plt.title('Z stat: z coord=%d' % idx)
        plt.imshow(zstat[:, :, idx])
        plt.colorbar()
        plt.axis('off')
        plt.show()


# Summarise the behavioral data
def summarise_behavior():
    print('#######################\n#######################\n# Summary across runs #\n#######################\n#######################\n')
    behavioral_folder = 'analysis/Behavioral/'

    # Load analysis timing in and look at some of the outputs
    analysis_timing_file = behavioral_folder + 'AnalysedData.mat'
    if os.path.isfile(analysis_timing_file):
        analysis_timing_all = loadmat(analysis_timing_file, struct_as_record=False)['AnalysedData']
        
        # The data is stored as an object in the third list down
        analysis_timing = analysis_timing_all[0][0]
        
        # Get the TRs per run
        expected_duration= analysis_timing.FunctionalLength[0]
        actual_TRs = analysis_timing.FunctionalLength_Actual[0]
        TR_duration = analysis_timing.TR[0]
        BurnInTRNumber = analysis_timing.BurnInTRNumber[0]
        Included_Runs = analysis_timing.Include_Run[0]
        
        # Calculate the expected number of TRs
        expected_TRs = (expected_duration / TR_duration[:len(expected_duration)]) + BurnInTRNumber
        
        print('Match between expected and actual TR numbers:')
        print('Expected: %s' % expected_TRs)
        print('Actual: %s' % actual_TRs)
        
        # Check to see if there is a mismatch for the included runs
        if np.any((actual_TRs != expected_TRs)[np.where(Included_Runs == 1)]):
            print('!#!#!#!#!#!#!#!\n!#!#!#!#!#!#!#!\n\nRUN TR MISMATCH\n\n!#!#!#!#!#!#!#!\n!#!#!#!#!#!#!#!\n')
        
        # Get the coder names
        if hasattr(analysis_timing.EyeData[0][0], 'Coder_name'):
            coder_names = analysis_timing.EyeData[0][0].Coder_name[0]
            included_coders = analysis_timing.EyeData[0][0].IncludedCoders[0] - 1
            excluded_coders = np.setxor1d(np.arange(len(coder_names)), included_coders)

            print('Eye tracking reliability')

            # Print the included and excluded coders
            print('Included coders:')
            for coder_counter in included_coders:
                print(coder_names[coder_counter][0])

            print('Excluded coders:')
            for coder_counter in excluded_coders:
                print(coder_names[coder_counter][0])
        
        if hasattr(analysis_timing.EyeData[0][0], 'Reliability') and len(analysis_timing.EyeData[0][0].Reliability) > 0:
            Reliability = analysis_timing.EyeData[0][0].Reliability[0][0]

            attributes = Reliability.__dir__()

            for attribute in attributes:
                if attribute[0] is not '_':
                    print('\nReliabilty for ' + attribute)

                    Intraframe = getattr(Reliability, attribute)[0][0].Intraframe_all[0]
                    Interframe = getattr(Reliability, attribute)[0][0].Interframe_all[0]

                    if (np.isnan(Intraframe[excluded_coders]) == False).sum() == 0:
                        excluded_str = ' (No excluded accuracies)'
                    else:
                        excluded_str = ' (excluded score:%0.3f)' % np.nanmean(Intraframe[excluded_coders])

                    print('Intraframe: %0.3f%s' % (np.nanmean(Intraframe[included_coders]), excluded_str))

                    if (np.isnan(Interframe[excluded_coders]) == False).sum() == 0:
                        excluded_str = ' (No excluded accuracies)'
                    else:
                        excluded_str = ' (excluded score:%0.3f)' % np.nanmean(Interframe[excluded_coders])

                    print('Interframe: %0.3f%s' % (np.nanmean(Interframe[included_coders]), excluded_str))
        else:
            print('Reliability information not found')
    else:
        print('Couldn''t find a Analysis_Timing file')
        
    # Print all of the figures that are stored in the behavioral folder starting with Experiment_*
    img_names = glob.glob(behavioral_folder + '*.png')
    
    for img_name in img_names:
        
        # Plot the figure of the image
        img = mpimg.imread(img_name)
        plt.figure()
        plt.imshow(img)
        plt.axis('off')
        img_name_clip = img_name[img_name.rfind('/') + 1:]
        plt.title(img_name_clip)
        
    
        
# Summarise the secondlevel data        
def summarise_secondlevel():
        
    reg_folder = 'analysis/secondlevel/registration.feat/'
    
    highres_file = reg_folder + 'reg/highres2standard.nii.gz'
    standard_file = reg_folder + 'reg/standard.nii.gz'
    
    manual_reg_folder=reg_folder+'reg/Manual_Reg_Standard/'
    
    if os.path.isdir(manual_reg_folder):
        print('Manual registration to standard has been performed')
    else:
        print('!#!#!#!#!#!#!#!\n!#!#!#!#!#!#!#!\n\nCheck that you manually aligned HighRes to Standard\n\n!#!#!#!#!#!#!#!\n!#!#!#!#!#!#!#!\n')
    
    # Load the files
    if os.path.isfile(highres_file):
        
        # Load the images
        highres = nibabel.load(highres_file)
        standard = nibabel.load(standard_file)
        
        # Show the interactive viewer for standard and highres
        fig=plotting.view_img(highres,bg_img=standard,opacity=0.4)
        
    else:
        # Set to nothing
        fig=[]
        print('%s doesn''t exist' % highres_file)
        
    # Check the secondlevel experiment folders that exist
    experiment_folders = glob.glob('analysis/secondlevel_*')    
    
    for experiment_folder in experiment_folders:
        
        print('Found %s' % experiment_folder)
        
        timing_files = glob.glob(experiment_folder + '/default/Timing/*_Only.txt')
        
        for timing_file in timing_files:
            timing_mat = np.loadtxt(timing_file)
            
            if len(timing_mat.shape) == 1:
                timing_mat = timing_mat.reshape((1, 3))
                
            print('%s has %d included blocks and %d excluded blocks' % (timing_file, np.sum(timing_mat[:,2] == 1), np.sum(timing_mat[:,2] == 0)))
    
    # Load the ScanTimeAnalysis data for this participant
    stacked_data_name = 'analysis/Behavioral/ppt_stacked_data.mat'
    if os.path.isfile(stacked_data_name):
        
        if os.path.exists('analysis/secondlevel/FunctionalSplitter_Log') == False or os.path.getmtime('analysis/secondlevel/FunctionalSplitter_Log') > os.path.getmtime('analysis/Behavioral/ppt_stacked_data.mat'):
            print('\n\n***********\n\n**WARNING**:\n\n***********\n\nThis graph relies on an output from ~/scripts/ScanTimeAnalysis.m and from a quick check it looks like this wasn''t run recently. This means this graph might be out of date. You should run that script again with this participant included in order to generate a new ''analysis/Behavioral/ppt_stacked_data.mat'' file for this participant\n\n***********\n')
    
        
        # Load the matlab file
        stacked_data_all = loadmat(stacked_data_name)
        
        # Pull out the data
        stacked_labels = []
        stacked_data = []
        for category_counter in range(len(stacked_data_all['ppt_stacked_data'][0])):
            stacked_labels.append(stacked_data_all['stacked_labels'][0][category_counter][0])
            stacked_data.append(stacked_data_all['ppt_stacked_data'][0][category_counter])

        # Plot the figure
        plt.figure()
        plt.bar(range(len(stacked_data)), stacked_data)
        plt.ylabel('Minutes')
        plt.xticks(np.arange(len(stacked_data)), stacked_labels, rotation=15)
        print(stacked_labels)
    else:
        print('%s doesn''t exist' % stacked_data_name)
            

    print('\n\nReturning an interactive view of the registration from high res to standard for double-checking. If you want to do this for any of the functional to highres registrations, run this block of code (substitute func_run): \n\nimport nibabel as nib \nfunc_run="01a" #which functional? \nfunc=nib.load("analysis/firstlevel/functional%s.feat/reg/example_func.nii.gz" % func_run)\nhighres=nib.load("analysis/firstlevel/functional%s.feat/reg/highres2example_func.nii.gz" % func_run) \nplotting.view_img(func,bg_img=highres,opacity=0.4)')
          
    return fig

def overlay_slices(bottom_slice, top_slice):
    
    # Add an alpha layer for the second slice
    temp_slice = np.zeros((top_slice.shape[0], top_slice.shape[1], 4))
    temp_slice[:, :, 3] = 0.5
    temp_slice[:, :, 0] = top_slice # Put in each layer

    # Plot slices through the midline overlaying the mask
    plt.imshow(np.rot90(bottom_slice), cmap='gray')
    plt.axis('off')
    plt.imshow(np.rot90(temp_slice))
    plt.axis('off')
    plt.show()
    
