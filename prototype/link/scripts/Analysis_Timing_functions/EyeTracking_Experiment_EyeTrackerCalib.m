%%Summarize eye tracking data for the eye tracker calibration
%
% Summarize the time taken to look at the target in the eye tracker
% calibration
%
function EyeData=EyeTracking_Experiment_EyeTrackerCalib(varargin)

%Get the inputs
EyeData = varargin{1};
Data = varargin{2};

%What experiment is this
Experiment='EyeTrackerCalib';

%Iterate through the experiment counter
ReactionTime=struct;

figs=struct;

%Iterate through all the trials of this experiment
colors={'red', 'green'};
correct_RT=[];
Accuracy_all=[];
for IdxCounter=1:length(EyeData.Timecourse.(Experiment))
    
    %What block and repetition does this Idx correspond to
    Idx_Name=EyeData.Idx_Names.(Experiment)(IdxCounter,:);
    Block_Name=sprintf('Block_%d_%d', Idx_Name(1), Idx_Name(2));
    TrialCounter=Idx_Name(3); %What trial does this index refer to?
    
    % How many trials per block?
    Trials=length(Data.Experiment_EyeTrackerCalib.(Block_Name).Timing.TrialOns);
    
    % If they quit out mid block, deal with it here
    if TrialCounter > Trials
        warning(sprintf('Trial %d exceeds the number of total trails stored: %d. This can happen when you quit out, meaning that info about the last trial isn''t saved. Skipping this trial to deal with this\n', TrialCounter, Trials))
        continue;
    end
    
    TrialOns=Data.Experiment_EyeTrackerCalib.(Block_Name).Timing.TrialOns(TrialCounter);
    
    %Extract the timecourse
    Timecourse=EyeData.Timecourse.(Experiment){IdxCounter};
    
    % What is the correct X report for this index?
    if isfield(EyeData.Reliability, 'EyeTrackerCalib')
        X=EyeData.Reliability.EyeTrackerCalib.X(1, IdxCounter);
        Y=EyeData.Reliability.EyeTrackerCalib.Y(1, IdxCounter);
        
        %What is the timing of the frames (when you have an incomplete
        %set of coders, not all of these frames will be numbered,
        %thus decreasing your timing precision).
        if length(Timecourse)>1
            
            %Make a figure
            if isfield(figs, Block_Name)==0
                figs.(Block_Name)=figure;
            end
            
            %Return to this figure
            figure(figs.(Block_Name))
            
            %Recode the timepoints for display purposes
            Timecourse_recoded=Timecourse;
            Timecourse_recoded(Timecourse==0)=nan;
            Timecourse_recoded(Timecourse==1)=-1;
            Timecourse_recoded(Timecourse==2)=1;
            Timecourse_recoded(Timecourse==3)=0;
            
            % What is the experiment time when half the trial has elapsed
            TimingTemp=EyeData.Timing.(Experiment){IdxCounter};
            Threshold=((TimingTemp(end,1) - TimingTemp(1,1))*0.5) + TimingTemp(1,1);
            
            %What frames exceed the threshold
            First_frame = min(find(Threshold<TimingTemp(:,1)));
            
            % Determine whether this is considered a correct response
            Accuracy=mode(Timecourse(First_frame:end))==X;
            Accuracy_all(end+1)=Accuracy;
            ReactionTime.(Block_Name).Accuracy(TrialCounter)=Accuracy;
            
            %What side did the target appear on
            if X==1
                Side='Left ';
            elseif X==2
                Side='Right ';
            elseif X==3
                Side='Centre ';
            end
            
            if Y==1
                Height='Top';
            elseif Y==2
                Height='Middle';
            elseif Y==3
                Height='Bottom';
            end
            
            subplot(ceil(sqrt(Trials)), ceil(sqrt(Trials)), TrialCounter)
            hold on
            plot(Timecourse_recoded,1:length(Timecourse_recoded), colors{Accuracy+1});
            
            title([Side, Height]);
            xlim([-1.2, 1.2]);
            set(gca, 'YTick', [], 'YTickLabel', {},'XTick', [-1 0 1], 'XTickLabel', {'L', 'C', 'R'})
            
            hold off
            
            % When, relative to the onset of the target, do the eyes
            % saccade
            SaccadeIdx=find(Timecourse==X);
            SaccadeIdx=min(SaccadeIdx);
            
            % Convert this index into time since the target onset
            ReactionTime.(Block_Name).Position(TrialCounter, :)=[X, Y];
            if isempty(SaccadeIdx)
                ReactionTime.(Block_Name).ReactionTime(TrialCounter)=nan; %If this is empty then this mean they never looked
            else
                
                % Get the eye tracker time, if the idx does not
                % correspond to a sampled point then go forward until
                % it does
                EyeTrackerTime=0;
                while EyeTrackerTime==0 && length(EyeData.Timing.(Experiment){IdxCounter})>=SaccadeIdx
                    EyeTrackerTime=EyeData.Timing.(Experiment){IdxCounter}(SaccadeIdx,1);
                    SaccadeIdx=SaccadeIdx+1;
                end
                
                % Convert the eyetracker time into matlab
                MatlabTime=(EyeTrackerTime-EyeData.EyeTrackerTime.intercept)/EyeData.EyeTrackerTime.slope;
                RT=MatlabTime-TrialOns;
                ReactionTime.(Block_Name).ReactionTime(TrialCounter)=RT;
                
                % Add the RT if they looked at the stimulus
                if Accuracy==1
                    correct_RT(end+1)=RT;
                end
            end
        end
    end
end

%Save all the figures
Blocks=fieldnames(figs);
for BlockCounter=1:length(Blocks)
    figure(figs.(Blocks{BlockCounter}))
    suptitle(Blocks{BlockCounter});
    saveas(figs.(Blocks{BlockCounter}), sprintf('analysis/Behavioral/Experiment_EyeTrackerCalib_%s.png', Blocks{BlockCounter}))
    close(figs.(Blocks{BlockCounter}))
end

% Make a plot of the distribution of RTs
figure;
hist(correct_RT);
fig=gcf;
title(sprintf('Distribution of RT. Mean RT (>0.1s): %0.2fs, Proportion correct: %0.2f%%', mean(correct_RT(correct_RT>0.1)), mean(Accuracy_all)*100));
saveas(fig, 'analysis/Behavioral/Experiment_EyeTrackerCalib_histogram.png')
close(fig);

%Store the data
EyeData.ReactionTime.(Experiment)=ReactionTime;
