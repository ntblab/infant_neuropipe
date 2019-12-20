%%Summarize eye tracking data for Posner
%
% Summarize the looking time and reaction behavior of the participants in
% the posner task.
%
% To add an experiment, create the function which takes in the following
% inputs: EyeData, Data, GenerateTrials. The output is EyeData but probably
% including (any or all) are Weights, ReactionTime and Exclude. Be careful
% when making this that you don't overwrite any of the previous entries
% (Which is why each experiment should have its own subfield of Weights,
% ReactionTime and Exclude)
%
%
function EyeData=EyeTracking_Experiment_PosnerCuing(varargin)

%Get the inputs
EyeData = varargin{1};
Data = varargin{2};
GenerateTrials = varargin{3};

%What experiment is this
Experiment='PosnerCuing';

%Include coders where necessary
IncludedCoders=EyeData.IncludedCoders;

%Iterate through the experiment counter
ReactionTime=struct;
Weights=struct;
Exclude=struct;

posnerfigs=struct;
RT_threshold=[0, 1]; %What is the cut off for RT in the posner. 0 means the saccade must be after the onset of the target

%Iterate through all the trials of this experiment
for IdxCounter=1:length(EyeData.Timecourse.(Experiment))
    
    %What block and repetition does this Idx correspond to
    Idx_Name=EyeData.Idx_Names.(Experiment)(IdxCounter,:);
    Block_Name=sprintf('Block_%d_%d', Idx_Name(1), Idx_Name(2));
    Condition=GenerateTrials.Experiment_PosnerCuing.Parameters.BlockNames{Idx_Name(1)}; %What condition is this
    TrialCounter=Idx_Name(3); %What trial does this index refer to?
    
    %Extract the timecourse
    Timecourse=EyeData.Timecourse.(Experiment){IdxCounter};
    
    %If this block's data was recorded, specify it here. If not
    %don't create a time course
    if isfield(Data.Experiment_PosnerCuing, Block_Name)  &&  isfield(Data.Experiment_PosnerCuing.(Block_Name).Timing, 'ITIOns') && size(Data.Experiment_PosnerCuing.(Block_Name).Timing.ITIOns, 1)>=TrialCounter
        %What are the times of trial events
        Cue_Onset=Data.Experiment_PosnerCuing.(Block_Name).Timing.CueOns(TrialCounter,2);
        Cue_Offset=Data.Experiment_PosnerCuing.(Block_Name).Timing.CueTargetOns(TrialCounter,2);
        Target_Onset=Data.Experiment_PosnerCuing.(Block_Name).Timing.TargetOns(TrialCounter,2);
        Target_Offset=Data.Experiment_PosnerCuing.(Block_Name).Timing.ITIOns(TrialCounter,2);
        
        %Convert matlab times to eye tracker time
        Cue_Onset_eyetracker=(EyeData.EyeTrackerTime.slope*Cue_Onset) + EyeData.EyeTrackerTime.intercept;
        Cue_Offset_eyetracker=(EyeData.EyeTrackerTime.slope*Cue_Offset) + EyeData.EyeTrackerTime.intercept;
        Target_Onset_eyetracker=(EyeData.EyeTrackerTime.slope*Target_Onset) + EyeData.EyeTrackerTime.intercept;
        Target_Offset_eyetracker=(EyeData.EyeTrackerTime.slope*Target_Offset) + EyeData.EyeTrackerTime.intercept;
    else
        Timecourse=0;
    end
    
    %What is the timing of the frames (when you have an incomplete
    %set of coders, not all of these frames will be numbered,
    %thus decreasing your timing precision).
    if length(Timecourse)>1
        FrameTiming=EyeData.Timing.(Experiment){IdxCounter}(:,1);
        
        [~,Cue_Onset_Idx]=min(abs(FrameTiming-Cue_Onset_eyetracker));
        [~,Cue_Offset_Idx]=min(abs(FrameTiming-Cue_Offset_eyetracker));
        [~,Target_Onset_Idx]=min(abs(FrameTiming-Target_Onset_eyetracker));
        [~,Target_Offset_Idx]=min(abs(FrameTiming-Target_Offset_eyetracker));
        
        % Specify the critical window of timing for this experiment
        Exclude.CriticalWindow{IdxCounter}=Cue_Onset_Idx:Cue_Offset_Idx;
        
        %Make a figure
        if isfield(posnerfigs, Block_Name)==0
            posnerfigs.(Block_Name)=figure;
        end
        
        %Return to this figure
        figure(posnerfigs.(Block_Name))
        
        %Recode the timepoints for display purposes
        Timecourse_recoded=Timecourse;
        Timecourse_recoded(Timecourse==0)=nan;
        Timecourse_recoded(Timecourse==6)=nan;
        Timecourse_recoded(Timecourse==1)=-1;
        Timecourse_recoded(Timecourse==2)=1;
        Timecourse_recoded(Timecourse==3)=0;
        
        %What condition is this?
        TrialParameters=Data.(sprintf('Experiment_%s', Experiment)).(Block_Name).StimulusSequence(TrialCounter,:);
        
        %What side did the target appear on
        if TrialParameters(2)==1
            Side='Left ';
        else
            Side='Right ';
        end
        
        %Is it a valid, neutral or invalid trial
        if TrialParameters(1)==TrialParameters(2)
            Validity='Valid';
        elseif TrialParameters(1)==0
            Validity='Neutral';
        else
            Validity='Invalid';
        end
        
        subplot(2,5, TrialCounter)
        hold on
        plot(Timecourse_recoded,1:length(Timecourse_recoded));
        plot([-1.5, 1.5], [Cue_Onset_Idx, Cue_Onset_Idx], 'r');
        plot([-1.5, 1.5], [Cue_Offset_Idx, Cue_Offset_Idx], 'r');
        plot([-1.5, 1.5], [Target_Onset_Idx, Target_Onset_Idx],'g');
        plot([-1.5, 1.5], [Target_Offset_Idx, Target_Offset_Idx], 'g');
        
        title([Side, Validity]);
        set(gca, 'YTick', [], 'YTickLabel', {},'XTick', [-1 0 1], 'XTickLabel', {'L', 'C', 'R'})
        hold off
        
        % When, relative to the onset of the target, do the eyes
        % saccade
        
        SaccadeIdx=find(Timecourse(Target_Onset_Idx:Target_Offset_Idx)==TrialParameters(2));
        SaccadeIdx=min(SaccadeIdx) + Target_Onset_Idx - 1;
        
        %Create if it doesn't exist
        if ~exist('PooledRT') || ~isfield(PooledRT, Condition) || ~isfield(PooledRT.(Condition), Validity)
            PooledRT.(Condition).(Validity)=[];
        end
        
        % Convert this index into time since the target onset
        if isempty(SaccadeIdx)
            ReactionTime.(Block_Name).ReactionTime(TrialCounter)=nan; %If this is empty then this mean they never looked
        else
            
            % Get the eye tracker time, if the idx does not
            % correspond to a sampled point then go forward until
            % it does
            EyeTrackerTime=0;
            while EyeTrackerTime==0 && length(EyeData.Timing.(Experiment){IdxCounter})>=SaccadeIdx;
                EyeTrackerTime=EyeData.Timing.(Experiment){IdxCounter}(SaccadeIdx,1);
                SaccadeIdx=SaccadeIdx+1;
            end
            
            % Convert the eyetracker time into matlab
            MatlabTime=(EyeTrackerTime-EyeData.EyeTrackerTime.intercept)/EyeData.EyeTrackerTime.slope;
            RT=MatlabTime-Target_Onset;
            
            % Make sure that the RT is within the bounds
            if RT>=RT_threshold(1) && RT<RT_threshold(2)
                %Store list for later
                PooledRT.(Condition).(Validity)(end+1)=RT;
            else
                fprintf('RT for %s event %d (%s) is out of range: %0.2f\n', Block_Name, TrialCounter, Validity, RT);
                RT = nan;
            end
            
            ReactionTime.(Block_Name).ReactionTime(TrialCounter)=RT;
            ReactionTime.(Block_Name).Validity{TrialCounter}=Validity;
            
            % Exclude events that don't have any looks to the target
            Weights.Parametric.(Block_Name)(TrialCounter) = ~isnan(RT);
            
        end
        
        %                 %Create weights of leftward versus rightward saccades so
        %                 %you can quantify leftward versus rightward activity
        %
        %                 Left=sum(Timecourse(Target_Onset_Idx:Target_Offset_Idx)==1);
        %                 Right=sum(Timecourse(Target_Onset_Idx:Target_Offset_Idx)==2);
        %
        %                 % Create seperate weights
        %                 Weights.Parametric.PosnerCuing.(Block_Name)(1,TrialCounter)=Left/(Target_Offset_Idx-Target_Onset_Idx+1);
        %                 Weights.Parametric.PosnerCuing.(Block_Name)(2,TrialCounter)=Right/(Target_Offset_Idx-Target_Onset_Idx+1);
        %
        
        
    end
end

%% Do analyses summarizing across blocks 
% Only proceed if you collected the PooledRT
if exist('PooledRT')~=0
    
    % Store for later
    ReactionTime.PooledRT = PooledRT; 
    
    %Save all the posner figures and create
    Conditions=fieldnames(PooledRT);
    Blocks=fieldnames(posnerfigs);
    for BlockCounter=1:length(Blocks)
        figure(posnerfigs.(Blocks{BlockCounter}))
        suptitle(Conditions{str2double(Blocks{BlockCounter}(7))});
        savefig(posnerfigs.(Blocks{BlockCounter}), sprintf('analysis/Behavioral/Experiment_PosnerCuing_%s.fig', Blocks{BlockCounter}))
        saveas(posnerfigs.(Blocks{BlockCounter}), sprintf('analysis/Behavioral/Experiment_PosnerCuing_%s.png', Blocks{BlockCounter}))
        close(posnerfigs.(Blocks{BlockCounter}))
    end
    
    %Iterate through the conditions
    for ConditionCounter=1:length(Conditions)
        Condition=Conditions{ConditionCounter};
        
        % Create histogram of reaction times to target
        range=0:0.2:2;
        h=figure;
        hold on
        try vals=hist(PooledRT.(Condition).Valid, range); plot(range, vals/sum(vals), 'r'); catch; end
        try vals=hist(PooledRT.(Condition).Invalid, range); plot(range, vals/sum(vals), 'g'); catch; end
        try vals=hist(PooledRT.(Condition).Neutral, range); plot(range, vals/sum(vals), 'b'); catch; end
        xlim([0,2])
        xlabel('Seconds');
        title(Condition);
        legend({'Valid', 'Invalid', 'Neutral'});
        hold off
        
        savefig(h, sprintf('analysis/Behavioral/Experiment_PosnerCuing_RT_%s_Validity.fig', Condition))
        saveas(h, sprintf('analysis/Behavioral/Experiment_PosnerCuing_RT_%s_Validity.png', Condition))
        close(h);
        
        % Extract the means
        try Valid=mean(PooledRT.(Condition).Valid); catch; Valid=NaN; end
        try Invalid=mean(PooledRT.(Condition).Invalid); catch; Invalid=NaN; end
        try Neutral=mean(PooledRT.(Condition).Neutral); catch; Neutral=NaN; end
        
        % Print results
        fprintf('\nPosner reaction time results for %s blocks\n---------------------\n\nValid RT: %0.2f (%d)\nInvalid RT: %0.2f (%d)\nNeutral RT: %0.2f (%d)\n\n---------------------\n', Condition, Valid, length(PooledRT.(Condition).Valid), Invalid, length(PooledRT.(Condition).Invalid), Neutral, length(PooledRT.(Condition).Neutral));
        
    end
    
    
end

%Store the data
EyeData.Weights.(Experiment)=Weights;
EyeData.ReactionTime.(Experiment)=ReactionTime;
EyeData.Exclude.(Experiment)=Exclude;
