%% Create regressors of eyes open versus closed
%
% Take in analysed timing (either a path to load or the actual file) and identify the eyedata for this experiment as
% well as the TR timing for this data. Specify which blocks you want to
% make, create regressor file using only the epochs that were included


function EyeTracking_Eye_Closed_Regressor(AnalysedData, Experiment, Output_name_base)

% Load the string if it is appropriate
if isstr(AnalysedData)
    load(AnalysedData)
end


% What blocks were included?
TrialsIncluded=AnalysedData.EyeData.TrialsIncluded.(Experiment);

% What idx names are there?
Idx_Names=AnalysedData.EyeData.Idx_Names.(Experiment);

% Eyes closed
InvalidCodes=0;

% What proportion of eyes closed on a TR is necessary for exclusion
Criteria=0.5;
Burnout_TRs=3; %What is the default burn out TR number?

for IdxCounter=1:size(Idx_Names,1)
    
    BlockNumber=Idx_Names(IdxCounter,1);
    RepetitionNumber=Idx_Names(IdxCounter,2);
    EventNumber=Idx_Names(IdxCounter,3);
    
    % What is the block number
    Block=sprintf('Block_%d_%d', BlockNumber, RepetitionNumber);
    
    %Iterate through the epochs
    %If this epoch is included then make a TR by TR timecourse
    
    TR_EyesClosed=[];
    if TrialsIncluded.(Block)(EventNumber, 1)==1
        
        % What frames are with the eyes closed?
        EyesClosed=AnalysedData.EyeData.Timecourse.(Experiment){IdxCounter}==InvalidCodes;
        
        % What are the TRs 
        TRs=AnalysedData.(sprintf('Experiment_%s', Experiment)).(Block).TRs;
        
        % Remove the burn in and burn out TRs
        FirstTR=length(AnalysedData.(sprintf('Experiment_%s', Experiment)).(Block).BurnInTRs)+1;
        LastTR=length(AnalysedData.(sprintf('Experiment_%s', Experiment)).(Block).RestTRs)-Burnout_TRs;
        TRs = TRs(FirstTR:end-LastTR);
        
        % Put the TRs in eye tracking time
        TRs_EyeTracker=(AnalysedData.EyeData.EyeTrackerTime.slope*TRs)+AnalysedData.EyeData.EyeTrackerTime.intercept;
        
        % What is the time of the frames from this epoch?
        FrameTiming=AnalysedData.EyeData.Timing.(Experiment){IdxCounter}(:,1);
        
        % Iterate through the frames, stopping before the last one
        for TRCounter=1:length(TRs_EyeTracker)-1
            
            % When does the TR start and stop in eye tracker indices
            [~,TR_Onset_Idx]=min(abs(FrameTiming-TRs_EyeTracker(TRCounter)));
            [~,TR_Offset_Idx]=min(abs(FrameTiming-TRs_EyeTracker(TRCounter+1)));
            
            % Store whether this TR is eyes opened versus closed
            TR_EyesClosed(TRCounter)=mean(EyesClosed(TR_Onset_Idx:TR_Offset_Idx))>Criteria;
            
        end
        
        % Print the regressor name and file
        fprintf('Created %s with %d TRs\n%s\n\n', Block, length(TR_EyesClosed), sprintf('%d\n', TR_EyesClosed));
        
        % Make a regressor file
        dlmwrite(sprintf('%s_%s.txt', Output_name_base, Block), TR_EyesClosed')
        
    end
end