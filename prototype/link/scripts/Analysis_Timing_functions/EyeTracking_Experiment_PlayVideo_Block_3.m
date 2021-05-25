%% Summarize eye tracking data for PlayVideo
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
function EyeData=EyeTracking_Experiment_PlayVideo_Block_3(varargin)

%Get the inputs
EyeData = varargin{1};
Data = varargin{2};

TR = 2; % Assume the TR is 2s

is_conservative = 0; % If this is 1 then you will only consider a present response acceptable. If it is set to zero then only a response that isn't off screen is acceptable. So if there is no eye tracking data or there is

% Specify the experiment ID
Experiment = 'PlayVideo_Block_3';

for IdxCounter=1:length(EyeData.Timecourse.(Experiment))
    
    %What block and repetition does this Idx correspond to
    Idx_Name=EyeData.Idx_Names.(Experiment)(IdxCounter,:);
    Block_Name=sprintf('Block_%d_%d', Idx_Name(1), Idx_Name(2));
    
    %Extract the timecourse
    Timecourse=EyeData.Timecourse.(Experiment){IdxCounter};
    
    % Get the timing of each eye tracker frame
    FrameTiming=EyeData.Timing.(Experiment){IdxCounter}(:,1);
    
    % Get the time stamps
    if isfield(Data.Experiment_PlayVideo.(Block_Name).Timing.Movie_1, 'movieStart')
        
        MovieStart = Data.Experiment_PlayVideo.(Block_Name).Timing.Movie_1.movieStart.Local;
        MovieEnd = Data.Experiment_PlayVideo.(Block_Name).Timing.Movie_1.movieEnd.Local;
        
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
            % No data was found in this critical windo so specify that here
            Exclude.CriticalWindow{IdxCounter}=[];
        end
        
        % Turn these times in to seconds
        block_start_elapsed = (block_start - onset_time) / EyeData.EyeTrackerTime.slope;
        block_end_elapsed = (block_end - onset_time) / EyeData.EyeTrackerTime.slope;
        
        figure;
        
        % Plot the time course
        hold on
        plot(elapsed_time, gaze_data_block);
        
        % When does the block start and stop?
        plot([block_start_elapsed, block_start_elapsed], [-1, 3], 'g');
        plot([block_end_elapsed, block_end_elapsed], [-1, 3], 'r');
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
        saveas(gcf, sprintf('analysis/Behavioral/PlayVideo_%s.png', Block_Name));
        
        %% Convert to be a regressor
        
        % Pull out the time stamps
        tr_timestamps_all = Data.Experiment_PlayVideo.(Block_Name).Timing.Movie_1.TR;
        
        if ~isempty(tr_timestamps_all)
            
            % Find the next TR stored in the data that is after this block. If it
            % is wrong then it will be ignored because it won't fit in a TR bin
            last_idx = find(tr_timestamps_all(end) == Data.Global.Timing.TR) + 1;
            
            if length(Data.Global.Timing.TR) >= last_idx
                extra_TR = Data.Global.Timing.TR(last_idx);
                
                tr_timestamps_all = [tr_timestamps_all, extra_TR];
            end
            
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
            
            % Clip if too long
            if last_bin>length(tr_timestamps_eyetracker)
                last_bin = length(tr_timestamps_eyetracker);
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
            fid = fopen(sprintf('analysis/Behavioral/PlayVideo_%s.txt', Block_Name), 'w');
            
            % Print the TR inclusions
            fprintf(fid, sprintf('%d\n', off_screen_trs));
            
            % Close the file
            fclose(fid);
        else
            warning(sprintf('Not making a regressor for PlayVideo %s because there are no TRs for this run\n', Block_Name));
        end
    end
end

% If the file exists then save it
if exist('Exclude') > 0 
    EyeData.Exclude.(Experiment)=Exclude;
end