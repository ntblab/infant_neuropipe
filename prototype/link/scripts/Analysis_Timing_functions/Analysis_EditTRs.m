%%  Edit the TRs in case of any issues
%
% Takes in a run's data and identifies when there seem to be some issues
% that ought to be corrected.
%
%The following actions are taken, where appropriate
%     Removing duplicate TRs
%     Interpolating TRs (within a Task)
%     Generating Task TRs (If no TRs were recorded within an experiment)
%     Guessing Task TRs when you quit and have no TRs
%     Finding Burn in TRs
%     TRs out of order
%
function [Edited_Data, InterpolatedTRs, PlottedGuessedTRs, PrintLog]=Analysis_EditTRs(Data, MostRecentExperiment, Window, RunOrder_Time, ExperimentName)

%Pull out the relevatn data
TR=Window.TR;
BurnInTRs=Window.BurnIn - 1; %Minus one because only N-1 were collected
Edited_Data=Data.Timing;

InterpolatedTRs=[]; %Preset the size
PlottedGuessedTRs=[]; %Assume empty
PrintLog='';

EditsPerformed=zeros(1,6); %What edits were actually done?

%Delete all double reads of TRs
if any(diff(Edited_Data.TR)<TR*0.5)
    
    
    %Iterate through the TRs
    TRCounter=1;
    while TRCounter<=length(Edited_Data.TR)-1 %Don't take the last 2 to avoid idxing out
        
        
        %Are TRs close registered as close in time
        AdjacentDifference=Edited_Data.TR(TRCounter+1)-Edited_Data.TR(TRCounter)<TR*0.5;
        
        if  AdjacentDifference
            Edited_Data.TR=[Edited_Data.TR(1:TRCounter), Edited_Data.TR(TRCounter+2:end)];
            EditsPerformed(1)=1; %There has been at least one change of this type
        else
            TRCounter=TRCounter+1; %Only increment when there is a sufficient difference
        end
        
    end
    
end

%Are you going to interpolate the TRs (whenever there is a gap then
%fill it)

if any(diff(Edited_Data.TR)>TR*1.1)
    
    
    %Iterate through the TRs
    TRCounter=1;
    while TRCounter<length(Edited_Data.TR) %One less than the list or else you will index out of bounds
        
        %If there is a gap of 3 TRs then fill it in
        if  Edited_Data.TR(TRCounter+1)-Edited_Data.TR(TRCounter)>TR*1.1
            
            GapTRs= Edited_Data.TR(TRCounter):TR:Edited_Data.TR(TRCounter+1); %Make the time stamps for the TRs
            
            %What index are you taking? This will be different
            %depending on whether there is still a gap between this
            %last interpolated TR and the real TRs
            if abs(GapTRs(end)-Edited_Data.TR(TRCounter+1))>(TR*.9)
                GapTRs=GapTRs(2:end);
            else
                GapTRs=GapTRs(2:end-1);
            end
            
            InterpolatedTRs=[InterpolatedTRs, GapTRs];
            
            Edited_Data.TR = [Edited_Data.TR(1:TRCounter), GapTRs, Edited_Data.TR(TRCounter+1:end)]; %Store these interpolated TRs
            EditsPerformed(2)=1; %There has been at least one change of this type
        end
        
        TRCounter=TRCounter+1;
    end
end


%If there are no TRs recorded until the decay then work backwards
if ~isempty(Edited_Data.TR) && RunOrder_Time<Edited_Data.TR(1)
    
    
    %When was the last TR of the previous block? Continue from
    %that, max this value out at 4 TRs.
    if ~isempty(MostRecentExperiment.TR)
        WarmUpTRTime=MostRecentExperiment.TR(end)+TR;
        WarmUpTRTime(Edited_Data.TestStart - WarmUpTRTime >TR*BurnInTRs)=Edited_Data.TestStart - TR*BurnInTRs;
    else %If it was not an experiment last time then you had a full burn in
        WarmUpTRTime=Edited_Data.TestStart - TR*BurnInTRs;
    end
    
    GapTRs=fliplr(Edited_Data.TR(1): -TR : WarmUpTRTime); %Start from the anchor and go backwards
    
    
    %What index do you start at? Depends on the Gap TR value
    if ~isempty(MostRecentExperiment.TR) && mod(Edited_Data.TR(1)-MostRecentExperiment.TR(end),TR)<0.5*TR
        Idx=2;
    else
        Idx=1;
    end
    
    InterpolatedTRs=[InterpolatedTRs, GapTRs(Idx:end-1)]; %Add to the list
    Edited_Data.TR = [GapTRs(Idx:end-1), Edited_Data.TR]; %Store these interpolated TRs (don't use RealTRs so that these added TRs can combine
    
    EditsPerformed(3)=1; %There has been at least one change of this type
end

%If this is a quit block but not a video block
if Data.Quit==1 && isempty(strfind('Experiment_PlayVideo Experiment_EyeTrackerCalib', ExperimentName)) && isempty(Edited_Data.TR) && (Edited_Data.TestStart-RunOrder_Time)>(TR*1.1)
    
    %How many TRs do you think were read
    GuessedTRs=floor((Edited_Data.TestEnd-MostRecentExperiment.TR(end))/TR);
    
    PlottedGuessedTRs=MostRecentExperiment.TR(end)+TR:TR:MostRecentExperiment.TR(end) + (GuessedTRs*TR);
    
    Edited_Data.TR = PlottedGuessedTRs;
    
    EditsPerformed(4)=1; %There has been at least one change of this type
end


%Are there any TRs between the last experiment and this one? Could miss
%a TR if it comes in in between listening
if isempty(strfind('Experiment_PlayVideo Experiment_EyeTrackerCalib Experiment_MemTest', ExperimentName)) && ~isempty(MostRecentExperiment.TR) && ~isempty(Edited_Data.TR) && ((Edited_Data.TR(1)-MostRecentExperiment.TR(end))>TR*1.1)  && ((Edited_Data.TR(1)-MostRecentExperiment.TR(end))<TR*5)
    
    
    
    GapTRs=fliplr(Edited_Data.TR(1): -TR : MostRecentExperiment.TR(end)); %Start from the anchor and go backwards
    
    %What index doe you start at? Depends on the Gap TR value
    if mod(Edited_Data.TR(1)-MostRecentExperiment.TR(end),TR)<0.5*TR
        Idx=2;
    else
        Idx=1;
    end
    
    InterpolatedTRs=[InterpolatedTRs, GapTRs(Idx:end-1)];
    
    Edited_Data.TR=[GapTRs(Idx:end-1), Edited_Data.TR]; %Add these TRs on to the start
    
    EditsPerformed(5)=1; %There has been at least one change of this type
    
end

%Reorder the TRs if necessary
if sum(sort(Edited_Data.TR)-Edited_Data.TR)>0
    
    Edited_Data.TR=sort(Edited_Data.TR);
    EditsPerformed(6)=1; %There has been at least one change of this type
end

%Provide a list of what is changed for each TR

if any(EditsPerformed)==1
    %Store what is to be printed
    PrintLog=[PrintLog, sprintf('\n\nFollowing edits were made:')];
    
    %What edits do the EditsPerformed idxs correspond to 
    EditTypes={'Removing duplicate TRs',...
    'Interpolating TRs',...
    'Generating Task TRs',...
    'Guessing Task TRs when you quit and have no TRs',...
    'Finding Burn In TRs',...
    'TRs out of order'};
    
    %Print the completed edits
    PrintLog=[PrintLog, sprintf('\n%s', EditTypes{find(EditsPerformed==1)})];

end

PrintLog=[PrintLog, sprintf('\n')];