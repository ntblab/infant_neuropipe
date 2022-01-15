%% Summarize eye tracking data for Repetition Narrowing
%
% Summarize the looking time and reaction behavior of the participants in
% the repetition narrowing task.
%
% To add an experiment, create the function which takes in the following
% inputs: EyeData, Data, GenerateTrials. The output is EyeData but probably
% including (any or all) are Weights, ReactionTime and Exclude. Be careful
% when making this that you don't overwrite any of the previous entries
% (Which is why each experiment should have its own subfield of Weights,
% ReactionTime and Exclude)
%
% TY 08/14/2019

function EyeData=EyeTracking_Experiment_RepetitionNarrowing(varargin)

%Get the inputs
EyeData = varargin{1};
Data = varargin{2};
GenerateTrials = varargin{3};

%What experiment is this
Experiment='RepetitionNarrowing';

%Iterate through the experiment counter
Weights=struct;
Exclude=struct;

rnfigs=struct;

%Iterate through all the trials of this experiment
for IdxCounter=1:length(EyeData.Timecourse.(Experiment))
    
    %What block and repetition does this Idx correspond to
    Idx_Name=EyeData.Idx_Names.(Experiment)(IdxCounter,:);
    Block_Name=sprintf('Block_%d_%d', Idx_Name(1), Idx_Name(2));
    Full_Name=GenerateTrials.Experiment_RepetitionNarrowing.Parameters.BlockNames{Idx_Name(1)}; %What condition is this
    
    % NOTE: This is legacy code to account for changes in the naming of conditions that happened before the data collection reported here
    %Because there was a change in the naming system, we have to try a few
    %things to figure out what the condition (species, rep/norep) actually
    %was
    Temp1=Full_Name(strfind(Full_Name, '; nth')-2 : strfind(Full_Name, '; nth')-1);
    %second oldest naming system
    Temp2=Full_Name(strfind(Full_Name, '; Block')-1);
    
    if ~isempty(Temp1)
        if str2double(Temp1(isstrprop(Temp1, 'digit')))==1
            Condition=[Full_Name(1:strfind(Full_Name, ';')-1), '_Reps'];
        else
            Condition=[Full_Name(1:strfind(Full_Name, ';')-1), '_NoReps'];
        end
        
    elseif ~isempty(Temp2(isstrprop(Temp2, 'digit')))
        if str2double(Temp2(isstrprop(Temp2, 'digit')))==1
            Condition=[Full_Name(1:strfind(Full_Name, ';')-1), '_Reps'];
        else
            Condition=[Full_Name(1:strfind(Full_Name, ';')-1), '_NoReps'];
        end
    else
        Temp=Full_Name(1:strfind(Full_Name, 'Block')-2);
    
        if ~contains(Temp,'Novel') 
            Condition=[Full_Name(1:strfind(Full_Name, ';')-1), '_Reps'];
        else
            Condition=[Full_Name(1:strfind(Full_Name, ';')-1), '_NoReps'];
        end
    
    end
    
    %The condition name 'Scenes_Reps' is a lie --> change it accordingly
    if contains(Condition, 'Scenes_Reps')
        Condition='Scenes_NoReps';
    end
    
    
    %Extract the timecourse
    Timecourse=EyeData.Timecourse.(Experiment){IdxCounter};
    
    
    %If this block's data was recorded, specify it here. If not
    %don't create a time course
    if isfield(Data.Experiment_RepetitionNarrowing, Block_Name) && Data.Experiment_RepetitionNarrowing.(Block_Name).Quit == 0
        
        %Start time of the experiment
        Exp_Onset=Data.Experiment_RepetitionNarrowing.(Block_Name).Timing.TestStart;
       
        %What are the times of the fixation event
        Fix_Onset=Data.Experiment_RepetitionNarrowing.(Block_Name).Timing.FixationStart;
        Fix_Offset=Data.Experiment_RepetitionNarrowing.(Block_Name).Timing.FixationEnd;

        %What are the times of VPC event
        VPC_Onset=Data.Experiment_RepetitionNarrowing.(Block_Name).VPC.Timing.ImageOns(1); %both are the same ish time
        VPC_Offset=Data.Experiment_RepetitionNarrowing.(Block_Name).VPC.Timing.ImageOffs(1);
        
        %Convert all the matlab times to eye tracker time
        Exp_Onset_eyetracker=(EyeData.EyeTrackerTime.slope*Exp_Onset) + EyeData.EyeTrackerTime.intercept;
        
        Fix_Onset_eyetracker=(EyeData.EyeTrackerTime.slope*Fix_Onset) + EyeData.EyeTrackerTime.intercept;
        Fix_Offset_eyetracker=(EyeData.EyeTrackerTime.slope*Fix_Offset) + EyeData.EyeTrackerTime.intercept;
       
        VPC_Onset_eyetracker=(EyeData.EyeTrackerTime.slope*VPC_Onset) + EyeData.EyeTrackerTime.intercept;
        VPC_Offset_eyetracker=(EyeData.EyeTrackerTime.slope*VPC_Offset) + EyeData.EyeTrackerTime.intercept;
        
    else
        Timecourse=0;
    end
    
    %What is the timing of the frames (when you have an incomplete
    %set of coders, not all of these frames will be numbered,
    %thus decreasing your timing precision).
    if length(Timecourse)>1
        FrameTiming=EyeData.Timing.(Experiment){IdxCounter}(:,1);
        
        [~,Exp_Onset_Idx]=min(abs(FrameTiming-Exp_Onset_eyetracker));
        
        [~,Fix_Onset_Idx]=min(abs(FrameTiming-Fix_Onset_eyetracker));
        [~,Fix_Offset_Idx]=min(abs(FrameTiming-Fix_Offset_eyetracker));
        
        [~,VPC_Onset_Idx]=min(abs(FrameTiming-VPC_Onset_eyetracker));
        [~,VPC_Offset_Idx]=min(abs(FrameTiming-VPC_Offset_eyetracker));
        
        %Make a figure for this condition (species, rep number)
        if isfield(rnfigs,Condition)==0
            rnfigs.(Condition)=figure;
        end
        
        %Which "nth" block is this?
        TrialCounter=Full_Name(end); %should be the last thing
        
        %Return to this figure
        figure(rnfigs.(Condition))

        %first lets change the time course 'undetected' to -1 for
        %visualization purposes, and center to be in the middle of left and
        %right
        Timecourse_recoded=Timecourse;
        Timecourse_recoded(Timecourse==6)=-1;
        Timecourse_recoded(Timecourse==3)=1.5;
        
        subplot(3,2, str2double(TrialCounter))
        hold on
        plot(1:length(Timecourse_recoded),Timecourse_recoded);
        plot([Fix_Onset_Idx, Fix_Onset_Idx],[-1.5, 3], 'g');
        plot([Fix_Offset_Idx, Fix_Offset_Idx],[-1.5,3], 'g')
        plot([VPC_Onset_Idx, VPC_Onset_Idx],[-1.5, 3], 'r');
        plot([VPC_Offset_Idx, VPC_Offset_Idx],[-1.5, 3], 'r');
        
        title([Block_Name]);
        yticks([-1, 0, 1, 1.5, 2]);
        ylim([-2, 4]);
        yticklabels({'undetected', 'off screen', 'left', 'center', 'right'})
        hold off
        
        %How was the VPC set up?
        New_Side=GenerateTrials.Experiment_RepetitionNarrowing.Stimuli.New_Position(Idx_Name(1));
        
        %What sides did the new and old images appear on
        %Also, what was the old stimulus?
        if New_Side==1 %left
            Old_Side=2; %right
            OldStim=Data.Experiment_RepetitionNarrowing.(Block_Name).VPC.Stimuli.Right;
            OldStim=OldStim(max(strfind(OldStim, '/'))+1:end); %shorten
        else
            Old_Side=1; %left
            OldStim=Data.Experiment_RepetitionNarrowing.(Block_Name).VPC.Stimuli.Left;
            OldStim=OldStim(max(strfind(OldStim, '/'))+1:end); %shorten
        end
        
        %What was the index of this old target?
        Old_idx=find(not(cellfun('isempty', strfind(Data.Experiment_RepetitionNarrowing.(Block_Name).Stimuli.Name, OldStim))));
        
        %preset
        saw_it=0;
        
        %if it was a repeat trial then there will be more examples, so keep
        %going until they looked at one of them
        
        for i=1:length(Old_idx)
            
            %What was the timing in matlab?
            Stim_Ons=Data.Experiment_RepetitionNarrowing.(Block_Name).Timing.LargeImageOns(Old_idx(i));
            Stim_Offs=Data.Experiment_RepetitionNarrowing.(Block_Name).Timing.ShrinkingOns(Old_idx(i));
            
            %what was the timing in eyetracker?
            Stim_Onset_eyetracker=(EyeData.EyeTrackerTime.slope*Stim_Ons) + EyeData.EyeTrackerTime.intercept;
            Stim_Offset_eyetracker=(EyeData.EyeTrackerTime.slope*Stim_Offs) + EyeData.EyeTrackerTime.intercept;
            
            [~,Stim_Onset_Idx]=min(abs(FrameTiming-Stim_Onset_eyetracker));
            [~,Stim_Offset_Idx]=min(abs(FrameTiming-Stim_Offset_eyetracker)); 
            
	    % Figure out how long they were looking at the stimulus (i.e., not coded as offscreen) while it was on the screen
            prop_stim_offscreen=sum(Timecourse(Stim_Onset_Idx:Stim_Offset_Idx)==0)/length(Timecourse(Stim_Onset_Idx:Stim_Offset_Idx));
            
            % Did they look for at least 500 milliseconds?
            if (1-prop_stim_offscreen)*Data.Experiment_RepetitionNarrowing.(Block_Name).Timing.LargeImageTime > 0.5
                saw_it=1;
                break;
            end
        end
        
        %Now only if they saw it at encoding will you do the behavioral
        %analyses
        
        if saw_it==1
            
            %Create weights of looking to the old side
            New=sum(Timecourse(VPC_Onset_Idx:VPC_Offset_Idx)==New_Side);
            Old=sum(Timecourse(VPC_Onset_Idx:VPC_Offset_Idx)==Old_Side);

            %But how much of the trial were they looking to stimuli at all?
            %We will count undetected and center in this (just not offscreen)
            VPC_attend=length(Timecourse(VPC_Onset_Idx:VPC_Offset_Idx))-sum(Timecourse(VPC_Onset_Idx:VPC_Offset_Idx)==0);

            %So then how long was the VPC (not in frames but in time)? (should be 5 seconds)
            VPC_length=mean(Data.Experiment_RepetitionNarrowing.(Block_Name).VPC.Timing.ImageOffs-Data.Experiment_RepetitionNarrowing.(Block_Name).VPC.Timing.ImageOns);

            %Now we can figure out frames per seconds
            FPS=length(Timecourse(VPC_Onset_Idx:VPC_Offset_Idx))/VPC_length;

            % Create seperate weights for this block
            Weights.(Block_Name)(1)=Old/(New+Old); %prop old > new (out of all left/right time)
            Weights.(Block_Name)(2)=Old/VPC_attend; %prop old over all time attending (including centers and undetected)
            Weights.(Block_Name)(3)=Old/length(Timecourse(VPC_Onset_Idx:VPC_Offset_Idx)); %prop old over whole test trial
            Weights.(Block_Name)(4)=New/length(Timecourse(VPC_Onset_Idx:VPC_Offset_Idx)); %prop new over whole test trial
            
            %Create a pooled familiarity structure for this condition if it
            %does not already exist
            if ~exist('Pooled_Familiar') || ~isfield(Pooled_Familiar, Condition)
                Pooled_Familiar.(Condition).Old_New=[];
                Pooled_Familiar.(Condition).Old_Seen=[];
                Pooled_Familiar.(Condition).Old_Overall=[];
                Pooled_Familiar.(Condition).New_Overall=[];
            end

            %Only add to this if they looked left or right for 500 ms or more
            %(calulated by time frames attended to VPC divided by frame rate of
            %the VPC) 
            
            %if VPC_attend/FPS > 0.5
                Pooled_Familiar.(Condition).Old_New(end+1)=Old/(New+Old);
                Pooled_Familiar.(Condition).Old_Seen(end+1)=Old/VPC_attend;
                Pooled_Familiar.(Condition).Old_Overall(end+1)=Old/length(Timecourse(VPC_Onset_Idx:VPC_Offset_Idx));
		Pooled_Familiar.(Condition).New_Overall(end+1)=New/length(Timecourse(VPC_Onset_Idx:VPC_Offset_Idx));
            %end
            
            
        end
    end
end

%% Do analyses summarizing across blocks 
%Iterate through the conditions
if exist('Pooled_Familiar')~=0
    
    Conditions=fieldnames(Pooled_Familiar);

    for ConditionCounter=1:length(Conditions)
        Condition=Conditions{ConditionCounter};
        
        % First, save out the condition figures
        figure(rnfigs.(Condition))
        suptitle(Condition);
        savefig(rnfigs.(Condition), sprintf('analysis/Behavioral/Experiment_RepetitionNarrowing_%s.fig', Condition))
        saveas(rnfigs.(Condition), sprintf('analysis/Behavioral/Experiment_RepetitionNarrowing_%s.png', Condition))
        %close(rnfigs.(Condition))
        
        % Extract the mean looking to the familiar; test if different from
        % chance 50%; we just want this for the face stimuli
        if ~contains(Condition,'Scenes')
            
            %Pascalis study looked at what happened over the entire VPC --
            %let's follow that 
            try PropFam_OldOverall=nanmean(Pooled_Familiar.(Condition).Old_Overall); catch; PropFam_OldOverall=NaN; end
	    try PropFam_NewOverall=nanmean(Pooled_Familiar.(Condition).New_Overall); catch; PropFam_NewOverall=NaN; end
            try [h,p,ci,stats]=ttest(Pooled_Familiar.(Condition).Old_Overall,Pooled_Familiar.(Condition).New_Overall); catch; p=NaN; end
            
            %But report the other measures too 
            try PropFam=nanmean(Pooled_Familiar.(Condition).Old_New); catch; PropFam=NaN; end
            try PropFam_Seen=nanmean(Pooled_Familiar.(Condition).Old_Seen); catch; PropFam_Seen=NaN; end
           
            % Print results
            fprintf('\nRepetition Narrowing looking time results for %s blocks (%d examples)\n\n---------------------\n\nProportion looking at familiar over duration of test:%0.2f (vs novel %0.2f, p value: %0.2f)\n Proportion looking at familiar out of time attending %0.2f\n Proportion looking at familiar vs novel %0.2f\n\n---------------------\n\n', Condition, length(Pooled_Familiar.(Condition).Old_Overall),PropFam_OldOverall,PropFam_NewOverall, p, PropFam_Seen,PropFam);
        end
    end
    
end

%Store the data
EyeData.Weights.(Experiment)=Weights;
EyeData.Exclude.(Experiment)=Exclude;
