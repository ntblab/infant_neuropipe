#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Create the vgg weights for a movie file automatically

Take in a movie and a TR duration to create a TR by TR regressor for different properties of the stimulus.

Calculate the following properties:
    Luminance
    Complexity
    VGG (max pooling for layers )

Requires openCV and Keras 

Created by C Ellis 5/23/18
"""

import cv2
import numpy as np
import matplotlib.pyplot as plt
from pylab import *
import skimage.measure
import sys
import os
from tensorflow import keras
from keras.models import Model
import math

def run_vgg(img, base_model):
    
    # Define the outputs that you want from the model
    model = Model(inputs=base_model.input, outputs=[base_model.get_layer('block1_pool').output,
                                               base_model.get_layer('block2_pool').output,
                                               base_model.get_layer('block3_pool').output,
                                               base_model.get_layer('block4_pool').output,
                                               base_model.get_layer('block5_pool').output,
                                               base_model.get_layer('fc1').output,
                                               base_model.get_layer('fc2').output,
                                               base_model.get_layer('predictions').output])
    
    # Run the model on the img and get the layer specific information
    b1p, b2p, b3p, b4p, b5p, fc1, fc2, pred = model.predict(img)
    
    # Return VGG outputs
    return b1p, b2p, b3p, b4p, b5p, fc1, fc2, pred

def run_vgg_max_conv(img, base_model):
    
    # Define the outputs that you want from the model
    model = Model(inputs=base_model.input, outputs=[base_model.get_layer('block1_conv2').output,
                                               base_model.get_layer('block2_conv2').output,
                                               base_model.get_layer('block3_conv4').output,
                                               base_model.get_layer('block4_conv4').output,
                                               base_model.get_layer('block5_conv4').output,
                                               base_model.get_layer('fc1').output,
                                               base_model.get_layer('fc2').output,
                                               base_model.get_layer('predictions').output])
    
    # Run the model on the img and get the layer specific information
    b1c, b2c, b3c, b4c, b5c, fc1, fc2, pred = model.predict(img)
    
    # Return VGG outputs
    return b1c, b2c, b3c, b4c, b5c, fc1, fc2, pred

def run_inception(img, base_model):
    
    # Define the outputs that you want from the model. Note, because these names are not labelled explicitly, every time you reload the model, the numbers change.
    # For reference, the 5th and 6th are in a branch, so are the 8th and 9th
    model = Model(inputs=base_model.input, outputs=[base_model.get_layer('average_pooling2d_1').output,
                                               base_model.get_layer('average_pooling2d_2').output,
                                               base_model.get_layer('average_pooling2d_3').output,
                                               base_model.get_layer('average_pooling2d_4').output,
                                               base_model.get_layer('average_pooling2d_5').output,
                                               base_model.get_layer('average_pooling2d_6').output,
                                               base_model.get_layer('average_pooling2d_7').output,
                                               base_model.get_layer('average_pooling2d_8').output,
                                               base_model.get_layer('average_pooling2d_9').output])
    
    # Run the model on the img and get the layer specific information
    a1p, a2p, a3p, a4p, a5p, a6p, a7p, a8p, a9p = model.predict(img)
    
    # Return the outputs
    return a1p, a2p, a3p, a4p, a5p, a6p, a7p, a8p, a9p

def run_inception_max(img, base_model):
    
    # Define the outputs that you want from the model. Note, because these names are not labelled explicitly, every time you reload the model, the numbers change. The predictions layer is the fully connected layer using the softmax (rather than relu like in VGG)
    model = Model(inputs=base_model.input, outputs=[base_model.get_layer('max_pooling2d_1').output,
                                                    base_model.get_layer('max_pooling2d_2').output,
                                                    base_model.get_layer('max_pooling2d_3').output,
                                                    base_model.get_layer('max_pooling2d_4').output,
                                                    base_model.get_layer('predictions').output,
                                                   ])
    
    # Run the model on the img and get the layer specific information
    b1p, b2p, b3p, b4p, fc1 = model.predict(img)
    
    # Return the outputs
    return b1p, b2p, b3p, b4p, fc1
    

# Specify the movie to be loaded in:
if len(sys.argv) > 1:
    cap_idx = sys.argv[1]
else:
    cap_idx = 'MickeyMouseBirthday.mp4'

if len(sys.argv) > 2:
    tr_duration = float(sys.argv[2])
else:
    tr_duration = 2

# Are you storing the data in the alt folder?
if len(sys.argv) > 3:
    output_dir = sys.argv[3]
else:
    output_dir = 'group/PlayVideo/vgg_weights/'   
    
# Is this using the max convolution layers or the pooling layers?
if len(sys.argv) > 4:
    is_max_pooling = int(sys.argv[4])
else:
    is_max_pooling = 1
    
# Is this using vgg 19 or inception. Set to -1 if doing luminance
if len(sys.argv) > 5:
    is_vgg19 = int(sys.argv[5])
else:
    is_vgg19 = 1
    
# Are you using random weights or image net
if len(sys.argv) > 6:
    regressor_seed = sys.argv[6]
else:
    regressor_seed = '' 
    
if regressor_seed is '':
    weights = 'imagenet'
else:
    print('Using random weights! Saving with the suffix: %s' % regressor_seed)
    weights = None


# Print information
print('Running', str(cap_idx))
print('TR duration: %d' % tr_duration)
print('What is the output directory: %s' % output_dir)
print('What type of output: %s' % ['convolution layer', 'max pooling layer'][is_max_pooling])
print('Use the %s network' % ['inception', 'VGG'][is_vgg19])

# Capture device    
cap = cv2.VideoCapture(cap_idx)

# Get the fps
fps = np.round(cap.get(cv2.CAP_PROP_FPS))
temporal_resolution = fps  # Based on the frame number

# Get the frame number
frame_number = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

# Preset
Regressors_all = {}
Regressors_all['luminance']  = []
Regressors_all['compression'] = []
frame_4d = []

# Iterate through the frames
if cap_idx.find('Mickey') > 0:
    print('Triming movie because it has a border')

for frame_counter in range(1, frame_number + 1): 
    
    cap.set(cv2.CAP_PROP_POS_FRAMES, frame_counter)

    # Get the last frame
    if frame_counter == 2:
        last_frame = frame

    # Capture the image
    ret, frame = cap.read()

    # If the frame is not found, use the last one, otherwise create files here
    if frame is None:
        print('Frame %d missing, interpolating from previous frame' % frame_counter)
        frame = last_frame
    else:
        # Crop to exclude the border and make the frame square (measured manually).
        if cap_idx.find('Mickey') > 0:
            frame = frame[1:-1, 162:1118, :]
        elif cap_idx.find('alt_movie.mp4') > 0:
            frame = frame[1:-1, 185:1108, :]
        elif cap_idx.find('alt_movie_2.mp4') > 0:
            frame = frame[1:-1, 5:-5, :]
        elif cap_idx.find('Child_Play') > 0:
            frame = frame[50:-50, 150:-150, :]
        
    ## Calculate the luminance
    
    #Convert the frame into YCbCr
    frame_ycbcr = cv2.cvtColor(frame, cv2.COLOR_BGR2YCR_CB)

    # Append the average luminance of the frame
    Regressors_all['luminance'] += [np.mean(frame_ycbcr[:, :, 0])]
        
    ## Calculate the complexity of the frame
    
    # create a temp name    
    random_tag = np.random.randint(100000)
    filename = 'temp_%d_.png' % random_tag

    # Save the image as a png
    cv2.imwrite(filename, frame)
    
    # How big is the image in bytes
    Regressors_all['compression'] += [os.stat(filename).st_size]
    
    # Delete the image
    os.remove(filename)
    
    # Resize to fit (224 is the typical)
    if is_vgg19 == 1:
        frame = cv2.resize(frame, (224, 224))
    else:
        frame = cv2.resize(frame, (299, 299))
    
    # Store the data as a list (so it is read as 4d by numpy)
    frame_4d += [frame]
    
    # Add a counter print
    if np.mod(len(frame_4d), 500) == 0:
        print(len(frame_4d))
        
print('Finished reading in %d frames' % len(frame_4d))

# Release the movie textures
cap.release()

## Run it through VGG and store the different layers separately

# Convert the list of frames into an array
frame_num = len(frame_4d)
frame_array = np.zeros((frame_num, frame_4d[0].shape[0], frame_4d[0].shape[1], frame_4d[0].shape[2]))
for frame_counter in range(frame_num):
    frame_array[frame_counter, :, :, :] = frame_4d[frame_counter]

# Reset for memory concerms
frame_4d=[]
    
if is_vgg19 == 1:
    # Make the VGG model
    print('Running VGG')

    # Create the base model for running VGG in keras
    base_model = keras.applications.vgg19.VGG19(include_top=True, 
                                                weights=weights, 
                                                input_tensor=None, 
                                                input_shape=None, 
                                                pooling=None, 
                                                classes=1000)

    # Run VGG
    if is_max_pooling == 1:
        Regressors_all['vgg_b1p'], Regressors_all['vgg_b2p'], Regressors_all['vgg_b3p'], Regressors_all['vgg_b4p'], Regressors_all['vgg_b5p'], Regressors_all['vgg_fc1'], Regressors_all['vgg_fc2'], _ = run_vgg(frame_array, base_model)
    else:
        print('Running convolutional layers')
        Regressors_all['vgg_b1c'], Regressors_all['vgg_b2c'], Regressors_all['vgg_b3c'], Regressors_all['vgg_b4c'], Regressors_all['vgg_b5c'], Regressors_all['vgg_fc1'], Regressors_all['vgg_fc2'], _ = run_vgg_max_conv(frame_array, base_model)

else:
    
    # Make the inception model
    print('Running inception')
    
    # Create the base model for running inception
    base_model = keras.applications.inception_v3.InceptionV3(include_top=True, 
                                                             weights=weights, 
                                                             input_tensor=None, 
                                                             input_shape=None, 
                                                             pooling=None, 
                                                             classes=1000)
    
    # Store the outputs of the model
    if is_max_pooling == 1:
        Regressors_all['inc_b1p'], Regressors_all['inc_b2p'], Regressors_all['inc_b3p'], Regressors_all['inc_b4p'], Regressors_all['inc_fc1'] = run_inception_max(frame_array, base_model)
    else:
        Regressors_all['inc_a1p'], Regressors_all['inc_a2p'], Regressors_all['inc_a3p'], Regressors_all['inc_a4p'], Regressors_all['inc_a5p'], Regressors_all['inc_a6p'], Regressors_all['inc_a7p'], Regressors_all['inc_a8p'], Regressors_all['inc_a9p'] = run_inception(frame_array, base_model)

print('What is the shape of each array')        
for key in Regressors_all.keys():
    try:
        print(key, Regressors_all[key].shape)
    except:
        print(key, len(Regressors_all[key]))
        
# Plot a frame across all the layers to get an idea of the filters being used
frame_idx = 1500 # What frame do you want to plot
frame = np.copy(frame_array[frame_idx, :, :, :])
frame[:, :, 0] = frame_array[frame_idx, :, :, 2]
frame[:, :, 1] = frame_array[frame_idx, :, :, 1]
frame[:, :, 2] = frame_array[frame_idx, :, :, 0]

# Are you plotting (can't on the cluster usually)
plotting = 0
if plotting == 1:
    plt.imshow(frame / 255)
    plt.axis('off')
    plt.savefig('%s/frame_%d.png' % (output_dir, frame_idx))
    
    for regressor_key in ['vgg_b1p', 'vgg_b2p', 'vgg_b3p', 'vgg_b4p', 'vgg_b5p']:
        for filter_num in range(3):
            
            # Pull out the 
            regressor_frame = Regressors_all[regressor_key][frame_idx, :, :, filter_num]
            
            plt.imshow(regressor_frame)
            plt.axis('off')
            plt.savefig('%s/regressor_%s_filter_%d%s.png' % (output_dir, regressor_key, filter_num, regressor_seed))
        

# Reset for memory concerns
frame_array = []


# Vectorize each regressor to be TR by feature (for luminance the features are different frames, for vgg it is filters x coordinate x frame) 
tr_number = int((frame_num / fps) / tr_duration)  # How many TRs are there?
frame_window_size = int(np.round(fps * tr_duration))

print('Saving data')

for regressor_key in Regressors_all:
    
    # Reshape the data to be TR by feature. For the luminance and compression regressors this is trivial, for VGG it is a bit more complicated
    if (is_vgg19 == 0 or is_vgg19 == 1) and regressor_key != 'luminance' and  regressor_key != 'compression':
        
        print('%s has the dimensionality:' % regressor_key)
        print(Regressors_all[regressor_key].shape)
        
        # Reshape the regressor to be a movie frame by unit feature matrix
        reg_vec = Regressors_all[regressor_key].reshape(Regressors_all[regressor_key].shape[0], int(np.prod(Regressors_all[regressor_key].shape[1:])))
        
    else:
        
        # Reshape the regressor to be a tr by unit feature matrix by concatenating all the frames within a TR into a long list.
        # Preset the array
        reg_vec = np.zeros((tr_number, len(np.asarray(Regressors_all[regressor_key][0:int(frame_window_size)]).flatten()))) 

        for tr in range(tr_number):

            # Get the lower and upper index
            l_idx = int(tr * frame_window_size)
            u_idx = int((tr + 1) * frame_window_size)
            if u_idx >= frame_num:
                u_idx = int(frame_num - 1)  # Bound

            # Store the TR
            reg_vec[tr, :] = np.asarray(Regressors_all[regressor_key][l_idx:u_idx]).flatten()
    
    # Save this for later (be cautious here, these files are large)
    np.save('%s/%s%s.npy' % (output_dir, regressor_key, regressor_seed), reg_vec)
        
    # Clear the data to save space
    Regressors_all[regressor_key] = []
    reg_vec = []    
print('Outputting %s/%s%s.npy\nFinished' % (output_dir, regressor_key, regressor_seed))        
