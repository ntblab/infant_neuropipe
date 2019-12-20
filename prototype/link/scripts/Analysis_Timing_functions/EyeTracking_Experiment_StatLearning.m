%% Summarize eye tracking data for Statlearning
%
% Pull out gaze behavior and then create both a plot and regressor of it
%
% To add an experiment, create the function which takes in the following
% inputs: EyeData, Data, GenerateTrials. The output is EyeData but probably
% including (any or all) are Weights, ReactionTime and Exclude. Be careful
% when making this that you don't overwrite any of the previous entries
% (Which is why each experiment should have its own subfield of Weights,
% ReactionTime and Exclude)
%
%
function EyeData=EyeTracking_Experiment_StatLearning(varargin)

%Get the inputs
EyeData = varargin{1};
Data = varargin{2};

TR = 2; % Assume the TR is 2s

% Specify the experiment ID
Experiment = 'StatLearning';

% Make the figure
figure
for IdxCounter=1:length(EyeData.Timecourse.(Experiment))
    
    %What block and repetition does this Idx correspond to
    Idx_Name=EyeData.Idx_Names.(Experiment)(IdxCounter,:);
    Block_Name=sprintf('Block_%d_%d', Idx_Name(1), Idx_Name(2));
    
    %Extract the timecourse
    Timecourse=EyeData.Timecourse.(Experiment){IdxCounter};
    
    % Get the timing of each eye tracker frame
    FrameTiming=EyeData.Timing.(Experiment){IdxCounter}(:,1);
    
    % Get the time stamps
    BlockStart = Data.Experiment_StatLearning.(Block_Name).Timing.InitPulseTime;
    BlockEnd = Data.Experiment_StatLearning.(Block_Name).Timing.BlockEndTime;
    
    % What time points do you have measurements for
    time_points = FrameTiming ~= 0;
    
    % When did the block start
    onset_time = FrameTiming(find(time_points == 1, 1));
    
    % Elapsed time for each eye frame
    elapsed_time = (FrameTiming(time_points) - onset_time) / EyeData.EyeTrackerTime.slope;
    
    % Pull out the block's gaze data
    gaze_data_block = Timecourse(time_points);
    
    % Remap the data to make it easier to read
    gaze_data_block(gaze_data_block==0) = 7; % Turn all off screen responses into a different response
    gaze_data_block = 7 - gaze_data_block; % Now subtract 7 so that the lowest number (which was a 5 for present) becomes a 2
    eyes_present = mean(gaze_data_block == 2);
    
    % Get the block start and stop time in eye tracker time
    block_start = (BlockStart * EyeData.EyeTrackerTime.slope) + EyeData.EyeTrackerTime.intercept;
    block_end = (BlockEnd * EyeData.EyeTrackerTime.slope) + EyeData.EyeTrackerTime.intercept;
    
    % Turn these times in to seconds
    block_start_elapsed = (block_start - onset_time) / EyeData.EyeTrackerTime.slope;
    block_end_elapsed = (block_end - onset_time) / EyeData.EyeTrackerTime.slope;
    
    subplot(3, 4, Idx_Name(1));
    
    % Plot the time course
    hold on
    if Idx_Name(2) == 1
        plot(elapsed_time, gaze_data_block);
    else
        % If you reran this block, plot it in red
        plot(elapsed_time, gaze_data_block, 'r');
    end
    hold off
    
    % Change the range so that you can see the responses that matter
    yticks([0, 1, 2]); % Allowed responses are 'off screen', 'undetected', 'present' (reordered after the remapping
    ylim([-1, 3]);
    title(sprintf('%d: %0.2f', Idx_Name(1), mean(eyes_present)));
    
    if mod(Idx_Name(1), 4) == 1
        yticklabels({'off screen', 'undetected', 'present'});
    else
        yticklabels({});
    end
    
end

% Save the figure
saveas(gcf, sprintf('analysis/Behavioral/StatLearning_eye_timecourse.png'));
    
