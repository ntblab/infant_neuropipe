%% Aggregate the Gaze_Categorization data
%
% Take in the information for a given participant and output the aggregate
% looking behaviors across coders.
%
% This takes as it's input the participant number and the GenerateTrials
% structure (just so it can know the block names)
%
% Aggregate has a field for each experiment which contain a cell vector for
% the eye tracking data as it has been categorized (in absolute terms, not
% relative to each experiment.
%
% If a key is being pressed that isn't recognized then this will be issued
% as a warning. If you see this warning, ALWAYS pay attention to it. You
% should ultimately add to the list, which simply means adding an 'elseif'
% statement to the statement interpreting the acquired frames
%
% Timing is also output from this function. Timing contains both the eye
% tracker time information and the time since the start of the experiment.
% This is organized the same way as aggregate
%
% The aggregated data can be understood/translated using Idx_Names, which is a
% field of EyeData. Each row of Idx_Names identifies what that
% corresponding row in Aggregate/Timing/ImageList refers to.
% The first column of Idx_Names represents the block number, the second
% column is the nth repetition of this block and column three is the nth
% event in the block. This is probably the most risky part of the code
% since there could be issues with how these might align between coders.
%
% Finally this will also output the coder conditions (nth frames these
% participants saw)
%
% First draft, C Ellis 8/5/16
% Added analysis elements, split into multiple functions C Ellis 9/6/16
% Updated to deal with incomplete data C Ellis 2/6/17

function EyeData=EyeTracking_Aggregate(GenerateTrials, ParticipantName, Extension)

if nargin == 1
    Extension='data/Behavioral/';
    ParticipantName='*';
end

if nargin == 2
    Extension='../Coder_Files/';
end

%What coders do you have for this participant
Coders=dir([Extension, ParticipantName, '_Coder_*']);

%Cycle through the coders and get the appropriate information
Aggregate=struct;
Unknown_characters={};
for CoderCounter=1:length(Coders)
    
    %What is the condition the participant is
    if isempty(strfind(Coders(CoderCounter).name, 'all'))
        EyeData.Coder_ConditionList(CoderCounter)=str2num(Coders(CoderCounter).name(end-4));
    else
        EyeData.Coder_ConditionList(CoderCounter)=0; % Means that all frames were coded
    end
    EyeData.Coder_name{CoderCounter}=Coders(CoderCounter).name;
    
    %Load the Coder
    load([Extension, Coders(CoderCounter).name], 'Output', 'ExperimentDefinitions', 'ResponseAllowed', 'TrialCounter', 'ImageList', 'Indexes', 'EyeTrackerTime_slope', 'EyeTrackerTime_intercept', 'TrialType');
   
    %Store for later
    if isfield(Output, 'EyeTrackerTime_slope')
        EyeData.EyeTrackerTime.slope=Output.EyeTrackerTime_slope;
        EyeData.EyeTrackerTime.intercept=Output.EyeTrackerTime_intercept;
    end
        
    %What experiments are being run
    if ~iscell(Output.Timing)
        Experiments=fieldnames(Output.Timing);
        
        %Remove the block suffix from some of them
        for ExperimentCounter = 1:length(Experiments)
            if strfind(Experiments{ExperimentCounter}, '_Block_')
                Experiments_clean{ExperimentCounter}=(1:strfind(Experiments{ExperimentCounter}, '_Block_')-1);
            else
                Experiments_clean{ExperimentCounter}=Experiments{ExperimentCounter};
            end
        end
        
        %Set up the Idx_Names. This reads through all of the trials and
        %stores the corresponding index in the appropriate experiment.
        
        if CoderCounter==1
            
            EyeData.Indexes=Indexes; %Store this
            EyeData.ImageList=ImageList;
            EyeData.Idx_Names=struct; %Preset
            for TrialCounter=1:length(Indexes)
                
                %What is the name of the index for this trial
                Index=Indexes{TrialCounter};
                
                %Store the indexes for this experiment (create the field if
                %necessary
                if isfield(EyeData.Idx_Names, Index{1})
                    EyeData.Idx_Names.(Index{1})(end+1,:)=cell2mat(Index(2:4));
                else
                    EyeData.Idx_Names.(Index{1})=cell2mat(Index(2:4));
                end
                
            end
        else
            % Check whether the indexes of this participant are the same as
            % those that have been found before. If not, fix it
            ExperimentCounter=struct;
            TrialCounter=1;
            rearranged_idxs=0;
            New_Indexes=cell(length(EyeData.Indexes),1);
            while TrialCounter <= length(Indexes)
                
                %What is the name of the index for this trial
                Proposed_Idxs=Indexes{TrialCounter};
                
                % What is the index you should be on
                if isfield(ExperimentCounter, Proposed_Idxs{1})
                    ExperimentCounter.(Proposed_Idxs{1})= ExperimentCounter.(Proposed_Idxs{1}) +1;
                else
                    ExperimentCounter.(Proposed_Idxs{1})=1;
                end
                
                % Does this experiment idx exist?
                if ~isfield(EyeData.Idx_Names, Proposed_Idxs{1})
                    
                    % If there is no experiment then add to the end of the
                    % indexes
                    warning('Coder %d has the experiment %s that Coder 1 does not have. Updating Experiment category', CoderCounter, Proposed_Idxs{1})
                    
                    % Add to the list
                    EyeData.Idx_Names.(Proposed_Idxs{1})=cell2mat(Proposed_Idxs(2:4));
                    
                    % Insert this index into the sequence
                    EyeData.Indexes = [EyeData.Indexes(1:TrialCounter), {Proposed_Idxs}, EyeData.Indexes(TrialCounter+1:end)];
                    
                    % Add the image list
                    Images=ImageList.(Proposed_Idxs{1}){Proposed_Idxs{2}, Proposed_Idxs{3}, Proposed_Idxs{4}};
                    EyeData.ImageList.(Proposed_Idxs{1}){Proposed_Idxs{2}, Proposed_Idxs{3}, Proposed_Idxs{4}}=Images;
                    
                end
                
                %Store the indexes for this experiment (create the field if
                %necessary
                Expected_Idxs={(Proposed_Idxs{1}), EyeData.Idx_Names.(Proposed_Idxs{1})(ExperimentCounter.(Proposed_Idxs{1}),1), EyeData.Idx_Names.(Proposed_Idxs{1})(ExperimentCounter.(Proposed_Idxs{1}),2), EyeData.Idx_Names.(Proposed_Idxs{1})(ExperimentCounter.(Proposed_Idxs{1}),3)};
                
                % Check if the two cells are equal. If not then take the
                % following action
                if ~isequal(Expected_Idxs, Proposed_Idxs)
                    
                    % Print this if there isn't consistency
                    if rearranged_idxs==0
                        warning('Idxs are not in the same order for coders 1 and %d', CoderCounter)
                        rearranged_idxs=1;
                    end
                    
                    % Check whether these indexes exist anywhere. If they do
                    % then reorder the current particpant. If they don't then
                    % append to the end of indexes
                    idx_exists=0;
                    
                    for Idx_Counter=1:length(EyeData.Indexes)
                        
                        % What are the indices for this trial
                        temp_idxs=EyeData.Indexes{Idx_Counter};%{(Proposed_Idxs{1}), EyeData.Idx_Names.(Proposed_Idxs{1})(Idx_Counter,1), EyeData.Idx_Names.(Proposed_Idxs{1})(Idx_Counter,2), EyeData.Idx_Names.(Proposed_Idxs{1})(Idx_Counter,3)};
                        
                        if isequal(temp_idxs, Proposed_Idxs)
                            idx_exists=Idx_Counter;
                        end
                    end
                    
                    % If this has an index then rearrange the values, if it
                    % doesn't exist then add it to the end
                    if idx_exists>0
                        New_Indexes{idx_exists}=Proposed_Idxs;
                    else
                        warning('%s %d %d %d doesn''t exist yet. Adding it', CoderCounter)
                        New_Indexes{end+1}=Proposed_Idxs;
                        EyeData.Indexes{end+1}=Proposed_Idxs;
                        EyeData.Idx_Names.(Proposed_Idxs{1})(end+1,:) = [Proposed_Idxs{2}, Proposed_Idxs{3}, Proposed_Idxs{4}];
                        EyeData.ImageList.(Proposed_Idxs{1})(Proposed_Idxs{2}, Proposed_Idxs{3}, Proposed_Idxs{4}) = ImageList.(Proposed_Idxs{1})(Proposed_Idxs{2}, Proposed_Idxs{3}, Proposed_Idxs{4});
                    end
                    
                end
                
                % Since the length of indexes may change on every trial this
                % might not work
                TrialCounter=TrialCounter+1;
            end
            
            %Replace the indexes
            Indexes=New_Indexes;
        end
        
        %Iterate through experiments
        for ExperimentCounter=1:length(Experiments)
            
            % Take the responses from each trial
            % This is a cell with {BlockNumber, RepetitionNumber, TrialCounter}
            Experiment_Run=Output.Experiment.(Experiments{ExperimentCounter});
            
            %Find what blocks, repetitions and trials the coder did
            Idxs_Run=cellfun(@isempty, Experiment_Run)==0;
            
            %Get the list of indexes that were completed
            Idx_Names=[];
            for BlockCounter=1:size(Idxs_Run,1)
                for RepetitonCounter=1:size(Idxs_Run,2)
                    for EventCounter=1:size(Idxs_Run,3)
                        if Idxs_Run(BlockCounter, RepetitonCounter, EventCounter)==1
                            Idx_Names(end+1,:)=[BlockCounter, RepetitonCounter, EventCounter];
                        end
                    end
                end
            end
            
            
            %             %Define what those indexes are
            %             Idx_Names=[];
            %             for TrialCounter=1:size(Experiment_Run,3)
            %
            %                 %Store the indexes to a temporay file
            %                 Temp=[];
            %                 [Temp(:,1), Temp(:,2)]=find(Idxs_Run(:,:,TrialCounter)==1);
            %
            %                 %Append this to the list
            %                 if ~isempty(Temp)
            %
            %                     %Organized in terms of blocks, repetitions and trials
            %                     Idx_Names(end+1:end+size(Temp,1),:)=([Temp, repmat(TrialCounter, size(Temp,1),1)]);
            %                 end
            %             end
            %
            %             %Store the index names (so long as they are longer than the ones)
            %
            %             EyeData.Idx_Names.(Experiments{ExperimentCounter})=Idx_Names;
            %
            %         %Store just the trials that were run.
            %         Trials_Run=Experiment_Run(Idxs_Run);
            
            %Iterate through these sections of eye tracking that were coded.
            %Pull out the reports as well as timing and image information
            for IdxCounter=1:sum(Idxs_Run(:))
                
                %What does this Idx correspond to in terms of blocks,
                %repetitions and trials?
                Idx_Name=Idx_Names(IdxCounter,:);
                
                %Where in the Idx_Names is list is this Idx_Name
                Idx_Row=find(((EyeData.Idx_Names.(Experiments{ExperimentCounter})(:,1)==Idx_Name(1)) .* (EyeData.Idx_Names.(Experiments{ExperimentCounter})(:,2)==Idx_Name(2)) .* (EyeData.Idx_Names.(Experiments{ExperimentCounter})(:,3)==Idx_Name(3)))==1);
                
                if length(Idx_Row)>1
                    warning('%s Block_%d_%d event %d has been coded more than once. Only considering the first time.', Experiments{ExperimentCounter}, Idx_Name(1), Idx_Name(2), Idx_Name(3))
                    Idx_Row=Idx_Row(1);
                end
                
                %If it hasn't already been done, preset the size
                if ~isfield(Aggregate,  Experiments{ExperimentCounter}) || length(Aggregate.(Experiments{ExperimentCounter})) < Idx_Row || isempty(Aggregate.(Experiments{ExperimentCounter}){Idx_Row})
                    
                    Frames=length(ImageList.(Experiments{ExperimentCounter}){Idx_Name(1), Idx_Name(2), Idx_Name(3)});
                    Aggregate.(Experiments{ExperimentCounter}){Idx_Row}=nan(length(Coders), Frames);
                end
                
                %Pull out the index names
                BlockName=GenerateTrials.(['Experiment_', Experiments_clean{ExperimentCounter}]).Parameters.BlockNames{Idx_Name(1)};
                
                % What frames are there for this experiment.
                Acquired_Frames=Experiment_Run{Idx_Name(1), Idx_Name(2), Idx_Name(3)};
                
                % Count through the frames
                ResponseList=repmat(NaN, length(Acquired_Frames),1);
                for FrameCounter=1:length(Acquired_Frames)
                    
                    %Is there a response on this trial and if so, sort it
                    
                    %If you wish to add a response key then simply add another
                    %elseif statement with the key to response mapping. DO NOT
                    %change the mappings as they exist
                    
                    if ~isempty(Acquired_Frames{FrameCounter})
                        if strcmp(Acquired_Frames{FrameCounter}, 'a') %LeftKey
                            ResponseList(FrameCounter)=1;
                        elseif strcmp(Acquired_Frames{FrameCounter}, 'd') %RightKey
                            ResponseList(FrameCounter)=2;
                        elseif strcmp(Acquired_Frames{FrameCounter}, 's') %CentreKey
                            ResponseList(FrameCounter)=3;
                        elseif strcmp(Acquired_Frames{FrameCounter}, 'x') %OffCentreKey
                            ResponseList(FrameCounter)=4;
                        elseif strcmp(Acquired_Frames{FrameCounter}, 'e') %PresentKey
                            ResponseList(FrameCounter)=5;
                        elseif strcmp(Acquired_Frames{FrameCounter}, 'LeftShift') %Undetected
                            ResponseList(FrameCounter)=6;
                        elseif strcmp(Acquired_Frames{FrameCounter}, 'w') %Up
                            ResponseList(FrameCounter)=7;
                        elseif strcmp(Acquired_Frames{FrameCounter}, 'z') %Down
                            ResponseList(FrameCounter)=8;
                        elseif strcmp(Acquired_Frames{FrameCounter}, 'u') %UpLeft
                            ResponseList(FrameCounter)=9;
                        elseif strcmp(Acquired_Frames{FrameCounter}, 'i') %UpRight
                            ResponseList(FrameCounter)=10;
                        elseif strcmp(Acquired_Frames{FrameCounter}, 'j') %DownLeft
                            ResponseList(FrameCounter)=11;
                        elseif strcmp(Acquired_Frames{FrameCounter}, 'k') %DownRight
                            ResponseList(FrameCounter)=12;
                        elseif strcmp(Acquired_Frames{FrameCounter}, 'space') %NoEyeKey
                            ResponseList(FrameCounter)=0;
                        else
                            %Issue a warning for other responses
                            if isempty(strcmp(Unknown_characters, Acquired_Frames{FrameCounter})) || all(strcmp(Unknown_characters, Acquired_Frames{FrameCounter})==0)
                                warning(sprintf('Unknown character: %s found', Acquired_Frames{FrameCounter}));
                                Unknown_characters{end+1}=Acquired_Frames{FrameCounter};
                            end
                        end
                    end
                    
                end
                
                %Extract the timing information for the frames taken in the
                %experiment
                
                ImageList_Temp=ImageList.(Experiments{ExperimentCounter}){Idx_Name(1), Idx_Name(2), Idx_Name(3)};
                
                %Pull out the timing of the frames that were completed.
                TimingTemp=[];
                for Counter=1:length(ImageList_Temp)
                    %When is the start and the end of this number
                    MinIdx=max(strfind(ImageList_Temp{Counter}, '_'))+1;
                    MaxIdx=max(strfind(ImageList_Temp{Counter}, '.'))-1;
                    
                    %Store the number
                    TimingTemp(end+1)=str2num(ImageList_Temp{Counter}(MinIdx:MaxIdx));
                end
                
                % Determine what is the first frame after the stimulus
                % onsets (accounting for any lag that may come)
                epoch_onset_msg = TrialType.(Experiments{ExperimentCounter}){Idx_Name(1), Idx_Name(2), Idx_Name(3)}; % What is the message that specifies the epoch onset
                epoch_onset_mat = str2num(epoch_onset_msg(max([max(strfind(epoch_onset_msg, '_')), max(strfind(epoch_onset_msg, ' ')), max(strfind(epoch_onset_msg, ':'))]) + 1:end));
                epoch_onset_eyetracker = (epoch_onset_mat * EyeTrackerTime_slope) + EyeTrackerTime_intercept;
                
                %Store the timing information, both the eye tracker time and
                %the time since the experiment started
                onset_frame = 0;
                for CoderFrames=find(~isnan(ResponseList))'
                    Timing.(Experiments{ExperimentCounter}){Idx_Row}(CoderFrames,:) = [ TimingTemp(CoderFrames), Output.Timing.(Experiments{ExperimentCounter}){Idx_Name(1), Idx_Name(2), Idx_Name(3)}{CoderFrames}{1}];
                    
                    % Check if a frame is past the onset time when
                    % accounting for lag
                    if onset_frame == 0 && ~isempty(epoch_onset_eyetracker) && TimingTemp(CoderFrames) > epoch_onset_eyetracker
                       onset_frame = CoderFrames; 
                    end
                end
                
                % What frame for this ppt was the first to be considered
                EyeData.onset_frame.(Experiments{ExperimentCounter})(Idx_Name(1), Idx_Name(2), Idx_Name(3)) = onset_frame;
                
                % Append the response list to the data 
                Aggregate.(Experiments{ExperimentCounter}){Idx_Row}(CoderCounter, 1:length(ResponseList))=ResponseList;
                
                
            end
        end
    end
end

% Remove all the frames corresponding to the epoch before the stimulus was
% on the screen

for idx_counter = 1:length(EyeData.Indexes)
    
    % Pull out the 4 element index information
    idx = EyeData.Indexes{idx_counter};
    
    % Find the matching idx
    matched_idx = find(all((EyeData.Idx_Names.(idx{1}) - [idx{2}, idx{3}, idx{4}]) == 0, 2));
    
    if length(matched_idx) > 1
        matched_idx = 1;
        %fprintf('For %s Block_%d_%d %d multiple matches found, using the first one\n', idx{1}, idx{2}, idx{3}, idx{4});
    end
    
    % Edit the information
    onset_frame = EyeData.onset_frame.(idx{1})(idx{2}, idx{3}, idx{4});
    
    if onset_frame > 2
        fprintf('Onset for %s Block_%d_%d %d is %d\n', idx{1}, idx{2}, idx{3}, idx{4}, onset_frame);
    end
    
    % Make frames that weren't set equal to 1 in order to ensure it is
    % done
    if onset_frame < 1
        fprintf('Onset for %s Block_%d_%d %d was not set\n', idx{1}, idx{2}, idx{3}, idx{4});
        onset_frame = 1;
    end
    
    ImageList.(idx{1}){idx{2}, idx{3}, idx{4}} = ImageList.(idx{1}){idx{2}, idx{3}, idx{4}}(onset_frame:end);
    Aggregate.(idx{1}){matched_idx} = Aggregate.(idx{1}){matched_idx}(:, onset_frame:end);
    Timing.(idx{1}){matched_idx} = Timing.(idx{1}){matched_idx}(onset_frame:end, :);
    
end

%Store this data for later
EyeData.Aggregate=Aggregate;
EyeData.Timing=Timing;
EyeData.ImageList=ImageList;


end
