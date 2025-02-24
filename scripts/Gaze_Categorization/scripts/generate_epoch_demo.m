%% Generate a demo of an epoch supplied for a given coder image list file
%
% Load in an image list from a participant and specify a certain epoch of
% data. Then pull the images associated with that epoch out and convert
% them in to a gif or mp4. mj2 is a reasonable default
%
% Provide the experiment name (don't include 'Experiment_') and the index,
% which is a three element vector referring to the block, repetition and
% epoch number of the experiment
%
% Assumes your current directory is where this script is

function generate_epoch_demo(participant_name, experiment_name, block_number, repetition_number, epoch_number, extension)

input_dir = sprintf('../Frames/%s/', participant_name);
image_list_name = sprintf('../Frames/%s/ImageList.mat', participant_name);
output_name = sprintf('../saved_demos/%s_%s_%d_%d_%d.%s', participant_name, experiment_name, block_number, repetition_number, epoch_number, extension);

frame_time = 0.055; % How long should you wait between frames 

fprintf('Loading %s\n', image_list_name);
fprintf('Saving %s\n', output_name);

% Load in the information on the image list
load(image_list_name);

ImageNames=ImageList.(experiment_name){block_number,repetition_number, epoch_number}; %Get all of the images from the directory

% If this is not a gif then set up the video object
if ~strcmp(extension, 'gif')
    if strcmp(extension, 'mp4')
        format = 'MPEG-4';
    elseif strcmp(extension, 'mj2')
        format = 'Motion JPEG 2000';
    elseif strcmp(extension, 'avi')
        format = 'Uncompressed AVI';
    else
        fprintf('Extension not found, quitting\n');
        return;
    end
    vid_obj = VideoWriter(output_name, format);
    vid_obj.FrameRate=1/frame_time;
    open(vid_obj); % Open the video object
end
    
    
%Iterate through all the images
for Imagecounter=1:length(ImageNames)
    
    %Read the appropriate image in
    iImage=imread([input_dir, ImageNames{Imagecounter}]); %This might not load the names in in the proper order
    
    % If the output is a gif, do this, otherwise try save it as a video
    if strcmp(extension, 'gif')
        
        %Convert image into the appropriate format
        if size(iImage,3)>1 %Only do this if it is 3d data
            [imind,cm] = rgb2ind(iImage,256);
        end
        
        %Write the image to a gif
        if Imagecounter == 1
            if size(iImage,3)>1
                imwrite(imind,cm,output_name,'gif','DelayTime', frame_time, 'Loopcount',inf);
            else %If the image is 2d then do this
                imwrite(iImage,output_name,'gif','DelayTime', frame_time, 'Loopcount',inf);
            end
        else
            if size(iImage,3)>1
                imwrite(imind,cm,output_name,'gif','WriteMode','append');
            else %If the image is 2d then do this
                imwrite(iImage,output_name,'gif','WriteMode','append');
            end
        end
    else
        
        % Convert a grayscale image into RGB
        if size(iImage, 3) == 1
            sensorAlignment = 'gbrg'; % Needed for demosaic function
            iImage = demosaic(iImage, sensorAlignment); 
        end
        
        writeVideo(vid_obj, iImage);
        
        % If this is the last image then close
        if Imagecounter == length(ImageNames)
            close(vid_obj);
        end
    end
end
end