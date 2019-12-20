
%% Identify every TR with an experiment, block, repetition and event and label them
function [AnalysedData, PrintLog] = Timing_TR_Timecourse(AnalysedData, ExperimentName, BlockName, Functional_Counter, Timing, PrintLog)        


% Make text for the events

idxs=strfind(BlockName, '_');
BlockNumber=str2num(BlockName((idxs(1) + 1):(idxs(2) - 1)));
RepetitionCounter=str2num(BlockName(idxs(2) + 1:end));

Text={ExperimentName; BlockNumber; RepetitionCounter};
Timecourse=repmat(Text,1,length(AnalysedData.(ExperimentName).(BlockName).block_TRs));

%Are there events for this data, 0 means burn in and decay
if isfield(Timing, 'Events')
    
    %Preset
    EventList=cell(1, AnalysedData.BurnIn_Surplus + AnalysedData.(ExperimentName).(BlockName).TaskTRs);
    
    %Put zeros in for the burn in
    if AnalysedData.BurnIn_Surplus>0
        for TRCounter = 1:AnalysedData.BurnIn_Surplus
            EventList{TRCounter}=0;
        end
    end
    
    %If it is a zero then it will try index the zeroth element
    if Timing.InitialWait<=0
        PrintLog=[PrintLog, sprintf('\nBug with events: Initial Wait can''t be set to zero, making it 0.001\n')];
        Timing.InitialWait=0.001;
    end
    
    %Preset the start of the first event
    Event_End=(AnalysedData.BurnIn_Surplus/ AnalysedData.TR(Functional_Counter))+Timing.InitialWait;
    
    %Identify what times correspond to events
    for EventCounter=1:Timing.Events
        
        %When does this event start
        Event_Start=Event_End;
        
        %What time does the event end
        Event_End=Event_Start+Timing.TimeElapsed_Events(EventCounter);
        
        %What TR idxs are used
        TR_Start=ceil(Event_Start/AnalysedData.TR(Functional_Counter));
        TR_End=ceil(Event_End/AnalysedData.TR(Functional_Counter));
        
        %Increase the length of the event list
        while length(EventList)<=TR_End
            EventList{end+1}=[];
        end
        
        %Store the events (may be multiple in a single TR
        for TRCounter=TR_Start:TR_End
            EventList{TRCounter}(end+1)=EventCounter;
        end
    end
    
    % If there are no events then set this
    if Timing.Events == 0
        TR_End=AnalysedData.(ExperimentName).(BlockName).TaskTRs; % Preset just incase there are zero events
    end
    
    %Extend this out if it isn't long enough
    if TR_End<(AnalysedData.(ExperimentName).(BlockName).TaskTRs + AnalysedData.BurnIn_Surplus)
        EventList(TR_End:(AnalysedData.(ExperimentName).(BlockName).TaskTRs+AnalysedData.BurnIn_Surplus))={EventCounter};
    end
    
    %Add the TRs for the event
    EventList=[EventList, repmat({0}, 1, AnalysedData.(ExperimentName).(BlockName).RestTRs)];
    
else
    
    %Store the events
    EventList=[repmat({0}, 1, AnalysedData.BurnIn_Surplus), repmat({1}, 1, AnalysedData.(ExperimentName).(BlockName).TaskTRs), repmat({0}, 1, AnalysedData.(ExperimentName).(BlockName).RestTRs)];
end

%If these are the wrong size (usually because the block was
%aborted) then only take what TRs were actually recorded
Timecourse(4,:)=EventList(1:size(Timecourse,2));

%Store the data
AnalysedData.Timecourse{Functional_Counter}(:, AnalysedData.(ExperimentName).(BlockName).block_TRs)=Timecourse;
AnalysedData.(ExperimentName).(BlockName).EventList=EventList;

end