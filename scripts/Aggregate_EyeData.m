% Aggregate eye tracker coding information
%
% Take in the eye tracker information from all experiments and organize it
% by experiment and also by coder. Only consider included coders
%
% Ellis 7/18/17

function Aggregate_EyeData

% What participants are there?
participants=dir('subjects/');

Aggregate.Accuracy.EyeTrackerCalib=struct;
Aggregate.Accuracy.PosnerCuing=struct;
Aggregate.Intraframe=struct;
Aggregate.Interframe=struct;
Participants_Collected={};
Coders_Collected={};
for participant_counter=1:length(participants)
    
    try
        filename=['subjects/', participants(participant_counter).name, '/analysis/Behavioral/EyeData.mat'];
        load(filename);
        
        % Store the info about the participants and coders
        Participants_Collected{end+1}=participants(participant_counter).name;
        Coders_Collected{end+1}={};
        
        Experiments=fieldnames(EyeData.Reliability);
        
        %Iterate through the includedcoders
        for CoderCounter=1:length(EyeData.IncludedCoders)
            
            % What coder are they?
            Coder_Idx=EyeData.IncludedCoders(CoderCounter);
            temp=EyeData.Coder_name{Coder_Idx};
            Coder_Initials=temp(strfind(temp, 'Coder_')+6:strfind(temp, 'Coder_')+7);
            condition=temp(strfind(temp, Coder_Initials)+3:strfind(temp, Coder_Initials)+3);
            
            if isfield(EyeData.Reliability, 'EyeTrackerCalib')
                
                if ~isfield(Aggregate.Accuracy.EyeTrackerCalib, Coder_Initials)
                    Aggregate.Accuracy.EyeTrackerCalib.(Coder_Initials)=[];
                end
                
                Aggregate.Accuracy.EyeTrackerCalib.(Coder_Initials)(end+1)=nanmean(EyeData.Reliability.EyeTrackerCalib.Accuracy(Coder_Idx, :));
                
            end
            
            if isfield(EyeData.Reliability, 'PosnerCuing')
                
                if ~isfield(Aggregate.Accuracy.PosnerCuing, Coder_Initials)
                    Aggregate.Accuracy.PosnerCuing.(Coder_Initials)=[];
                end
                
                Aggregate.Accuracy.PosnerCuing.(Coder_Initials)(end+1)=nanmean(EyeData.Reliability.PosnerCuing.Accuracy(Coder_Idx, :));
                
            end
            
            Condition=EyeData.Coder_ConditionList(Coder_Idx);
            for Experiment_Counter=1:length(Experiments)
                
                
                if isfield(EyeData.Reliability.(Experiments{Experiment_Counter}), 'Intraframe')
                    
                    %Preset if haven't been made yet
                    if ~isfield(Aggregate.Intraframe, Experiments{Experiment_Counter})
                        Aggregate.Intraframe.(Experiments{Experiment_Counter})=[];
                    end
                    
                    if ~isfield(Aggregate.Intraframe, Coder_Initials)
                        Aggregate.Intraframe.(Coder_Initials)=[];
                    end
                    
                    % What participants are appropriate for this coder?
                    IncludedComparisons=any(any(EyeData.Reliability.(Experiments{Experiment_Counter}).Intraframe_Coder_Comparisons{Condition}==Coder_Idx,1),3);
                    Intraframe=nanmean(nanmean(EyeData.Reliability.(Experiments{Experiment_Counter}).Intraframe{Condition}(:,IncludedComparisons), 2));
                    
                    %Add for this experiment and for this coder
                    Aggregate.Intraframe.(Experiments{Experiment_Counter})(end+1)=Intraframe;
                    Aggregate.Intraframe.(Coder_Initials)(end+1)=Intraframe;
                    
                end
                
                if isfield(EyeData.Reliability.(Experiments{Experiment_Counter}), 'Interframe')
                    
                    %Preset if haven't been made yet
                    
                    if ~isfield(Aggregate.Interframe, Experiments{Experiment_Counter})
                        Aggregate.Interframe.(Experiments{Experiment_Counter})=[];
                    end
                    
                    if ~isfield(Aggregate.Interframe, Coder_Initials)
                        Aggregate.Interframe.(Coder_Initials)=[];
                    end
                    
                    % What participants are appropriate for this coder?
                    IncludedComparisons=any(any(EyeData.Reliability.(Experiments{Experiment_Counter}).Interframe_Coder_Comparisons{Condition}(:, :, 1)==Coder_Idx,1),3);
                    Interframe=nanmean(nanmean(EyeData.Reliability.(Experiments{Experiment_Counter}).Interframe{Condition}(:,IncludedComparisons), 2));
                    
                    %Add for this experiment and for this coder
                    Aggregate.Interframe.(Experiments{Experiment_Counter})(end+1)=Interframe;
                    Aggregate.Interframe.(Coder_Initials)(end+1)=Interframe;
                end
            end
            
            % Add to the list
            Coders_Collected{end}{end+1}=[Coder_Initials, '_', condition];
            
        end
        if length(EyeData.IncludedCoders)==0
            fprintf('No coders for %s\n', participants(participant_counter).name);
        end
    catch
        fprintf('Skipping %s\n', participants(participant_counter).name);
    end
end


%Output reports
fprintf('\n\n#####################\nParticipants Collected\n#####################\n\n');
CollectedParticipants=~cellfun(@isempty, Coders_Collected);
for Participant_counter=1:length(Participants_Collected)
    if CollectedParticipants(Participant_counter)==1
        fprintf('%s: %s\n', Participants_Collected{Participant_counter}, sprintf('%s ', Coders_Collected{Participant_counter}{:})); 
    end
end


fprintf('\n\n#####################\nAccuracy for EyeTrackerCalib\n#####################\n\n');

for Coder_Counter=1:length(fieldnames(Aggregate.Accuracy.EyeTrackerCalib))
    coders=fieldnames(Aggregate.Accuracy.EyeTrackerCalib);
    fprintf('%s: %0.2f (%d)\n', coders{Coder_Counter}, mean(Aggregate.Accuracy.EyeTrackerCalib.(coders{Coder_Counter})), length(Aggregate.Accuracy.EyeTrackerCalib.(coders{Coder_Counter})));
end

fprintf('\n\n#####################\nAccuracy for PosnerCuing\n#####################\n\n');

for Coder_Counter=1:length(fieldnames(Aggregate.Accuracy.PosnerCuing))
    coders=fieldnames(Aggregate.Accuracy.PosnerCuing);
    fprintf('%s: %0.2f (%d)\n', coders{Coder_Counter}, mean(Aggregate.Accuracy.PosnerCuing.(coders{Coder_Counter})), length(Aggregate.Accuracy.PosnerCuing.(coders{Coder_Counter})));
end

fprintf('\n\n#####################\nAverage Intraframe reliability\n#####################\n');
Fields=fieldnames(Aggregate.Intraframe);
for Field_Counter=1:length(Fields)
    fprintf('%s: %0.2f (%d)\n', Fields{Field_Counter}, nanmean(Aggregate.Intraframe.(Fields{Field_Counter})), length(Aggregate.Intraframe.(Fields{Field_Counter})));
end

fprintf('\n\n#####################\nAverage Interframe reliability\n#####################\n');
Fields=fieldnames(Aggregate.Interframe);
for Field_Counter=1:length(Fields)
    fprintf('%s: %0.2f (%d)\n', Fields{Field_Counter}, nanmean(Aggregate.Interframe.(Fields{Field_Counter})), length(Aggregate.Interframe.(Fields{Field_Counter})));
end
