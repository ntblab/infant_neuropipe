%% Calculate reliability for eye tracking data
%
%Three types of reliability are outputted measured:
%
%1. Accuracy: when a stimulus appears in a known location, is that coded in
%             the expected way. Proportion_EyeTrackerCalib_Include
%             describes how much time of each trial should be considered.
%
%2. Intraframe: when two coders see the same frame, do they code it the
%               same?
%
%3. Interframe: how similar is the coding for adjacent frames?
%
% There are the critical inputs from  EyeData:
%       Idx_Names: used for identifying what experiments to analyse
%       Coder_ConditionList: What conditions the participants were in
%       Aggregate: get the eye tracking categorizations
%       Timing: so that Proportion_EyeTrackerCalib_Include can be based on
%       elapsed time rather than number of frames.
% Data is necessary so that you can discern where fixations are expected on
% each trial.
%
% Established as a stand alone function, C Ellis 9/8/16
% Updated Interframe coding and enabled ignored coders, C Ellis 7/10/17
function EyeData=EyeTracking_Reliability(EyeData, Data)

%What are the thresholds for including a coder in this experiment.
%Since a bad coder will mean poor reliability with those that coded the
%same frame (intra) or adjacent frames (inter) only one of these has to be
%above threshold. If IQR value is given then the outlier will be 1.5x below the
%IQR across not ignored coders
Intraframe_Threshold=0.25;
Interframe_Threshold=0.25;
Accuracy_Threshold_EyeTrackerCalib='IQR';
Accuracy_Threshold_PosnerCuing='IQR';
Proportion_EyeTrackerCalib_Include=0.5; %What proportion of frames are you using for the eye tracking calibration?

Ignored_Coders={'NC', 'JO', 'Pilot'};

% Is this coder to be included (at least initially). If not then intraframe
% and interframe reliability won't be calculated
isIncluded_Coder=ones(1,length(EyeData.Coder_name));
for CoderCounter=1:length(EyeData.Coder_name)
    Coder_name=EyeData.Coder_name{CoderCounter};
    for ignored_coder_counter =1:length(Ignored_Coders)
        if ~isempty(strfind(Coder_name(strfind(Coder_name, 'Coder_'):end),Ignored_Coders{ignored_coder_counter}))
            isIncluded_Coder(CoderCounter)=0;
        end
    end
end

Experiments=fieldnames(EyeData.Idx_Names);
IncludedCoders=[];
Conditions=unique(EyeData.Coder_ConditionList);
%Iterate through the different conditions

% If there is only one coder then exit out now
if length(EyeData.Coder_ConditionList)==1
    EyeData.Reliability=[];
    EyeData.IncludedCoders=1;
    return
end

Reliability=struct;

for ConditionCounter=1:length(Conditions)
    
    Condition=Conditions(ConditionCounter);
    
    %Iterate through the experiments
    for ExperimentCounter=1:length(Experiments)
        
        
        %Iterate through the trials
        for IdxCounter=1:length(EyeData.Aggregate.(Experiments{ExperimentCounter}))
            
            %Pull out the information from the aggregation
            TimingTemp=EyeData.Timing.(Experiments{ExperimentCounter}){IdxCounter};
            
            %if eye tracking wasn't collected for this trial then skip this
            if ~isempty(TimingTemp)
                
                %% Objective metric of accuracy within participants
                
                for CoderCounter=1:length(EyeData.Coder_ConditionList)
                    
                    %Test for accuracy on the eye tracking calibration
                    if strcmp(Experiments{ExperimentCounter}, 'EyeTrackerCalib')
                        
                        %Take the proportion of responses that are accurate for the
                        %this trial. Use X% of the trial (anchored on the end) in
                        %order to ignore the starting position
                        ResponseList=EyeData.Aggregate.(Experiments{ExperimentCounter}){IdxCounter}(CoderCounter,:);
                        
                        % What is the experiment time when Proportion of
                        % responses should be considered?
                        Threshold=((TimingTemp(end,1) - TimingTemp(1,1))*Proportion_EyeTrackerCalib_Include) + TimingTemp(1,1);
                        
                        %What frames exceed the threshold
                        IncludedFrames= Threshold<TimingTemp(:,1); ResponseList=ResponseList(1:length(IncludedFrames));
                        
                        %What responses are relevant for this participant?
                        Responses=ResponseList(IncludedFrames' & ~isnan(ResponseList));
                        
                        %Pull out the idx name
                        Idx_Name=EyeData.Idx_Names.(Experiments{ExperimentCounter})(IdxCounter,:);
                        
                        %where is the target in coordinates?
                        Origins = Data.(['Experiment_', Experiments{ExperimentCounter}]).(sprintf('Block_%d_%d', Idx_Name(1), Idx_Name(2))).Stimuli.Origin;
                        
                        if size(Origins, 1) >= Idx_Name(3)
                            
                            % Pull out origin
                            Origin=Origins(Idx_Name(3),:);
                            
                            %Categorize the X coordinate to be left, right or centre
                            %NOTICE THIS WAS FLIPPED
                            if Origin(1)<960; X=1;
                            elseif Origin(1)==960; X=3;
                            elseif Origin(1)>960; X=2; %
                            end
                            
                            %Do the same for the Y
                            if Origin(2)<540; Y=1;
                            elseif Origin(2)==540; Y=2;
                            elseif Origin(2)>540; Y=3;
                            end
                            
                            %Store the mean of the response accuracy
                            Reliability.EyeTrackerCalib.X(CoderCounter, IdxCounter)= X;
                            Reliability.EyeTrackerCalib.Y(CoderCounter, IdxCounter)= Y;
                            Reliability.EyeTrackerCalib.ResponseMode(CoderCounter, IdxCounter)= mode(Responses);
                            Reliability.EyeTrackerCalib.ResponseAverage(CoderCounter, IdxCounter)= mean(Responses);
                            Reliability.EyeTrackerCalib.Left_Reports(CoderCounter, IdxCounter)= mean(Responses==1);
                            Reliability.EyeTrackerCalib.Right_Reports(CoderCounter, IdxCounter)= mean(Responses==2);
                            Reliability.EyeTrackerCalib.Centre_Reports(CoderCounter, IdxCounter)= mean(Responses==3);
                            Reliability.EyeTrackerCalib.Undetected(CoderCounter, IdxCounter)= mean(Responses==0);
                            
                            %Find the modal responses for this index and
                            %determine if it is accurate
                            Reliability.EyeTrackerCalib.Accuracy_All(CoderCounter, IdxCounter)= mode(Responses)==X;
                            Reliability.EyeTrackerCalib.Accuracy(CoderCounter, IdxCounter)= mode(Responses(Responses~=0))==X;
                        end
                    elseif strcmp(Experiments{ExperimentCounter}, 'PosnerCuing')
                        
                        %Take the proportion of responses that are accurate for the
                        %this trial. 
                        %Identify the time after the target has appeared
                        %and take the modal response of this participant,
                        %comparing it to what they should have responded
                        
                        ResponseList=EyeData.Aggregate.(Experiments{ExperimentCounter}){IdxCounter}(CoderCounter,:);
                        
                        %Pull out the idx name
                        Idx_Name=EyeData.Idx_Names.(Experiments{ExperimentCounter})(IdxCounter,:);
                        
                        % What is the experiment time when the target
                        % appeared? (In time since the start of the
                        % experiment)
                        if isfield(Data.(['Experiment_', Experiments{ExperimentCounter}]).(sprintf('Block_%d_%d', Idx_Name(1), Idx_Name(2))).Timing, 'TargetOns') && size(Data.(['Experiment_', Experiments{ExperimentCounter}]).(sprintf('Block_%d_%d', Idx_Name(1), Idx_Name(2))).Timing.TargetOns, 1) >= Idx_Name(3)  %If they quit then this matters
                            
                            Target_Onset=Data.(['Experiment_', Experiments{ExperimentCounter}]).(sprintf('Block_%d_%d', Idx_Name(1), Idx_Name(2))).Timing.TargetOns(Idx_Name(3),2)-Data.Global.Timing.Start;
                            
                            %What frames exceed the threshold
                            IncludedFrames= Target_Onset<TimingTemp(:,2); ResponseList=ResponseList(1:length(IncludedFrames));
                            
                            %What responses are relevant for this participant?
                            Responses=ResponseList(IncludedFrames' & ~isnan(ResponseList));
                            
                            CorrectResponse=Data.(['Experiment_', Experiments{ExperimentCounter}]).(sprintf('Block_%d_%d', Idx_Name(1), Idx_Name(2))).Response.Target_Location(Idx_Name(3));
                            
                            % If there is not a modal response then store
                            % as NaN
                            if ~isnan(mode(Responses))
                                
                                %Find the modal responses for this index and
                                %determine if it is accurate
                                ModalResponse=mode(Responses);
                                Reliability.(Experiments{ExperimentCounter}).ModalResponse(CoderCounter, IdxCounter)= ModalResponse;
                                Reliability.(Experiments{ExperimentCounter}).CorrectResponse(CoderCounter, IdxCounter)= CorrectResponse;
                                
                                % Only accept responses that are either
                                % left (1) or right (2)
                                if ModalResponse<3
                                    Reliability.(Experiments{ExperimentCounter}).Accuracy(CoderCounter, IdxCounter)= double(ModalResponse==CorrectResponse);
                                else
                                    Reliability.(Experiments{ExperimentCounter}).Accuracy(CoderCounter, IdxCounter)=NaN;
                                end
                            else
                                Reliability.(Experiments{ExperimentCounter}).ModalResponse(CoderCounter, IdxCounter)=NaN;
                                Reliability.(Experiments{ExperimentCounter}).CorrectResponse(CoderCounter, IdxCounter)=CorrectResponse;
                                Reliability.(Experiments{ExperimentCounter}).Accuracy(CoderCounter, IdxCounter)=NaN;
                            end
                        else
                            Reliability.(Experiments{ExperimentCounter}).ModalResponse(CoderCounter, IdxCounter)=NaN;
                            Reliability.(Experiments{ExperimentCounter}).CorrectResponse(CoderCounter, IdxCounter)=NaN;
                            Reliability.(Experiments{ExperimentCounter}).Accuracy(CoderCounter, IdxCounter)=NaN;
                        end
                    end
                    
                end
                
                %Pull out the fixations for this experiment, trial and the
                %relevant participants and relevant frames
                TrialFixations=EyeData.Aggregate.(Experiments{ExperimentCounter}){IdxCounter};
                
                %Which participants have this condition (and shouldn't be
                %ignored
                potential_coders=find(EyeData.Coder_ConditionList==Condition);
                Coder_Idx=potential_coders(ismember(potential_coders, find(isIncluded_Coder)));
                
                %% Intraframe reliability
                
                
                %What pairs of Coders should be taken
                CoderPairs=combnk(Coder_Idx, 2);
                
                % What pairs of Coders are there?
                for PairCounter=1:size(CoderPairs,1)
                    
                    %Pull out these Coders
                    PairedResponses=TrialFixations(CoderPairs(PairCounter,:), logical(~isnan(TrialFixations(CoderPairs(PairCounter,1),:)) .* ~isnan(TrialFixations(CoderPairs(PairCounter,2),:))));
                    
                    %Check that there are some pairs
                    if sum(~all(isnan(TrialFixations(Coder_Idx,:))'))>=2
                        
                        %Store the reliability
                        Reliability.(Experiments{ExperimentCounter}).Intraframe_Excluded{Condition}(IdxCounter, PairCounter)=mean(diff(PairedResponses(:, PairedResponses(1,:)~=0 & PairedResponses(2,:)~=0))==0);
                        Reliability.(Experiments{ExperimentCounter}).Intraframe{Condition}(IdxCounter, PairCounter)=mean(diff(PairedResponses)==0);
                    else
                        %Store as nans
                        Reliability.(Experiments{ExperimentCounter}).Intraframe_Excluded{Condition}(IdxCounter, PairCounter)=nan;
                        Reliability.(Experiments{ExperimentCounter}).Intraframe{Condition}(IdxCounter, PairCounter)=nan;
                    end
                    
                    %Who are the coders being compared?
                    Reliability.(Experiments{ExperimentCounter}).Intraframe_Coder_Comparisons{Condition}(IdxCounter, PairCounter, :) = CoderPairs(PairCounter,:);
                    
                end
            
                
                %% Interframe reliability
                
                %How similar are the frames for this participant and the
                %reports of the other participants coding of the one after
                if ~isempty(TrialFixations)
                    ComparisonIdx=1;
                    for CurrentCoderCounter=1:length(Coder_Idx)
                        
                        %what are the fixations of this coder?
                        CurrentFixations=TrialFixations(Coder_Idx(CurrentCoderCounter),:);
                        
                        % What frames correspond to the frame after the
                        % ones from this participant?
                        AdjacentIdxs=find(~isnan(CurrentFixations))+1;
                        
                        %If this doesn't exist then skip
                        if ~isempty(AdjacentIdxs)
                            
                            %If the last index exceeds the list then remove it
                            if AdjacentIdxs(end)>length(CurrentFixations)
                                AdjacentIdxs=AdjacentIdxs(1:end-1); %Take off the last index
                            end
                            
                            %Identify the adjacent responses
                            AdjacentFixations=TrialFixations(find(isIncluded_Coder),AdjacentIdxs);
                            
                            %Remove NANs
                            CurrentFixations=CurrentFixations(~isnan(CurrentFixations));
                            AdjacentCoders=find(mean(isnan(AdjacentFixations),2)<1);
                            AdjacentFixations=AdjacentFixations(AdjacentCoders,:);
                            
                            %For the remaining coders, compare the timecourse
                            for AdjacentCoderCounter=1:size(AdjacentFixations,1)
                                
                                idxs=~isnan(AdjacentFixations(AdjacentCoderCounter,:));
                                
                                %How similar are adjacent frames rated?
                                Reliability.(Experiments{ExperimentCounter}).Interframe{Condition}(IdxCounter, ComparisonIdx) = mean((CurrentFixations(idxs) - AdjacentFixations(AdjacentCoderCounter,idxs))==0);
                                
                                %What indexes are compared for this part frame
                                Reliability.(Experiments{ExperimentCounter}).Interframe_Coder_Comparisons{Condition}(IdxCounter, ComparisonIdx, :) = [Coder_Idx(CurrentCoderCounter), AdjacentCoders(AdjacentCoderCounter)];
                                
                                ComparisonIdx=ComparisonIdx+1;
                            end
                        end
                    end
                end
            end
        end
    end
end

% Find the IQR threshold for the Coder performance on the eye tracker calib
% blocks 
if isstr(Accuracy_Threshold_EyeTrackerCalib) && strcmp(Accuracy_Threshold_EyeTrackerCalib, 'IQR') && isfield(Reliability, 'EyeTrackerCalib')
    temp_Accuracy=nanmean(Reliability.EyeTrackerCalib.Accuracy(find(isIncluded_Coder), :),2);
    Accuracy_Threshold_EyeTrackerCalib=prctile(temp_Accuracy,25)-(iqr(temp_Accuracy)*1.5);
end

% Find the IQR threshold for the Coder performance on the posner blocks
if isstr(Accuracy_Threshold_PosnerCuing) && strcmp(Accuracy_Threshold_PosnerCuing, 'IQR') && isfield(Reliability, 'PosnerCuing')
    temp_Accuracy=nanmean(Reliability.PosnerCuing.Accuracy(find(isIncluded_Coder), :),2);
    Accuracy_Threshold_PosnerCuing=prctile(temp_Accuracy,25)-(iqr(temp_Accuracy)*1.5);
end

%Determine whether the coder is sufficiently good to warrant include
for CoderCounter=1:length(EyeData.Coder_ConditionList)
    %What conditon was the coder in
    Condition=EyeData.Coder_ConditionList(CoderCounter);
    
    Coder_name=EyeData.Coder_name{CoderCounter}(1:end-4);
    
    %Report the participant
    fprintf('\n\n\nReliability for %s', EyeData.Coder_name{CoderCounter}(1:end-4));
    
    %Report the eyetracking accuracy
    if isfield(Reliability, 'EyeTrackerCalib')
        Accuracy_EyeTrackerCalib=nanmean(Reliability.EyeTrackerCalib.Accuracy(CoderCounter, :));
        fprintf('\nEyeTrackerCalib accuracy is %0.2f\n', Accuracy_EyeTrackerCalib)
    end
    
    %Report the Posner accuracy
    if isfield(Reliability, 'PosnerCuing')
        Accuracy_PosnerCuing=nanmean(Reliability.PosnerCuing.Accuracy(CoderCounter, :));
        fprintf('\nPosnerCuing accuracy is %0.2f\n', Accuracy_PosnerCuing)
    end
    
    Intraframe=[];
    Interframe=[];
    for ExperimentCounter=1:length(Experiments)
        
        Intraframe_exp=[];
        Interframe_exp=[];
        
        %Was data collected for this experiment
        if isfield(Reliability, Experiments{ExperimentCounter})
            
            %Pull out the indexes of the comparisons for intraframe
            %reliability and then average those trials.
            fprintf('\n%s', Experiments{ExperimentCounter})
            
            if isfield(Reliability.(Experiments{ExperimentCounter}), 'Intraframe_Coder_Comparisons') && length(Reliability.(Experiments{ExperimentCounter}).Intraframe_Coder_Comparisons)>=Condition && ~isempty(Reliability.(Experiments{ExperimentCounter}).Intraframe_Coder_Comparisons{Condition})
                
                IncludedComparisons=any(any(Reliability.(Experiments{ExperimentCounter}).Intraframe_Coder_Comparisons{Condition}==CoderCounter,1),3);
                Intraframe(end+1)=nanmean(nanmean(Reliability.(Experiments{ExperimentCounter}).Intraframe{Condition}(:,IncludedComparisons), 2));
                Intraframe_exp = Intraframe(end);
                fprintf('\nIntraframe reliability: %0.2f', Intraframe(end))
            else
                fprintf('\nDid not find data for %s intraframe reliability', Experiments{ExperimentCounter})
            end
            
            %Are any of the indexes belonging to the coder (hope they don't
            %change based on index)
            if isfield(Reliability.(Experiments{ExperimentCounter}), 'Interframe') && length(Reliability.(Experiments{ExperimentCounter}).Interframe_Coder_Comparisons)>=Condition
                
                IncludedComparisons=any(any(Reliability.(Experiments{ExperimentCounter}).Interframe_Coder_Comparisons{Condition}(:, :, 1)==CoderCounter,1),3);
                Interframe(end+1)=nanmean(nanmean(Reliability.(Experiments{ExperimentCounter}).Interframe{Condition}(:,IncludedComparisons), 2));
                Interframe_exp = Interframe(end);
                fprintf('\nInterframe reliability: %0.2f', Interframe(end))
            else
                fprintf('\nDid not find data for %s interframe reliability', Experiments{ExperimentCounter})
            end
            
        end
        
        Reliability.(Experiments{ExperimentCounter}).Intraframe_all(CoderCounter) = nanmean(Intraframe_exp);
        Reliability.(Experiments{ExperimentCounter}).Interframe_all(CoderCounter) = nanmean(Interframe_exp);
        
    end

    
    % Check whether they pass the performance thresholds (default to yes)
    EyeTrackerCalib_Pass=1;
    if isfield(Reliability, 'EyeTrackerCalib') && mean(Accuracy_EyeTrackerCalib)<Accuracy_Threshold_EyeTrackerCalib
        EyeTrackerCalib_Pass=0;
    end
    
    PosnerCuing_Pass=1;
    if isfield(Reliability, 'PosnerCuing') && mean(Accuracy_PosnerCuing)<Accuracy_Threshold_PosnerCuing
        PosnerCuing_Pass=0;
    end
    
    Reliability_Pass=1;
    if nanmean(Intraframe)<Intraframe_Threshold || nanmean(Interframe)<Interframe_Threshold
        Reliability_Pass=0;
    end
    
    %If this coder is not ignored, do they pass the performance thresholds
    if isIncluded_Coder(CoderCounter)==1
         if EyeTrackerCalib_Pass && PosnerCuing_Pass && Reliability_Pass
            fprintf('\n\n%s will be included.\n', Coder_name);
            IncludedCoders(end+1)=CoderCounter;
        else
            fprintf('\n\n##############\n%s will NOT be included because of low performance\n##############\n', Coder_name);
        end
    else
        fprintf('\n\n##############\n%s will NOT be included because it is in the ignored list.\n##############\n', Coder_name)
    end
    
    
end

EyeData.Reliability=Reliability;
EyeData.IncludedCoders=IncludedCoders;
end
