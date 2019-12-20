%% Generate average responses for fixations
%
% The inputs are as follows:
%
% Aggregate: Contains the information needed for the responses
% Data: Needed to know what kind of stimulus is expected
% 
%ResponseKey
% LeftKey='a'; %Otherwise coded as 1
% RightKey='d'; %Otherwise coded as 2
% CentreKey='s'; %Otherwise coded as 3
% OffCentreKey='x'; %Otherwise coded as 4
% PresentKey='e'; %Otherwise coded as 5
% UndetectedKey='LeftShift'; %Otherwise coded as 6
% NoEyeKey='space'; %Otherwise coded as 0
% UpKey='w'; %Otherwise coded as 7
% DownKey='z'; %Otherwise coded as 8
% UpLeft='u'; %Otherwise coded as 9
% UpRight='i'; %Otherwise coded as 10
% DownLeft='j'; %Otherwise coded as 11
% DownRight='k'; %Otherwise coded as 12
%
% There are four types of outputs, Organized by experiment and then
% index (as read in the EyeData.Idx_Names organization)
%
% Proportions:
% What proportion of fixations in a trial are to any of the given
% categories, each for different coders. 
%
% TimeCourse:
% What is the time course of where the participant was looking, aggregating across coders 
%
% For each of these responses there will be one output per trial/idx and
% this will be excluded if necessary.
%
%
% Established as a stand alone function, C Ellis 9/8/16
function EyeData=EyeTracking_Responses(EyeData, EyeTrackerLag)

Experiments=fieldnames(EyeData.Aggregate);

% Get the path to the Gaze_Categorization
globals=read_globals;
addpath([globals.PROJ_DIR, 'scripts/']);

% Load the information
Gaze_Categorization_Responses

CodedResponses=[0 1 2 3 4 5 6 7 8 9 10 11 12]; %What responses are coded
Window_width=5; %How big is the response window

%What coders ought to be used
IncludedCoders=EyeData.IncludedCoders;

%Iterate through the experiment counter
for ExperimentCounter=1:length(Experiments)
    
    % What responses are allowed
    for temp_counter=1:size(ExperimentDefinitions,1)
        if ~isempty(strfind(ExperimentDefinitions{temp_counter, 1}, Experiments{ExperimentCounter}))
            % WHich responses (in terms of numbers) are allowed for this experiment
            Responses_Available=ResponseAllowed_code{ExperimentDefinitions{temp_counter,end}};
        end
    end
    
    % Make a temp response names (where you ignore the non pressed
    % responses
    Temp_ResponseNames=ResponseNames;
    Temp_ResponseNames(setdiff(CodedResponses, Responses_Available)+1)={'x'};
    
    %Iterate through each trial
    for IdxCounter=1:length(EyeData.Aggregate.(Experiments{ExperimentCounter}))
        
        %% Pull out the coder reports for this time period
        
        %Store the data for this event
        Event_Data=EyeData.Aggregate.(Experiments{ExperimentCounter}){IdxCounter};
        
        %If no frames were collected on this trial then put nans in for the
        %participant
        if isempty(Event_Data)
            Event_Data=ones([length(EyeData.Coder_ConditionList), 1])*nan;
        end
        
        %Checks if only the specify coded responses are given
        if any(Event_Data(:)>max(CodedResponses(:)))
            warning(sprintf('!!! Response %d is not coded for, add to the coded response options', find(Event_Data(:)>max(CodedResponses(:)))));
        end
        
        %% Make a timecourse of participant responses
        
        %Take a moving average of the data, getting the modal response of
        %the window
        
        for StartingFrame=1:size(Event_Data,2)
            
            %Establish the idxs of the window
            Frame_Idxs=StartingFrame-floor(Window_width/2):StartingFrame+floor(Window_width/2);
            
            %Check that none of the indexes are bounded
            Frame_Idxs=Frame_Idxs(Frame_Idxs<=size(Event_Data,2));
            Frame_Idxs=Frame_Idxs(Frame_Idxs>0);
            
            %What is the window of the data
            Window=Event_Data(IncludedCoders,Frame_Idxs);
            
            %Work out the modal response (the mode function doesn't deal
            %with ties correctly: if there is a tie then it will just pick
            %the smallest number)
            
            Responses=unique(Window(:));
            
            Response_Bin=[]; % Reset
            for Response_Counter=1:length(Responses)
                Response_Bin(Response_Counter)=sum(Window(:)==Responses(Response_Counter));
            end
            
            %What response should you choose?
            if sum(Response_Bin==max(Response_Bin))==1
                %If there is only one bin with the most choices then choose
                %that
                Response=Responses(Response_Bin==max(Response_Bin));
            else
                
                %If there is a tie then set to past frame
                if StartingFrame > 1
                    Response=Timecourse.(Experiments{ExperimentCounter}){IdxCounter}(StartingFrame-1);
                else
                    %Set to zero if this is the first frame
                    Response=0;
                end
            end
            
            Timecourse.(Experiments{ExperimentCounter}){IdxCounter}(StartingFrame)=Response;
            
            % What is the consensus for this frame (proportion of coders
            % that agree)
            Consensus.(Experiments{ExperimentCounter}){IdxCounter}(StartingFrame) = sum(min(Response_Bin(Response_Bin==max(Response_Bin)))) / sum(Response_Bin);
        end
        
        %% Calculate the proportion of looking time for participants.
        
        %Take the aggregate measure of looking data
        ResponseCounts=hist(Timecourse.(Experiments{ExperimentCounter}){IdxCounter}, CodedResponses);
        
        % What are the responses (each item versus all)?
        Proportions.(Experiments{ExperimentCounter}).Responses_Available=Temp_ResponseNames;
        Proportions.(Experiments{ExperimentCounter}).Responses_All(IdxCounter,:)=ResponseCounts./sum(ResponseCounts);
        Proportions.(Experiments{ExperimentCounter}).ResponsesCounts_All(IdxCounter,:)=ResponseCounts;
        
        %Store for each Coder
        if ~isempty(EyeData.Aggregate.(Experiments{ExperimentCounter}){IdxCounter})
            for Coder=1:size(EyeData.Aggregate.(Experiments{ExperimentCounter}){IdxCounter},1)
                
                Temp_ResponseCounts=hist(EyeData.Aggregate.(Experiments{ExperimentCounter}){IdxCounter}(Coder,:), CodedResponses);
                Proportions_participant.(Experiments{ExperimentCounter}).Responses_All(IdxCounter,:,Coder)=Temp_ResponseCounts./sum(Temp_ResponseCounts);
            end
        else
            % Preset the matrix if there is no data. If there is only one
            % coder you need to be explicit about the shape of the data
            if length(EyeData.Coder_name) > 1
                Proportions_participant.(Experiments{ExperimentCounter}).Responses_All(IdxCounter,:,:)=ones(1, size(ResponseCounts,2), length(EyeData.Coder_name))*NaN;
            else
                Proportions_participant.(Experiments{ExperimentCounter}).Responses_All(IdxCounter,:,1)=ones(size(ResponseCounts,2), 1)*NaN;
            end
        end
        
        %What responses are there? These comparisons will be untested in
        %some participants
        Proportions.(Experiments{ExperimentCounter}).LeftvsRight(IdxCounter)=ResponseCounts(2)./sum(ResponseCounts([2,3])); %Proportion of left vs right
        Proportions.(Experiments{ExperimentCounter}).CentrevsNotCentre(IdxCounter)=ResponseCounts(4)./sum(ResponseCounts([4,5])); %Proportion of centre vs not centre, right and undetected
        Proportions.(Experiments{ExperimentCounter}).PresentVsNoEye(IdxCounter)=ResponseCounts(6)./sum(ResponseCounts([1, 6])); %Proportion of detected vs not detected
        
    end
    
    %Print the results
    fprintf('\nOverall proportion for %s:\n',Experiments{ExperimentCounter});
    
    Proportions_hist=mean(Proportions.(Experiments{ExperimentCounter}).Responses_All,1);
    for ResponseCounter=1:length(Temp_ResponseNames)
        fprintf('%s: %0.2f\n',  Temp_ResponseNames{ResponseCounter}, Proportions_hist(ResponseCounter));
    end
    
    %Store for each participant
    for Coder=1:length(EyeData.Coder_name)
        fprintf('\nProportion for %s:\n',EyeData.Coder_name{Coder});
        Proportions_hist=nanmean(Proportions_participant.(Experiments{ExperimentCounter}).Responses_All(:,:,Coder),1);
        for ResponseCounter=1:length(Temp_ResponseNames)
            fprintf('%s: %0.2f\n',  Temp_ResponseNames{ResponseCounter}, Proportions_hist(ResponseCounter));
        end
    end
    fprintf('\n\n')
    
end

%Store the data in the structure
EyeData.Proportions=Proportions;
EyeData.Timecourse=Timecourse;
EyeData.Consensus=Consensus;

end
