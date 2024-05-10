# Short script to enable you to update the parametric timing file based on what is saved as novel and familiarity preference
# 07/29/2021
# add retrieval timing 10/07/2021
# separate nov/fam by category 03/05/2023
# separate nov/fam by delay 03/18/2023

# import
import numpy as np
import sys

# which subject path is it, and which secondlevel folder
subpath=sys.argv[1] # should be the full path
analysis_type=sys.argv[2] # likely just 'default'

# get the timing path
timing=subpath+'/analysis/secondlevel_SubMem_Categories/'+analysis_type+'/Timing/'

# load the event timing file, which has the info we need to make the other files
parametric=np.loadtxt(timing+'SubMem_Categories-Block_Events.txt')

# create new files for both the encoding and the test
for suffix in ['','_Test']:

    # load the novel and familiar pref timing files 
    novel=np.loadtxt(timing+'SubMem_Categories-Condition'+suffix+'_NovelPref.txt')
    familiar=np.loadtxt(timing+'SubMem_Categories-Condition'+suffix+'_FamiliarPref.txt')

    # cycle through lines in the parametric timing file and determine if they are usable
    # (Block_Events may contain encode trials with no looking at test)
    # Based on which suffix we provided, it will grab just the test or just the encode trials
    new_parametric=[]
    for line in range(parametric.shape[0]):
        start=parametric[line,0]

        if start in familiar[:,0] or start in novel[:,0]:

            if not len(new_parametric):
                new_parametric=parametric[line,:].reshape(1,-1) #initialize
            else:
                new_parametric=np.append(new_parametric,parametric[line,:].reshape(1,-1),0)

    # save this as a new parametric file that only contains usable trials from encode or test! 
    np.savetxt(timing+'SubMem_Categories-Condition'+suffix+'_Parametric.txt',new_parametric,fmt='%0.3f')

    # now create the main effect regressor -- it just will have a scaling factor of 1 for all trials
    # this is different than the encode timing file that already exists, because it doesn't include encode trials that weren't matched to test
    new_parametric_main=np.copy(new_parametric)
    new_parametric_main[:,2]=1

    # save!
    np.savetxt(timing+'SubMem_Categories-Condition'+suffix+'_Parametric_MainEffect.txt',new_parametric_main,fmt='%0.3f')

    # Now let's make the familiar and novel timing files for the different categories as well
    for cat in ['Faces','Places','Objects']:
        novel=np.loadtxt(timing+'SubMem_Categories-Condition'+suffix+'_NovelPref.txt')
        familiar=np.loadtxt(timing+'SubMem_Categories-Condition'+suffix+'_FamiliarPref.txt')

        category=np.loadtxt(timing+'SubMem_Categories-Condition_'+cat+'.txt')

        category_fam=[]
        category_nov=[]
        for line in range(category.shape[0]):
            start=category[line,0]

            if start in familiar[:,0]:
                if not len(category_fam):
                    category_fam=category[line,:].reshape(1,-1) #initialize
                else:
                    category_fam=np.append(category_fam,category[line,:].reshape(1,-1),0)

            elif start in novel[:,0]:

                if not len(category_nov):
                    category_nov=category[line,:].reshape(1,-1) #initialize
                else:
                    category_nov=np.append(category_nov,category[line,:].reshape(1,-1),0)

        # Save these out ! 
        np.savetxt(timing+'SubMem_Categories-Condition'+suffix+'_FamiliarPref_'+cat+'.txt',category_fam,fmt='%0.3f')
        np.savetxt(timing+'SubMem_Categories-Condition'+suffix+'_NovelPref_'+cat+'.txt',category_nov,fmt='%0.3f')

    # Finally, make the familiar and novel timing files for different delay lengths (only run this part if we are doing encoding) 
    if suffix == '':
        
        # Now let's make the timing files for the different delay lengths as well
        for lag in ['ShortDelay','LongDelay']:
            novel=np.loadtxt(timing+'SubMem_Categories-Condition'+suffix+'_NovelPref.txt')
            familiar=np.loadtxt(timing+'SubMem_Categories-Condition'+suffix+'_FamiliarPref.txt')

            delay=np.loadtxt(timing+'SubMem_Categories-Condition_'+lag+'.txt')

            delay_fam=[]
            delay_nov=[]
            for line in range(delay.shape[0]):
                start=delay[line,0]

                if start in familiar[:,0]:
                    if not len(delay_fam):
                        delay_fam=delay[line,:].reshape(1,-1) #initialize
                    else:
                        delay_fam=np.append(delay_fam,delay[line,:].reshape(1,-1),0)

                elif start in novel[:,0]:

                    if not len(delay_nov):
                        delay_nov=delay[line,:].reshape(1,-1) #initialize
                    else:
                        delay_nov=np.append(delay_nov,delay[line,:].reshape(1,-1),0)

            # instead of parametric, make this binary 
            delay_fam[:,2]=1
            delay_nov[:,2]=1

            # Save these out ! 
            np.savetxt(timing+'SubMem_Categories-Condition'+suffix+'_FamiliarPref_'+lag+'.txt',delay_fam,fmt='%0.3f')
            np.savetxt(timing+'SubMem_Categories-Condition'+suffix+'_NovelPref_'+lag+'.txt',delay_nov,fmt='%0.3f')
