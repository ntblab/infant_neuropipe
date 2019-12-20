%% Make a plot of the SFNR across the Y dim of the brain
%
% Take in the SFNR volume of the brain, use the masked volume to determine the extremes of the brain.
% Then average the SFNR of the brain, slice by slice. Plot this gradient
% for all runs for this participant
%
% This might not run on the cluster, in which case do this:
%
% names=dir0('.');
% for ppt = 1:length(names)
%   cd(names(ppt).name)
%   try Analysis_SFNR_gradient
%   catch
%   names(ppt).name
%   end
%   cd('..')
%   close all
% end
%
% C Ellis 12/7/16
function Analysis_SFNR_gradient(gradient_method)

% How do you calculate the gradient? 1=take the mean of all values in a slice, 2= take a sample of 100 voxels from each slice to make a mean
if nargin==0
    gradient_method=1;
end

if isstr(gradient_method)
    gradient_method=str2num(gradient_method);
end

% Preset values
n_samples=100;

%What are the file names
AnalysisFolder='analysis/firstlevel/Exploration';
Files=dir(sprintf('%s/functional*_univariate.feat', AnalysisFolder));

%Iterate through the files
for FileCounter=1:length(Files)
    
    %What are the names of the folders that are useful
    FeatDir=sprintf('%s/%s', AnalysisFolder, Files(FileCounter).name);
    nifti_name=sprintf('%s/sfnr_prefiltered_func_data_st.nii.gz', FeatDir);
    mask_name=sprintf('%s/sfnr_mask_prefiltered_func_data_st.nii.gz', FeatDir);
    
    
    %Load the nifti
    try
        nifti=load_nifti(nifti_name);
        nifti.img=nifti.vol;
        
        mask=load_nifti(mask_name);
        mask.img=mask.vol;
    catch
        nifti=load_untouch_nii(nifti_name);
        mask=load_untouch_nii(mask_name);
    end
    
    % Set all masked out values to zero
    nifti.img(mask.img==0)=nan;
    
    
    % Pull out the mean and std
    
    for y_counter=1:size(nifti.img,2)
        
        % Take a sample of points
        sample=squeeze(nifti.img(:,y_counter,:));
        sample=sample(~isnan(sample));
        
        if gradient_method==2
            if length(sample)>1
                sample=sample(randi([1, length(sample)], 1, n_samples));
            else
                sample=[];
            end
        end
        
        % Get the statistics
        gradient_mean(y_counter)=mean(sample);
        gradient_std(y_counter)=std(sample);
        
    end
    
    % What is the size of the brain
    y_max=nanmax(gradient_mean+gradient_std)*1.1;
    y_max(y_max<size(mask.img,1))=size(mask.img,1);
    
    % What is the slice of the brain you are taking
    z_sums=nansum(nansum(mask.img,2),1);
    [~, mask_tr]=max(squeeze(z_sums));
    
    % Plot the results
    %     figure
    %     subplot('Position', [0.25, 0.55, 0.45, 0.45]);
    %     imagesc(mask.img(:,:,floor(size(mask.img,3)/2)))
    %     axis off
    %
    %     subplot('Position', [0.25, 0.1, 0.45, 0.45]);
    %     x=find(~isnan(gradient));
    %     shadedplot(x, gradient(x)-gradient_std(x), gradient(x)+gradient_std(x), 'b');
    %     alpha(0.1)
    %     hold on
    %     plot(gradient,'b', 'LineWidth',5);
    %     ylim([0, y_max]);
    %     xlim([1, size(mask.img,2)]);
    %     ylabel('SFNR');
    
    % Make a distribution of the SFNR values, plotting the proportion. This
    % doesn't make sense if you don't use the gradient
    % method
    
    if gradient_method==1
        distribution=[];
        bins=50;
        temp_y_max=max(nifti.img(:));
        steps=temp_y_max/bins;
        distribution_steps=(steps/2):steps:temp_y_max-(steps/2);
        
        for y_counter=1:size(nifti.img,2)
            
            % Take a sample of points
            sample=squeeze(nifti.img(:,y_counter,:));
            sample=sample(~isnan(sample));
            
            %Store the distribution
            temp=fliplr(hist(sample, distribution_steps));
            distribution(:,y_counter)=temp/sum(temp);
        end
        
        h=figure;
        colormap('jet');
        imagesc(distribution);
        ticks= round(temp_y_max/10):round(temp_y_max/10):round(temp_y_max/10)*10;
        set(gca, 'YTickLabel', fliplr(ticks), 'YTick', 5:5:50)
        ylabel('Proportion of slice in SFNR');
        saveas(h, sprintf('%s/SFNR_distribution', FeatDir), 'png');
    end
    
    % Plot the gradient over top of the brain
    h=figure;
    x=find(~isnan(gradient_mean));
    shadedplot(x, gradient_mean(x)-gradient_std(x), gradient_mean(x)+gradient_std(x), 'b');
    alpha(0.1)
    hold on
    plot(gradient_mean,'b', 'LineWidth',5);
    hold on
    colormap('gray');
    imagesc(mask.img(:,:,mask_tr))
    alpha(0.2)
    hold on
    ylim([0, y_max]);
    xlim([1, size(mask.img,2)]);
    ylabel('SFNR');
    saveas(h, sprintf('%s/SFNR_gradient_%d', FeatDir, gradient_method), 'png');
    
end
end



function [ha hb hc] = shadedplot(x, y1, y2, varargin)

% SHADEDPLOT draws two lines on a plot and shades the area between those
% lines.
%
% SHADEDPLOT(x, y1, y2)
%   All of the arguments are vectors of the same length, and each y-vector is
%   horizontal (i.e. size(y1) = [1  N]). Vector x contains the x-axis values,
%   and y1:y2 contain the y-axis values.
%
%   Plot y1 and y2 vs x, then shade the area between those two
%   lines. Highlight the edges of that band with lines.
%
%   SHADEDPLOT(x, y1, y2, areacolor, linecolor)
%   The arguments areacolor and linecolor allow the user to set the color
%   of the shaded area and the boundary lines. These arguments must be
%   either text values (see the help for the PLOT function) or a
%   3-element vector with the color values in RGB (see the help for
%   COLORMAP).
%
%   [HA HB HC = SHADEDPLOT(x, y1, y2) returns three handles to the calling
%   function. HA is a vector of handles to areaseries objects (HA(2) is the
%   shaded area), HB is the handle to the first line (x vs y1), and HC is
%   the handle to the second line (x vs y2).
%
%   Example:
%
%     x1 = [1 2 3 4 5 6];
%     y1 = x1;
%     y2 = x1+1;
%     x3 = [1.5 2 2.5 3 3.5 4];
%     y3 = 2*x3;
%     y4 = 4*ones(size(x3));
%     ha = shadedplot(x1, y1, y2, [1 0.7 0.7], 'r'); %first area is red
%     hold on
%     hb = shadedplot(x3, y3, y4, [0.7 0.7 1]); %second area is blue
%     hold off

% plot the shaded area
y = [y1; (y2-y1)]';
ha = area(x, y);
set(ha(1), 'FaceColor', 'none') % this makes the bottom area invisible
set(ha, 'LineStyle', 'none')

% plot the line edges
hold on
hb = plot(x, y1, 'LineWidth', 1);
hc = plot(x, y2, 'LineWidth', 1);
hold off

% set the line and area colors if they are specified
switch length(varargin)
    case 0
    case 1
        set(ha(2), 'FaceColor', varargin{1})
    case 2
        set(ha(2), 'FaceColor', varargin{1})
        set(hb, 'Color', varargin{2})
        set(hc, 'Color', varargin{2})
    otherwise
end

% put the grid on top of the colored area
set(gca, 'Layer', 'top')
grid off
end