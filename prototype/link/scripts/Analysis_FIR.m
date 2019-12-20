%Analyse the FIR outputs
%
% Creates FIR analyses for analysis of the participant's HRF
%
%Searches through the neuropipe folder to identify names of files and
%folders and determines whether appropriate names exist.
%
%Specifically to use this there must be the following feat folders:
%   analysis/firstlevel/Exploration/functionalXX_univariate.feat
%   analysis/firstlevel/Exploration/functionalXX_fir.feat
%
% This will then take the appropriate files and make a plot showing the
% timelocked activation of the raw data, FIR model data and the design
% matrix. The figure will be outputted to analysis/firstlevel/functionalXX_fir.feat
%
% The input is the way that masking is done:
% 0: use the univariate results as a mask,
% 1:Take the first 20 voxels of the y dim,
% 2:Exclude voxels below a variance threshold hold and then use
% the back of the brain,
% 3: take the highest pe values
% $PATHNAME: If the variable is a name then this will be the mask loaded in
% for selection
%
% C Ellis 12/11/16
% Added Mask name inputs 6/27/27

function Analysis_FIR(Masktype, functional_run)

%0: use the univariate results as a mask, 1:Take the first 20 voxels of the y dim, 2:Exclude voxels below a variance threshold hold and then use the back of the brain, 3: take the highest pe values
if nargin==0
    Masktype='2';
end

if nargin<2
    functional_run='';
else
    % Fix leading zeros if this isn't a string
    if ~isstr(functional_run)
        functional_run=sprintf('%02d', functional_run);
    end
end

% Is it a string and a number?
if isstr(Masktype) && all(isstrprop(Masktype, 'digit'))
    Mask_output_name=Masktype;
    Masktype=str2num(Masktype);
else
    
    % Report an error with the mask path
    if exist(Masktype)==0
        fprintf('%s not found. Exiting\n', Masktype);
        return
    end
    
    Mask_output_name=Masktype(max(strfind(Masktype, '/'))+1:strfind(Masktype, '.nii')-1);
end

% addpath scripts
globals_struct=read_globals; % Load the content of the globals folder
addpath([globals_struct.PACKAGES_DIR, '/NIfTI_tools/'])

%What is the participant name
path=cd;
Participant=path(max(strfind(path, '/'))+1:end);

%What are the file names
AnalysisFolder='analysis/firstlevel/Exploration';

% Where is the data stored?
if length(functional_run) == 2
    DataFolder='data/nifti';

elseif length(functional_run) == 3
    DataFolder='analysis/firstlevel/pseudorun';
    fprintf('Assuming %s is a pseudorun\n', functional_run);
else
    fprintf('functional%s is not expected, aborting\n', functional_run);
    return
end

% Get all the files. Use only this run if necessary
fprintf('Looking for %s/%s_functional%s.nii.gz\n', DataFolder, Participant, functional_run);
Files=dir(sprintf('%s/%s_functional%s.nii.gz', DataFolder, Participant, functional_run));

%Hard code some features
TR=2;
BurnoutTRs=3; %How many TRs are you taking after the block ends?
PercentageIncluded=5; %What percentage of voxels should be included in the mask
PE_SelectionMethod=1; %Do you want to select based on: 1) mean PE, 2) std PE, 3) max PE

%Movie attributes:
makeVideo=0;
MovieFrameRate=15;
colors=[1, 0, 0; 0, 0, 0; 0, 1, 0];

%What are the names of the folders that are useful
File=Files(1).name;
FunctionalName=File(strfind(File, 'functional'):strfind(File, '.nii')-1);
UnivariateFolder=sprintf('%s/%s_univariate.feat', AnalysisFolder, FunctionalName);
FIRFolder=sprintf('%s/%s_fir.feat', AnalysisFolder, FunctionalName);
timingFile=sprintf('%s/%s.txt', AnalysisFolder, FunctionalName); %The original timing file for the experiment

fprintf('Using %s to make masktype %s\n', FIRFolder, Mask_output_name);

%If the necessary directories exist then run this.
if isdir(FIRFolder)
    
    %What files will be generated
    designFile=sprintf('%s/design', UnivariateFolder); %What is the design matrix of the univariate file
    univariateFile=sprintf('%s/stats/zstat1.nii.gz', UnivariateFolder); %The path to the zstat of task versus rest
    FIRDir=sprintf('%s/stats', FIRFolder); %The fir stats folder, where you will find the pe# volumes
    rawFile=sprintf('%s/%s', DataFolder,  File);
    
    %Load in the real data for the participant
    raw_nii=load_untouch_nii(rawFile);
    
    %What is the variance of the raw data across time?
    variance_volume=std(double(raw_nii.img),[],4);
    
    %Read in the timing files to overlay the data, timelocked to the event
    %onsets
    timing=textread(timingFile);
    onsets=(timing((timing(:, 3)>0),1)/TR)+1; %What TR idx do the blocks start on?
    durations=(timing((timing(:, 3)>0),2)/TR);
    
    %Read in the design matrix
    %This might not work, if not then do it on the cluster
    unix(sprintf('Vest2Text %s %s', [designFile, '.mat'], [designFile, '.txt']));
    designMat=textread([designFile, '.txt']);
    
    %If the last column is just zeros then remove it
    if all(designMat(:,end)==0)
        designMat=designMat(:,1:end-1);
    end
    
    %Calculate the average brain relative to onset
    for BlockCounter=1:length(onsets)
        %When does this block end?
        end_idx=onsets(BlockCounter)+min(durations)+BurnoutTRs-1;
        
        if BlockCounter==1
            %Create it if it doesnt already exist
            averaged=raw_nii.img(:,:,:,onsets(BlockCounter):end_idx);
        else
            %Sum
            averaged=averaged+raw_nii.img(:,:,:,onsets(BlockCounter):end_idx);
        end
        
    end
    
    %Divide by N to make the average
    averaged=averaged/length(onsets);
    
    %These should all be the same so you dont need to do it
    design=designMat(onsets(BlockCounter):end_idx);
    
    %Load in the pe data
    peFiles=dir(sprintf('%s/pe*.nii.gz', FIRDir));
    
    % Calculate the total of PE files
    peTotal=length(dir(sprintf('%s/zstat*.nii.gz', FIRDir)));
    
    fprintf('Found %d pe files\n\n', peTotal);
    
    if makeVideo == 1
        %Set up for the movie
        daObj=VideoWriter(sprintf('%s/Highest_PE_Voxels', FIRFolder), 'Motion JPEG 2000'); %Open the movie object
        daObj.FrameRate=MovieFrameRate;
        RotationPosition=[linspace(0,360,30)', linspace(45,45,30)'];
        RotationPosition=RotationPosition(1:end-1,:); %Remove the last line so that it flows consistently
        
        %Open this up
        open(daObj);
        h=figure;
    end
    
    for peCounter=1:peTotal
        
        filename=sprintf('%s/pe%d.nii.gz', FIRDir, peCounter);
        
        %Load the nifti for the pe value
        pe_nii=load_untouch_nii(filename);
        
        % Preset the size
        if exist('pe')~=1
            pe=zeros([size(pe_nii.img), peTotal]);
            psc_pe=zeros([size(pe_nii.img), peTotal]);
        end
        
        %Store the pe
        pe(:,:,:,peCounter)=pe_nii.img;
        
        filename=sprintf('%s/psc_pe%d.nii.gz', FIRDir, peCounter);
        
        %Load the nifti for the scaled pe value
        pe_nii=load_untouch_nii(filename);
        
        %Store the size
        psc_pe(:,:,:,peCounter)=pe_nii.img;
        
        % Do you want to make a video
        if makeVideo == 1
            
            %Which voxels have the highest value
            Threshold=prctile(abs(pe_nii.img(pe_nii.img(:)~=0)), 100-PercentageIncluded);
            
            %Select the voxels with the highest PE value
            selected=zeros(size(pe_nii.img));
            selected(abs(pe_nii.img(:))>Threshold)=1;
            
            %Pull out the indexes
            [x,y,z]=ind2sub(size(selected), find(selected==1));
            
            %What sign is the stimulus (and thus how should it be colored)?
            colour=sign(pe_nii.img).*selected+2;
            
            colourLabel=zeros(length(x),3);
            for VoxelCounter=1:length(x)
                colourLabel(VoxelCounter,:)=colors(colour(x(VoxelCounter), y(VoxelCounter), z(VoxelCounter)),:);
            end
            
            %Rotate and record the video frame
            scatter3(x,y,z,[], colourLabel, 'filled');
            xlabel('x'); ylabel('y'); zlabel('z');
            xlim([1 64]); ylim([1 64]); zlim([1 36]);
            title(sprintf('TR: %d', peCounter));
            
            for RotationCounter=1:size(RotationPosition,1)
                view(RotationPosition(RotationCounter,:)); drawnow;
                writeVideo(daObj,getframe(h)); %use figure, since axis changes size based on view
            end
        end
    end
    
    %End the video
    if makeVideo == 1
        close(daObj);
    end
    
    % Determine which volume to threshold for the mask
    
    
    % Load in the specified mask
    mask=[];
    Threshold=0;
    if any(isstrprop(Masktype, 'alpha'))
        nifti=load_untouch_nii(Masktype);
        
        % Set this file as the binary mask
        mask = nifti.img==1;
        % Use the univariate activation
    elseif isdir(UnivariateFolder) && Masktype==0
        
        univariate_nifti=load_untouch_nii(univariateFile);
        
        % Set this file as the binary mask
        mask = zeros(size(pe(:,:,:,1)));
        Threshold=prctile(abs(univariate_nifti.img(abs(univariate_nifti.img)>0)), 100-PercentageIncluded);
        mask(abs(univariate_nifti.img(:)) >= Threshold)=1;
        
        % Take the back half first
        mask(:,20:end,:)=0;
        
        %Use the back half of the brain (and potentially ignore highly
        %variable voxels)
    elseif Masktype==1 || Masktype==2
        
        % Set the mask size
        mask=ones(size(pe(:,:,:,1)));
        
        % Make brain shape
        mask(pe(:,:,:,1)==0)=0;
        
        % Take the back half first
        mask(:,20:end,:)=0;
        
        %Exclude voxels that are below a variance threshold
        if Masktype==2
            
            Threshold=prctile(variance_volume(mask==1), 100-PercentageIncluded);
            mask(abs(variance_volume(:))<Threshold)=0;
        end
        
        %Use the highest pe values
    elseif Masktype==3
        
        %Take the mean over time
        if PE_SelectionMethod==1
            temp_mask=mean(pe,4);
            
            %Take the std over time
        elseif PE_SelectionMethod==2
            temp_mask=std(pe,[],4);
            
            %Take the max over time
        elseif PE_SelectionMethod==3
            
            %Iterate through the voxels and find the max
            for x=1:size(pe,1)
                for y=1:size(pe,2)
                    for z=1:size(pe,3)
                        temp_mask(x,y,z)=max(pe(x,y,z,:));
                    end
                end
            end
        end
        
        %If Masktype is 3 then it will just use that nifti
        Threshold=prctile(abs(temp_mask(:)), 100-PercentageIncluded);
        
        mask=zeros(size(temp_mask));
        mask(abs(temp_mask(:))>=Threshold)=1;
    end
    
    %Pull out the indexes
    [x,y,z]=ind2sub(size(mask), find(mask==1));
    
    %Display the selected voxels
    h=figure;
    scatter3(x,y,z)
    xlabel('x'); ylabel('y'); zlabel('z');
    xlim([1 size(pe,1)]); ylim([1 size(pe,2)]); zlim([1 size(pe,3)]);
    title(sprintf('Mask type %s, threshold %0.2f', Masktype, Threshold));
    
    Selected_Voxel_name=sprintf('%s/Selected_Voxels_Masktype_%s', FIRFolder, Mask_output_name);
    Evoked_Voxel_name = sprintf('%s/Evoked_Response_Masktype_%s', FIRFolder, Mask_output_name);
    
    saveas(h, Selected_Voxel_name, 'fig');
    
    %Get the masked voxels
    masked_pe=zeros(length(x), size(pe, 4));
    masked_psc_pe=zeros(length(x), size(pe, 4));
    masked_averaged=zeros(length(x), size(averaged, 4));
    for voxelcounter=1:length(x)
        masked_pe(voxelcounter, :)=squeeze(pe(x(voxelcounter), y(voxelcounter), z(voxelcounter),:));
        masked_psc_pe(voxelcounter, :)=squeeze(psc_pe(x(voxelcounter), y(voxelcounter), z(voxelcounter),:));
        masked_averaged(voxelcounter, :)=squeeze(averaged(x(voxelcounter), y(voxelcounter), z(voxelcounter),:));
    end
    
    pe_z=zscore(mean(masked_pe));
    averaged_z=zscore(mean(masked_averaged));
    design_z=zscore(design);
    
    if length(design_z) < length(pe_z)
        fprintf('More elements in pe_z than the design. Assume you miss counted the number of confounds\n\n')
        pe_z=pe_z(1:length(design_z));
    end
    
    %Plot the normalized responses
    if length(pe_z)>3 && length(averaged_z)>3 && length(design_z)>3
        h=figure;
        hold on
        plot(pe_z, 'r')
        plot(averaged_z, 'b')
        plot(design_z, 'g')
        title(sprintf('pe-design r: %0.02f, pe-averaged r: %0.02f', corr(pe_z', design_z(1:length(pe_z))'), corr(pe_z', averaged_z(1:length(pe_z))')));
        ylabel('Normalized Evoked response')
        xlabel('TRs')
        legend({'pe', 'averaged', 'predicted'}, 'Location', 'South')
        
        %Save
        saveas(h, Evoked_Voxel_name, 'png');
    end
    
    % Save the number of onsets used here
    num_onsets = length(onsets);
    
    % Clear for saving
    h=[];
    
    % Save the data
    filename=sprintf('%s/FIR_data_Masktype_%s.mat', FIRFolder, Mask_output_name);
    fprintf('Saving %s\n', filename);
    save(filename);
end




