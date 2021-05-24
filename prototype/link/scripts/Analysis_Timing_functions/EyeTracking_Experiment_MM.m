%% Summarize eye tracking data for Movie Memory
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
% Same as PlayVideo with some name changes
% T Yates 04/03/2019
% Now reference Timing.TR not Movie_1.Timing.TR -> because the movie ends on
% an even number, it's possible that we may miss the last trigger and this
% could cause EyeTracking_Analysis to crash
% T Yates 05/09/2019
% Added drop condition exclusions C Ellis 09/16/19
% Save a file that lists the mapping of movies to block numbers
% T Yates 03/03/2020

function EyeData=EyeTracking_Experiment_MM(varargin)

%Get the inputs
EyeData = varargin{1};
Data = varargin{2};
GenerateTrials = varargin{3};

TR = 2; % Assume the TR is 2s

is_conservative = 0; % If this is 1 then you will only consider a present response acceptable. If it is set to zero then only a response that isn't off screen is acceptable. So if there is no eye tracking data or there is

% Specify the experiment ID
Experiment = 'MM';

%If it wasn't quit out

for IdxCounter=1:length(EyeData.Timecourse.(Experiment))
    %What block and repetition does this Idx correspond to
    Idx_Name=EyeData.Idx_Names.(Experiment)(IdxCounter,:);
    Block_Name=sprintf('Block_%d_%d', Idx_Name(1), Idx_Name(2));
    MovieName = GenerateTrials.Experiment_MM.Parameters.BlockNames{Idx_Name(1)};

    %Extract the timecourse
    Timecourse=EyeData.Timecourse.(Experiment){IdxCounter};
    
    % Get the timing of each eye tracker frame
    FrameTiming=EyeData.Timing.(Experiment){IdxCounter}(:,1);
    
    % Get the time stamps
    
    MovieStart = Data.Experiment_MM.(Block_Name).Timing.Movie_1.movieStart.Local;
    MovieEnd = Data.Experiment_MM.(Block_Name).Timing.Movie_1.movieEnd.Local;
    
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
    
    % Get the block start and stop time in eye tracker time
    block_start = (MovieStart * EyeData.EyeTrackerTime.slope) + EyeData.EyeTrackerTime.intercept;
    block_end = (MovieEnd * EyeData.EyeTrackerTime.slope) + EyeData.EyeTrackerTime.intercept;
    
    % Specify the critical window for doing exclusions based on
    % the movie timing
    if sum((FrameTiming(time_points) > block_start) .* (FrameTiming(time_points) < block_end)) > 0
        [~,block_start_idx]=min(abs(FrameTiming - block_start));
        [~,block_end_idx]=min(abs(FrameTiming - block_end));
        Exclude.CriticalWindow{IdxCounter}=block_start_idx:block_end_idx; %In terms of the indexes in the time course data
    else
        % No data was found in this critical window so specify that here
        Exclude.CriticalWindow{IdxCounter}=[];
    end
    
    % Turn these times in to seconds
    block_start_elapsed = (block_start - onset_time) / EyeData.EyeTrackerTime.slope;
    block_end_elapsed = (block_end - onset_time) / EyeData.EyeTrackerTime.slope;
    
    % Specify all of the Drop periods
    Drop_windows = [];
    if strcmp(MovieName(1:4), 'Drop')
        
        % Define the drop windows
        for drop_counter = 1:9
            Frame_onset = ((MovieStart + 20 * drop_counter - 10)  * EyeData.EyeTrackerTime.slope) + EyeData.EyeTrackerTime.intercept;
            Frame_offset = ((MovieStart + 20 * drop_counter)  * EyeData.EyeTrackerTime.slope) + EyeData.EyeTrackerTime.intercept;
            Drop_windows(drop_counter, :) = [Frame_onset, Frame_offset];
        end
        
        % Cycle through each frame. If the frame is within the drop period set the excluded responses accordingly
        for frame_counter = 1:length(FrameTiming)
            
            % If there are any windows that contain this frame then set the excluded responses accordingly
            if any((Drop_windows(:, 1) < FrameTiming(frame_counter)) .* (Drop_windows(:, 2) > FrameTiming(frame_counter)))
                Exclude.InvalidCodes{IdxCounter}{1}(frame_counter) = -inf; % This is a drop period so ignore everything
            else
                Exclude.InvalidCodes{IdxCounter}{1}(frame_counter) = 0; % This is an on period so off screen counts
            end
        end
        
        % Change the criterion since 50% of the frames are included by
        % default
        Exclude.Criterion(IdxCounter) = 0.75;
    else
        % If it is a full condition then set
        Exclude.Criterion(IdxCounter) = 0.5;
        Exclude.InvalidCodes{IdxCounter}{1} = 0;
    end

    figure;
    
    % Plot the time course
    hold on
    plot(elapsed_time, gaze_data_block);
    
    % When does the block start and stop?
    plot([block_start_elapsed, block_start_elapsed], [-1, 3], 'g');
    plot([block_end_elapsed, block_end_elapsed], [-1, 3], 'r');
    for drop_counter = 1:size(Drop_windows, 1)
        Drop_window = (Drop_windows(drop_counter, :) - onset_time) / EyeData.EyeTrackerTime.slope;

        % Fill in with the drop periods
        if any(Drop_window < max(elapsed_time))
            fill([Drop_window(1), Drop_window(1), Drop_window(2), Drop_window(2)], [-1, 3, 3, -1], 'k', 'facealpha', 0.1, 'EdgeColor', 'none');
        end
    end
    hold off
    
    % What proportion of timepoints in the window are present?
    critical_window = (elapsed_time > block_start_elapsed) .* (elapsed_time <= block_end_elapsed);
    critical_present = gaze_data_block(critical_window == 1) == 2;
    
    % Change the range so that you can see the responses that matter
    yticks([0, 1, 2]); % Allowed responses are 'off screen', 'undetected', 'present' (reordered after the remapping
    yticklabels({'off', 'undetected', 'present'});
    ylim([-1, 3]);
    title(sprintf('%s Present: %0.2f', Block_Name, mean(critical_present)));
    
    % Save the figure
    saveas(gcf, sprintf('analysis/Behavioral/MM_%s.png', Block_Name));
    
    %% Convert to be a regressor
    
    % Pull out the time stamps -> from the experiment block, not the movie
    tr_timestamps_all = Data.Experiment_MM.(Block_Name).Timing.TR;

    % Only create the regressor though
    if ~isempty(tr_timestamps_all)
        
        % Find the next TR stored in the data that is after this block. If it
        % is wrong then it will be ignored because it won't fit in a TR bin
        % but only do this if MM wasn't the last experiment run
        if find(tr_timestamps_all(end) == Data.Global.Timing.TR) ~= length(Data.Global.Timing.TR)
            extra_TR = Data.Global.Timing.TR(find(tr_timestamps_all(end) == Data.Global.Timing.TR) + 1);
            tr_timestamps_all = [tr_timestamps_all, extra_TR];
        %else 
        %    extra_TR = Data.Global.Timing.TR(end)+TR; %last TR plus the length of a TR 
        end
        
        %tr_timestamps_all = [tr_timestamps_all, extra_TR];
        
        % Fix if there are any missing TRs
        if any(diff(tr_timestamps_all)>TR*1.1)
            
            %Iterate through the TRs
            TRCounter=1;
            while TRCounter<length(tr_timestamps_all) %One less than the list or else you will index out of bounds
                
                %If there is a gap of 3 TRs then fill it in
                if  tr_timestamps_all(TRCounter+1) - tr_timestamps_all(TRCounter)>TR*1.1
                    
                    GapTRs= tr_timestamps_all(TRCounter):TR:tr_timestamps_all(TRCounter+1); %Make the time stamps for the TRs
                    
                    %What index are you taking? This will be different
                    %depending on whether there is still a gap between this
                    %last interpolated TR and the real TRs
                    if abs(GapTRs(end)-tr_timestamps_all(TRCounter+1))>(TR*.9)
                        GapTRs=GapTRs(2:end);
                    else
                        GapTRs=GapTRs(2:end-1);
                    end
                    
                    tr_timestamps_all = [tr_timestamps_all(1:TRCounter), GapTRs, tr_timestamps_all(TRCounter+1:end)]; %Store these interpolated TRs
                end
                
                TRCounter=TRCounter+1;
            end
        end
        
        % Convert the TR timestamps to the eyetracker time
        tr_timestamps_eyetracker = (tr_timestamps_all * EyeData.EyeTrackerTime.slope) + EyeData.EyeTrackerTime.intercept;
        
        % Bin the gaze data into timestamps
        first_bin = find((tr_timestamps_eyetracker - block_start) > 0, 1, 'first') - 1;
        last_bin = find((block_end-tr_timestamps_eyetracker) > 0,  1, 'last') + 1;
        
        % If there was no burn out then the last bin should be the last TR
        if last_bin > length(tr_timestamps_eyetracker)
            last_bin = length(tr_timestamps_eyetracker);
            fprintf('No burnout found for MM %s\n', Block_Name);
        end
        
        % Iterate through the bins
        off_screen_trs=[];
        for bin_counter = first_bin:(last_bin - 1)
            
            % When does this bin start and end
            bin_start = tr_timestamps_eyetracker(bin_counter);
            bin_end = tr_timestamps_eyetracker(bin_counter + 1);
            
            % Pull out the frames from this bin
            bin_frames = logical((FrameTiming >= bin_start) .* (FrameTiming < bin_end) .* (time_points == 1));
            
            % Specify the frames
            frames = Timecourse(bin_frames);
            
            % Check that it is long enough
            if ~isempty(frames)
                
                % Specify whether this is the modal response. Different
                % depending on whether you are being conservative or not
                if is_conservative == 1
                    off_screen_trs(end+1) = mode(frames) ~= 2;
                else
                    off_screen_trs(end+1) = mode(frames) == 0;
                end
            else
                % GIve the benefit of the doubt
                if is_conservative == 1
                    off_screen_trs(end+1) = 1;
                else
                    off_screen_trs(end+1) = 0;
                end
            end
            
        end
        
        % Store the TRs as a vector
        fid = fopen(sprintf('analysis/Behavioral/MM_%s.txt', Block_Name), 'w');
        
        % Print the TR inclusions
        fprintf(fid, sprintf('%d\n', off_screen_trs));
        
        % Close the file
        fclose(fid);
    else
        warning(sprintf('Not making a regressor for MM %s because there are no TRs for this run\n', Block_Name));
        
    end
    

end

% Also make a file that tells you the mapping between the block ID and the
% movie that was played

fid = fopen(sprintf('analysis/Behavioral/MM_Block2MovieName.txt'), 'w');

%We will cycle through this again one more time
for IdxCounter=1:length(EyeData.Timecourse.(Experiment))
    
    %What block and repetition does this Idx correspond to
    Idx_Name=EyeData.Idx_Names.(Experiment)(IdxCounter,:);
    Block_Name=sprintf('Block_%d_%d', Idx_Name(1), Idx_Name(2));
    MovieName = GenerateTrials.Experiment_MM.Parameters.BlockNames{Idx_Name(1)};
    
    %Split up the movie name into whether it was full/drop or 
    %split=strsplit(MovieName,'_');
    %Condition=split{1};
    %Movie=split{2};
    
    % Only print to the file if we didn't quit out and we collected enough
    % TRs (in other words, this movie wasn't shown in PETRA)
    if Data.Experiment_MM.(Block_Name).Quit==0 && ~isempty(Data.Experiment_MM.(Block_Name).Timing.TR)
        fprintf(fid, sprintf('%s %s\n', Block_Name,MovieName));
    end
end

% Close the file
fclose(fid);

if ~isempty(Data.Experiment_MM.(Block_Name).Timing.Movie_1.TR)
    EyeData.Exclude.(Experiment)=Exclude;
else
    %not sure if this is right .... 
    EyeData.Exclude.(Experiment)=Exclude;
end


