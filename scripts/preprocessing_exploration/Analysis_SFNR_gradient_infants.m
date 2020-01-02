%% Make a plot of the SFNR across the Y dim of the brain
%
% Take in the SFNR volume of the brain, use the masked volume to determine the extremes of the brain.
% Then average the SFNR of the brain, slice by slice. Plot this gradient
% for all runs for this participant and store the outputs in
% '$PROJ_DIR/results/sfnr_gradient/'
%
% C Ellis 11/1/17
function Analysis_SFNR_gradient_infants(gradient_method)

% How do you calculate the gradient? 1=take the mean of all values in a
% slice, 2= take a sample of N voxels with replacement from each slice to
% make a mean. 3= Take a sample of N without replacement and don't fill in
% a value if you don't have N voxels
if nargin==0
    gradient_method=3;
end

if isstr(gradient_method)
    gradient_method=str2num(gradient_method);
end

% Get the project directory
addpath prototype/link/scripts
globals_struct=read_globals('prototype/link/'); % Load the content of the globals folder

addpath([globals_struct.PACKAGES_DIR, '/NIfTI_tools/']);

% Preset values
n_samples=1000;

%What are the file names
results_folder='results/sfnr_gradient/';
mkdir(results_folder);

% Where is the data stored
data_folder = 'data/methods_data/SFNR_data/';

% Where do you want to store the data
output_dir = 'data/methods_data/SFNR_outputs/';
mkdir(output_dir);

% Get all the functionals
functionals = dir([data_folder, '*.nii.gz']);

%Iterate through the ppts
overall_trend=[];
overall_sfnr=[];
sfnr_names={};
run_TRs=[];
included_names={};
for participant_counter=1:length(functionals)
    
    % What is the participant name
    functional=functionals(participant_counter).name;
    input_name = [data_folder, functional];
    output_name = [output_dir, 'sfnr_', functional];
    output_mask_name = [output_dir, 'sfnr_mask_', functional];
    
    % Run the whole brain sfnr calculation if it doesn't exist already
    if exist(output_name) == 0
        whole_brain_sfnr(input_name, output_dir, '');
    else
        fprintf('Skipping %s, already exists\n', output_name);
    end
    
    %Load the sfnr data
    nifti=load_untouch_nii(output_name);
    mask=load_untouch_nii(output_mask_name);
    
    % Set all masked out values to zero
    mask=double(mask.img);
    volume=double(nifti.img);
    volume(mask==0)=nan;
    
    [~, num_TRs] = unix(['fslnvols ', input_name]);
    
    % Print used participants
    fprintf('%s\n', input_name);
    fprintf('TRs: %d\n\n', str2num(num_TRs));
    
    % Store for later
    sfnr_names{end+1} = input_name;
    run_TRs(end+1) = str2num(num_TRs);
    participant_included=1;
    
    for y_counter=1:size(volume,2)
        
        % Take a sample of points
        sample=squeeze(volume(:,y_counter,:));
        sample=sample(~isnan(sample));
        
        if gradient_method==2
            if length(sample)>1
                sample=sample(randi([1, length(sample)], 1, n_samples));
            else
                sample=[];
            end
        end
        
        if gradient_method==3
            if length(sample)>n_samples
                idxs = datasample(1:length(sample), length(sample), 'Replace', false);
                %idxs = Shuffle(1:length(sample));
                sample=sample(idxs(1:n_samples));
            else
                sample=[];
            end
        end
        
        % Get the statistics
        gradient_mean(y_counter)=nanmean(sample);
        
    end
    
    % Store the data for later
    overall_trend(:, end+1)=gradient_mean;
    overall_sfnr(end+1)=nanmean(volume(:));
    
    
    
end

% What is the median split of the data?
TR_threshold=median(run_TRs);

% Plot the means
figure
hold on
plot(overall_trend(:, run_TRs<TR_threshold), 'Color', [1,0,0])
plot(overall_trend(:, run_TRs>=TR_threshold), 'Color', [0,1,0])
plot(nanmean(overall_trend, 2), 'k', 'LineWidth', 10)
ylim([0, 120]);
xlim([0, 64]);
ylabel('SFNR');
saveas(gcf, sprintf('%s/SFNR_infant_overall_gradient_%d', results_folder, gradient_method), 'eps');

figure
hist(overall_sfnr)
ylabel('SFNR');
saveas(gcf, sprintf('%s/SFNR_infant_overall_%d', results_folder, gradient_method), 'eps');

% Figure out the means of each run and also the means of the peak
run_means = nanmean(overall_trend, 1);

range_radii=1;
run_peak=[];
for run_counter = 1:size(overall_trend, 2)
    
    [~, idx] = nanmax(overall_trend(:,run_counter));
    
    % Set the range and check it is in bounds
    lb=idx-range_radii;
    ub=idx+range_radii;
    
    lb(lb<1)=1;
    ub(ub>size(overall_trend, 1))=size(overall_trend, 1);
    
    % Get the mean of this range and store it
    run_peak(run_counter) = nanmean(overall_trend(lb:ub, run_counter));
    
end

% Save the data
save(sprintf('%s/SFNR_infant_overall_gradient_%d.mat', results_folder, gradient_method));

fprintf('%d sessions, %d runs, min of %d TRs, max of %d, mean of %0.2f\n\n', length(included_names), length(run_TRs), min(run_TRs), max(run_TRs), mean(run_TRs));

% Median split the brain and then average the first and second half

back_vs_front = zeros(size(overall_trend,2), 2);
for ppt_counter = 1:size(overall_trend, 2)
    sfnr_vals = overall_trend(:, ppt_counter);
    
    % Is this the sfnr values
    if sum(isnan(sfnr_vals)==0) > 0
      
        middle_idx = median(find(isnan(sfnr_vals) == 0));
          
        % Get the front and back of the brain separately
        back_vs_front(ppt_counter, 1) = nanmean(sfnr_vals(1:floor(middle_idx)));
        back_vs_front(ppt_counter, 2) = nanmean(sfnr_vals(ceil(middle_idx):end));
       
        
    else
        % Store the data
        back_vs_front(ppt_counter, 1) = nan;
        back_vs_front(ppt_counter, 2) = nan;
    end
end

% write the output to a text file
dlmwrite(sprintf('%s/SFNR_infant_back_vs_front_%d.txt', results_folder, gradient_method), back_vs_front);

min_TRs= 30;
fprintf('Infant mean for runs over %d TRs: %0.3f\n\n', min_TRs, nanmean(run_means(run_TRs>min_TRs)));

end
