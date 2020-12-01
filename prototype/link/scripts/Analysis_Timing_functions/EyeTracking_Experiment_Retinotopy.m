%% Summarize eye tracking data for Retinotopy
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
function EyeData=EyeTracking_Experiment_Retinotopy(varargin)

%Get the inputs
EyeData = varargin{1};
Data = varargin{2};
GenerateTrials = varargin{3};

TR = 2; % Assume the TR is 2s

minimum_inclusion_prop = 0.75; % WHat is the minimum amount needed to be considered usable

% Specify the experiment ID
Experiment = 'Retinotopy';

% Make the figure
figure
for IdxCounter=1:length(EyeData.Timecourse.(Experiment))
    
    %What block and repetition does this Idx correspond to
    Idx_Name=EyeData.Idx_Names.(Experiment)(IdxCounter,:);
    Block_Name = sprintf('Block_%d_%d', Idx_Name(1), Idx_Name(2));
    Event_counter = Idx_Name(3);
    
    % What block is this?
    block_type = GenerateTrials.Experiment_Retinotopy.Parameters.BlockNames{Idx_Name(1)};
    
    %Extract the timecourse
    Timecourse=EyeData.Timecourse.(Experiment){IdxCounter};
    
    % Get the timing of each eye tracker frame
    FrameTiming=EyeData.Timing.(Experiment){IdxCounter}(:,1);
    
    % Skip any cases where no frames were collected
    if ~isempty(FrameTiming)
        
        % Get the time stamps in matlab time
        BlockStart = Data.Experiment_Retinotopy.(Block_Name).Timing.InitPulseTime;
        BlockEnd = Data.Experiment_Retinotopy.(Block_Name).Timing.BlockEndTime;
        if isfield(Data.Experiment_Retinotopy.(Block_Name).Timing, 'Block_switch')
            Block_switch = Data.Experiment_Retinotopy.(Block_Name).Timing.Block_switch;
        end
        
        % Get the block start and stop time in eye tracker time
        block_start = (BlockStart * EyeData.EyeTrackerTime.slope) + EyeData.EyeTrackerTime.intercept;
        block_end = (BlockEnd * EyeData.EyeTrackerTime.slope) + EyeData.EyeTrackerTime.intercept;
        if isfield(Data.Experiment_Retinotopy.(Block_Name).Timing, 'Block_switch')
            block_switch = (Block_switch * EyeData.EyeTrackerTime.slope) + EyeData.EyeTrackerTime.intercept;
        end
        
        % What time points do you have measurements for
        time_points = FrameTiming ~= 0;
        
        % When did the block start
        onset_time = FrameTiming(find(time_points == 1, 1));
        
        % Elapsed time for each eye frame
        elapsed_time = (FrameTiming(time_points) - block_start) / EyeData.EyeTrackerTime.slope;
        
        % Pull out the block's gaze data
        gaze_data_block = Timecourse(time_points);
        
        % Turn these times in to seconds
        block_start_elapsed = (block_start - onset_time) / EyeData.EyeTrackerTime.slope;
        block_end_elapsed = (block_end - onset_time) / EyeData.EyeTrackerTime.slope;
        if isfield(Data.Experiment_Retinotopy.(Block_Name).Timing, 'Block_switch')
            block_switch_elapsed = (block_switch - onset_time) / EyeData.EyeTrackerTime.slope;
        end
        
        % Put the data on the subplot. The different events will all go on this
        % one according to their time stamps
        if ((Idx_Name(2) - 1) * 4) + Idx_Name(1) <= (ceil(length(EyeData.Timecourse.(Experiment)) / 8) * 4)
            subplot(ceil(length(EyeData.Timecourse.(Experiment)) / 8), 4, ((Idx_Name(2) - 1) * 4) + Idx_Name(1));
            
            % What is the string named
            if Idx_Name(2) == 1
                name_str = block_type;
            else
                name_str = '';
            end
            
            
            % Remap the data to make it easier to read (originally: left-1, right-2, up-7,
            % down-8, center-3, undetected-6, off-0)
            gaze_data_block(gaze_data_block == 6) = -1; % So it is close to off
            gaze_data_block(gaze_data_block == 3) = 4; % So it is spaced
            
            % Plot the time course
            hold on
            if Event_counter == 1
                plot(elapsed_time, gaze_data_block, 'k');
            else
                plot(elapsed_time, gaze_data_block, 'b');
            end
            
            % Only plot these for the first event
            if Event_counter == 1
                plot([block_start_elapsed, block_start_elapsed], [-2, 9], 'g');
                plot([block_end_elapsed, block_end_elapsed], [-2, 9], 'r');
                if isfield(Data.Experiment_Retinotopy.(Block_Name).Timing, 'Block_switch')
                    plot([block_switch_elapsed, block_switch_elapsed], [-2, 9], 'k');
                end
                
            end
            hold off
            
            yticks([-1, 0, 1, 2, 4, 7, 8]);
            ylim([-2, 9]);
            title(sprintf('%s', name_str));
            
            % Show the response options
            if Idx_Name(1) == 1
                yticklabels({'undetected', 'off screen', 'left', 'right', 'center', 'up', 'down'});
            else
                yticklabels({});
            end
            
            % Report the repetition number of the block
            if Idx_Name(1) == 4
                xlabel(num2str(Idx_Name(2)));
            end
        end
    end
    
    %% Determine what frames are to be excluded
    InvalidCodes = {};
    InvalidCodes{1} = 0;
    InvalidCodes{2} = 6;
    if strcmp(block_type, 'horizontal_first')
        
        % What is excluded depends on whether it is the first or second
        % event
        if Event_counter == 1
            InvalidCodes{3} = 7;
            InvalidCodes{4} = 8;
        else
            InvalidCodes{3} = 1;
            InvalidCodes{4} = 2;
        end
        
    elseif strcmp(block_type, 'vertical_first')
        
        % What is excluded depends on whether it is the first or second
        % event
        if Event_counter == 1
            InvalidCodes{3} = 1;
            InvalidCodes{4} = 2;
        else
            InvalidCodes{3} = 7;
            InvalidCodes{4} = 8;
        end
        
    end
    
    % Store
    EyeData.Exclude.Retinotopy.InvalidCodes{IdxCounter} = InvalidCodes;
    
    % Reduce the threshold for exclusion
    EyeData.Exclude.Retinotopy.Criterion(IdxCounter) = minimum_inclusion_prop;
    
end

% Save the figure
saveas(gcf, sprintf('analysis/Behavioral/Retinotopy_eye_timecourse.png'));

