%% Summarize eye tracking data for Subsequent Memory interleaved version
%
% Pull out gaze behavior and then create both a plot and regressor of it
%
% To add an experiment, create the function which takes in the following
% inputs: EyeData, Data, GenerateTrials. The output is EyeData but probably
% including (any or all) are Weights, ReactionTime and Exclude. Be careful
% when making this that you don't overwrite any of the previous entries
% (Which is why each experiment should have its own subfield of Weights,
% ReactionTime and Exclude)
%
% First draft -- TSY 12/20/2019
% Edits 01/06/2020
% Fix for multiple iterations of block 1 (start from last trial) 03/02/2020
% Start from last trial correctly this time; include encode trials where they look entirely at one or the other image 12/01/2020
% Save more info about relating eye data to test and encode trials; set up
% for retreival timing files 10/07/2021

function EyeData=EyeTracking_Experiment_SubMem_Categories(varargin)
%% Set up

%Get the inputs
EyeData = varargin{1};
Data = varargin{2};

% Specify the experiment ID
Experiment = 'SubMem_Categories';

minimum_saccade = 0.2; % What is the minimum amount of time to wait before considering a first look? For reference, a saccade takes 200ms to initiate in adults
half_VPC_trial =2; % what is half of the VPC trial?
minimum_Encode_fixation = 0.5; % How long do they need to look at the encoding trial to include it?
minimum_Test_looks = 0.5; % How long must they look at either option in order for test trial to count? 

%Iterate through the experiment counter
Weights=struct;
BlockList={};

%% Get the eye data from the VPC test trials and perform preprocessing steps
end_of_initial_all = [];
minimum_idx_all = [];
first_left_right_idx_all=[];
TestLag_all=[];
EyeTest2Encode=[]; % relate the eye data trial number for the test trial to the encode trial block and trial 
EyeTest2Test={}; % relate the eye data trial number for the test trial to the test trial block and trial
Test2EyeTest={}; % reverse of above to check for sanity 
TestLag_Encode={};

for IdxCounter=1:length(EyeData.Timecourse.(Experiment))
    
    
    %What block and repetition does this Idx correspond to
    Idx_Name=EyeData.Idx_Names.(Experiment)(IdxCounter,:);
    
    % Because of how Eye Data computes idx number, if you selected block 1
    % (resume) and you are rerunning (rep 2 or more) then the counter will restart
    % to 1 which means that you need to add to it
    if Idx_Name(1) == 1 && Idx_Name(2) > 1
        %Trial_number = Data.Experiment_SubMem_Categories.(sprintf('Block_1_%d', Idx_Name(2) - 1)).TrialCounter;
        Trial_number = find(Data.Experiment_SubMem_Categories.(sprintf('Block_1_%d', Idx_Name(2))).Timing.ImageOns~=0,1); % find the first index that you showed
        
        Idx_Name(3) = Idx_Name(3) + Trial_number-1; %add 
    end
    
    Block_Name=sprintf('Block_%d_%d', Idx_Name(1), Idx_Name(2));
    
    % Make sure that we have timing information for this event; otherwise,
    % we may have quit and not collected it
    if Idx_Name(3) <= length(Data.Experiment_SubMem_Categories.(Block_Name).Timing.ImageOns)
        
        
        % Now we know which trial we are looking at -- is this trial a VPC or
        % an encoding trial?
        isTestTrial=Data.Experiment_SubMem_Categories.(Block_Name).Stimuli.isVPC(Idx_Name(3));
        
        % Only calculate the next stuff if it is a VPC test trial
        if isTestTrial==1
            
            %What is the proprotion of left responses compared to right?
            LeftvsRight=EyeData.Proportions.(Experiment).LeftvsRight(IdxCounter);
            
            % Pull out the time course
            Timecourse = EyeData.Timecourse.(Experiment){IdxCounter};
            
            % What is the typical frame duration
            frame_duration = median(diff(EyeData.Timing.(Experiment){IdxCounter}(:,1)) / EyeData.EyeTrackerTime.slope);
            
            % Store the durations of each response type (1= left, 2= right, 3= center, 5= present, 6= undetected, 0= offscreen)
            duration_responses = [];
            for response_type = 1:9
                duration_responses(response_type) = sum(Timecourse==(response_type - 1)) * frame_duration;
            end
            
            % Then we can find whether first look was to the left. This is
            % defined as first change in fixation to either side -- note
            % that this doesn't ensure that the first look happens early in trial, but needs
            % to happen after a minimum saccade time 
            if ~isempty(Data.Experiment_SubMem_Categories.(Block_Name).Timing.ImageOns(Idx_Name(3)))
                
                Test_Timing.ImageOns(IdxCounter)=Data.Experiment_SubMem_Categories.(Block_Name).Timing.ImageOns(Idx_Name(3));
                
                Onset_eyetracker=((Test_Timing.ImageOns(IdxCounter)+minimum_saccade) * EyeData.EyeTrackerTime.slope) + EyeData.EyeTrackerTime.intercept;
                
                % What is the first Time point after the minimum saccade and they
                % are no longer off screen?
                minimum_idx = min(find(EyeData.Timing.(Experiment){IdxCounter}(:,1) > Onset_eyetracker));
                end_of_initial = min(find(diff(Timecourse(minimum_idx:end)) ~= 0)) + 1; % Find the end of the initial fixation period that is hung over from the last trial.
                end_of_initial = end_of_initial + minimum_idx - 1;

            else
                end_of_initial=[];
                
            end
            
            % Check this trial has a first look
            if ~isempty(end_of_initial) && (length(Timecourse) * frame_duration) > minimum_Test_looks
                
                end_of_initial_all(end+1) = end_of_initial;
                minimum_idx_all(end+1) = minimum_idx;
                
                % Are they looking left or right first
                first_left_right_idx = min([find(Timecourse(end_of_initial:end) == 1), find(Timecourse(end_of_initial:end) == 2)]) + end_of_initial - 1;
                FirstLook = Timecourse(first_left_right_idx);
                
                % Store if not empty
                if ~isempty(first_left_right_idx)
                    first_left_right_idx_all(end+1) = first_left_right_idx;
                else
                    first_left_right_idx_all(end+1) = -1;
                end
                
            else
                end_of_initial_all(end+1) = -1;
                minimum_idx_all(end+1) = -1;
                first_left_right_idx_all(end+1)=-1;
                FirstLook = [];
            end
            
            % Split half the time course and make it into left vs right
            if ~isempty(Data.Experiment_SubMem_Categories.(Block_Name).Timing.ImageOns(Idx_Name(3)))
                half_time = ((Test_Timing.ImageOns(IdxCounter) + half_VPC_trial) * EyeData.EyeTrackerTime.slope) + EyeData.EyeTrackerTime.intercept;
                mid_idx = min(find(EyeData.Timing.(Experiment){IdxCounter}(:,1) > half_time));
                
                % Set up the proportion of old looks, assuming the old was on the
                % left and then fix it later if was on the right.
                ProportionOld_Timecourse(1) = sum(Timecourse(1:mid_idx) == 1) / sum((Timecourse(1:mid_idx) == 1) + (Timecourse(1:mid_idx) == 2));
                ProportionOld_Timecourse(2) = sum(Timecourse(mid_idx:end) == 1) / sum((Timecourse(mid_idx:end) == 1) + (Timecourse(mid_idx:end) == 2));
                
                % Store the durations of each response type
                durationOld_Timecourse(1) = sum(Timecourse(1:mid_idx) == 1) * frame_duration;
                durationNew_Timecourse(1) = sum(Timecourse(1:mid_idx) == 2) * frame_duration;
                durationOld_Timecourse(2) = sum(Timecourse(mid_idx:end) == 1) * frame_duration;
                durationNew_Timecourse(2) = sum(Timecourse(mid_idx:end) == 2) * frame_duration;
                
                % Check that these two halves have enough data in them; if
                % not, set the proportion and duration to NaN values
                if (length(1:mid_idx) * frame_duration) < minimum_Test_looks
                    ProportionOld_Timecourse(1) = NaN;
                    durationOld_Timecourse(1) = NaN;
                    durationNew_Timecourse(1) = NaN;
                end
                
                if (length(mid_idx:length(Timecourse)) * frame_duration) < minimum_Test_looks
                    ProportionOld_Timecourse(2) = NaN;
                    durationOld_Timecourse(2) = NaN;
                    durationNew_Timecourse(2) = NaN;
                end
            end
            
            %Now figure out if the new stim is to the left or to the right !!
            %To do this first though, we need to convert our trial number into
            %the VPC trial number
            VPC_Num=find(Data.Experiment_SubMem_Categories.(Block_Name).Timing.VPC_ImageOns==Data.Experiment_SubMem_Categories.(Block_Name).Timing.ImageOns(Idx_Name(3)));
            
            NewStim=Data.Experiment_SubMem_Categories.(Block_Name).Stimuli.VPC_Side{VPC_Num};
            
            %What side are the test stimuli going to appear on?
            if NewStim==2
                OldSide='Left';
            else
                OldSide='Right';
            end
            
            %If the old stimulus is on the left then use these values as is
            if strcmp(OldSide, 'Left')
                ProportionOld=LeftvsRight;
                DurationOld=duration_responses(2);
                DurationNew=duration_responses(3);
                if isempty(FirstLook)
                    FirstLook_old(IdxCounter) = 0;
                    FirstLook_raw(IdxCounter) = 0;
                else
                    FirstLook_old(IdxCounter) = double(FirstLook == 1); % Were they looking left first
                    FirstLook_raw(IdxCounter) = FirstLook;
                end
            % but if the old stimulus is on the right, then reverse the values
            else
                ProportionOld=1-LeftvsRight;
                DurationOld=duration_responses(3);
                DurationNew=duration_responses(2);
                if isempty(FirstLook)
                    FirstLook_old(IdxCounter) = 0;
                    FirstLook_raw(IdxCounter) = 0;
                else
                    FirstLook_old(IdxCounter) = double(FirstLook == 2); % Were they looking right first
                    FirstLook_raw(IdxCounter) = FirstLook;
                end
                % Fix the directionality if old is right
                ProportionOld_Timecourse = 1 - ProportionOld_Timecourse;
                temp = durationOld_Timecourse;
                durationOld_Timecourse = durationNew_Timecourse;
                durationNew_Timecourse = temp;
                
            end
            
            % Finally, find out where this VPC's encoding trial was !!
            % Most of the time this will be in the same block but it's possible
            % we will have resumed from previous block, in which case we
            % have some stuff to figure out 
            
            % First, what image was the old?
            Test_Stimuli=Data.Experiment_SubMem_Categories.(Block_Name).Stimuli.Name{Idx_Name(3)};
            Full_Old_Image_Name=Test_Stimuli{1,1}; % always first in the list 
            Temp=strsplit(Full_Old_Image_Name,'/');
            Old_Image_Name=Temp{end};
            
            % Now find this index
            BlockNames_temp=fieldnames(Data.Experiment_SubMem_Categories);
            for BlockCounter=1:length(BlockNames_temp)
                
                if isfield(Data.Experiment_SubMem_Categories.(BlockNames_temp{BlockCounter}), 'Stimuli')
                    isName=cellfun(@(x)isequal(x,Old_Image_Name),Data.Experiment_SubMem_Categories.(BlockNames_temp{BlockCounter}).Stimuli.Name);
                    [row,col]=find(isName);
                    Encode_Idx=col; %yay!
                    
                    %Store the index name
                    if ~isempty(Encode_Idx)
                        Encode_BlockName=BlockNames_temp{BlockCounter};
                        
                        %Assign each Test stim with the index that it was presented
                        EyeTest2Encode{IdxCounter}={Encode_BlockName,Encode_Idx};
                        
                        % Here let's save that
                        BlockList{end+1} = BlockNames_temp{BlockCounter};
                        
                    end
                    
                end
                
            end
            
            % remember what the eye data index counter relates to in actual data collection
            
            if ~isfield(Test2EyeTest,Block_Name) % does this field exist yet?? 
                Test2EyeTest.(Block_Name)=[];
            end
            
            % Two different ways of saving this information, but we'll mainly use
            % Test2EyeTest later on in the timing files 
            
            % first though, revert back to the original Idx_Name(3) if this
            % is not the first block (since in timing creation we will
            % use the event counter of that block, not the event counter
            % overall)
            temp_idx=Idx_Name(3); % preset
            
            if Idx_Name(1) == 1 && Idx_Name(2) > 1
                Trial_number = find(Data.Experiment_SubMem_Categories.(sprintf('Block_1_%d', Idx_Name(2))).Timing.ImageOns~=0,1); % find the first index that you showed
                temp_idx = Idx_Name(3) - Trial_number+1; % reverse what we did before 
            end
            
            % save both ways
            Test2EyeTest.(Block_Name)(temp_idx)=IdxCounter;
            EyeTest2Test{IdxCounter}={Block_Name,Idx_Name(3)};
            
            %Store for later
            Weights.SubMem_Test.Raw(IdxCounter)=ProportionOld;
            Duration.Old(IdxCounter)=DurationOld;
            Duration.New(IdxCounter)=DurationNew;
            
            % save the specific proportions of responses
            ProportionOffScreen(IdxCounter)=EyeData.Proportions.(Experiment).Responses_All(IdxCounter, 1);
            ProportionUndetected(IdxCounter)=EyeData.Proportions.(Experiment).Responses_All(IdxCounter, 7);
            ProportionCenter(IdxCounter)=EyeData.Proportions.(Experiment).Responses_All(IdxCounter, 4);
            ProportionOld_Timecourse_all(IdxCounter, :)=ProportionOld_Timecourse;
            durationOld_Timecourse_all(IdxCounter, :)=durationOld_Timecourse;
            durationNew_Timecourse_all(IdxCounter, :)=durationNew_Timecourse;
            
            
            % If this data is from a previous session then set the lag to NaN;
            if exist('EyeTest2Encode') == 0 || length(EyeTest2Encode) < IdxCounter || isempty(EyeTest2Encode{IdxCounter}) %|| length(EyeTest2Encode) < IdxCounter
                %fprintf('Could not find %s, probably because it is from an old session\n', TestStim);
                TestLag_all(IdxCounter) = NaN;
            else
                TestLag_all(IdxCounter) = Test_Timing.ImageOns(IdxCounter) - Data.Experiment_SubMem_Categories.(EyeTest2Encode{IdxCounter}{1}).Timing.ImageOns(EyeTest2Encode{IdxCounter}{2});
            end
            
        else
            %If not a test trial (and it matters that it isn't set to 0), set to  NaN
            Weights.SubMem_Test.Raw(IdxCounter)=NaN;
            FirstLook_old(IdxCounter)=NaN;
            FirstLook_raw(IdxCounter) = NaN;
            ProportionOld_Timecourse_all(IdxCounter, :)=[NaN,NaN];
            
            %And increment the things we are incrementing
            end_of_initial_all(end+1) = NaN;
            minimum_idx_all(end+1) = NaN;
            first_left_right_idx_all(end+1)=NaN;
        end
    end
    
end

if sum(isnan(TestLag_all)) > 0
    fprintf('There were %d Test trials that couldn''t be matched with encoding, presumably because they were from a previous session\n', sum(isnan(TestLag_all)));
end

%% Determine whether test trials are going to be useable
% They need to satisfy a number of criteria: infants had to look at the
% encoding trial, the delay needs to have been in a reasonable range, etc.

% Preset size to deal with instances where they don't finish the test
BlockList=unique(BlockList);
for BlockCounter=1:length(BlockList)
    Weights.SubMem_Categories.Parametric.(BlockList{BlockCounter})=zeros(1, length(Data.Experiment_SubMem_Categories.(BlockList{BlockCounter}).Timing.ImageOns));
end

Idxs_Used=[];
EyeData.SubMem_Test.exclude_trial = [];
for TrialCounter=1:length(EyeTest2Encode)
    
    % what is the encode index (if there are some)
    Idxs=EyeTest2Encode{TrialCounter};
    
    exclude_trial=0;
    
    if ~isempty(Idxs)
 
        % Go back to the way eye tracking calls it (which is that if you
        % are in a repeat block it restarts the counter, so you have to
        % take back the change you made with the idx)
        BlockName=Idxs{1};
        if str2num(BlockName(end)) > 1
            Trial_number = find(Data.Experiment_SubMem_Categories.(sprintf(BlockName)).Timing.ImageOns~=0,1); % find the first real trial of this block
            eye_idx_name=Idxs{2} - Trial_number+1;
        else
            eye_idx_name=Idxs{2};
        end
        
        
        % Check that the encode trial this corresponds to has enough
        % data (and find out what eye index it is !)
        for idx_counter = 1:size(EyeData.Idx_Names.SubMem_Categories, 1)
           
            % If this is a match then update
            if EyeData.Idx_Names.SubMem_Categories(idx_counter, 1) == str2num(Idxs{1}(7)) && EyeData.Idx_Names.SubMem_Categories(idx_counter, 2) == str2num(Idxs{1}(9)) && EyeData.Idx_Names.SubMem_Categories(idx_counter, 3) == eye_idx_name
                encode_idx = idx_counter;
            end
        end
        
        % Pull out the time course
        Timecourse_encode = EyeData.Timecourse.(Experiment){encode_idx};
        
        % What is the typical frame duration
        frame_duration = median(diff(EyeData.Timing.(Experiment){encode_idx}(:,1)) / EyeData.EyeTrackerTime.slope);
        
        % Store the durations of each response type (1= left, 2= right, 3= center, 5= present, 6= undetected, 0= offscreen)
        duration_responses = [];
        for response_type = 1:9
            duration_responses(response_type) = sum(Timecourse_encode==(response_type - 1)) * frame_duration;
        end 
        
        %Check if they looked at the encoding image long enough or if we don't
        %have data for the encoding trial for some reason
        %Just include the response '3' which means on center (index 4 here, since 0 is off screen)
        if sum(duration_responses(4)) < (minimum_Encode_fixation) 
            exclude_trial = 1;
        end
        
        % Specifically, only take the first presentation of the test trial, unless that presentation
        % was all coded as Off-Screen then take the second
        % Cycle through all other Test trials and compare to the current one
        % to decide whether to swap it for a duplicate trial
        % Unlikely in the current design but just in case
        for temp_counter = setdiff(1:length(EyeTest2Encode), TrialCounter)
            
            % Pull out the idxs for this other trial
            temp_Idxs=EyeTest2Encode{temp_counter};
            
            % Is this the same trial type?
            if ~isempty(temp_Idxs) && strcmp(temp_Idxs{1}, Idxs{1}) &&  Idxs{2} == temp_Idxs{2}
                
                % If the lag for another trial is less than this one and some of
                % the data from that trial is usable then skip this trial
                Total_looking = nansum([Duration.Old(temp_counter), Duration.New(temp_counter)]);
                if TestLag_all(temp_counter) < TestLag_all(TrialCounter) &&  ~isnan(Total_looking) && Total_looking > minimum_Test_looks
                    exclude_trial = 2;
                    excluded_Idxs = temp_Idxs;
                    excluded_trial_counter = temp_counter;
                end
            end
        end
        
        % Exclude the trial if the test does not have a sufficient number
        % of frames in which the infant was looking
        Total_looking = nansum([Duration.Old(TrialCounter), Duration.New(TrialCounter)]);
        if ~isnan(Total_looking) && Total_looking < minimum_Test_looks
            exclude_trial = 3;
        end
        
        % Exclude the trial if the test lag is above the average
        % expected delay time based on how the experiment was coded
        % (range is usually up to 95 seconds so we will look for under 100 seconds)
        if TestLag_all(TrialCounter)>100 || isnan(TestLag_all(TrialCounter))
            exclude_trial = 4;
        end
        
        % Once you have determined whether to use the trial, store the
        % information
        EyeData.SubMem_Test.exclude_trial(end+1) = exclude_trial;
        
        if exclude_trial == 0
            Idxs_Used(end+1) = TrialCounter;
            
        else
            fprintf('Not using encode trial %d\n', Idxs{2});
            
            if exclude_trial == 1
                fprintf('Prop not looking at encode: %0.2f\n', 1 - sum(duration_responses(4))/sum(duration_responses));
            elseif exclude_trial == 3
                fprintf('Test secs included: %0.2f\n', Total_looking);
            elseif exclude_trial == 4
                fprintf('Abnormally long encode-test lag: %0.2f\n', TestLag_all(TrialCounter));
            elseif exclude_trial == 2
                fprintf('Repeat test exclusion: Current trial exclusion: %0.2f lag=%0.0f, other trial exclusion: %0.2f lag=%0.0f\n', ProportionOffScreen(TrialCounter), TestLag_all(TrialCounter), ProportionOffScreen(excluded_trial_counter), TestLag_all(excluded_trial_counter));
            end
            
        end
    end
end

fprintf('Total number of encoding trials with paired test trial: %d\n',length(Idxs_Used))

% Store the vector versions of this data
Proportion_Raw_Used = Weights.SubMem_Test.Raw(Idxs_Used); % Default to use trial
TestLag_Used = TestLag_all(Idxs_Used);
ProportionOld_Timecourse_all_Used = ProportionOld_Timecourse_all(Idxs_Used,:);
FirstLook_old_Used = FirstLook_old(Idxs_Used);

%% Create the conditions

if isempty(Idxs_Used)
    fprintf('!! No eye tracking weights created for SubMem_Categories !!\n')
else
    
    %Pull out the z scored looking time values
    %z-score is done manually to account for cases of NaNs when Participant was
    %not looking (or trial was not an encoding trial). zscore matlab built-in function does not do this
    Weights.SubMem_Test.Parametric = ones(1, length(Weights.SubMem_Test.Raw)) * nan;
    Weights.SubMem_Test.Parametric(Idxs_Used) = nanzscore(Weights.SubMem_Test.Raw(Idxs_Used));
    
    % Preset for the conditions
    Weights.SubMem_Test.Condition=zeros(12, length(Weights.SubMem_Test.Raw)) * nan;
    
    %Condition 1!
    %Binarize the data, were they looking to the new stim more than the old stim?
    Binaries=Weights.SubMem_Test.Raw; %preset to be the same as the weights (carries NaNs from the test trials)
    
    %Then actually binarize
    Old_Pref=find(Weights.SubMem_Test.Raw>0.5);
    Binaries(Old_Pref)=2;
    New_Pref=find(Weights.SubMem_Test.Raw>=0 & Weights.SubMem_Test.Raw<=0.5);
    Binaries(New_Pref)=1;
    
    Weights.SubMem_Test.Condition(1, Idxs_Used)=Binaries(Idxs_Used);
    
    %Condition 2!
    %Separate weights into 4 strengths for analysis
    W = zeros(1, length(Weights.SubMem_Test.Raw)) * nan;
    W(Idxs_Used) = Weights.SubMem_Test.Raw(Idxs_Used);
    
    for Trial=1:length(W)
        if W(Trial) <=  0.25
            W(Trial) = 1;
        elseif W(Trial) > 0.25 && W(Trial) <= 0.5
            W(Trial) = 2;
        elseif W(Trial) > 0.5 && W(Trial) <= 0.75
            W(Trial) = 3;
        elseif W(Trial) > 0.75
            W(Trial) = 4;
        end
        
    end
    
    Weights.SubMem_Test.Condition(2,:) = W;
    
    %Condition 3! and 4!
    % Create weights for different degrees of looking within the two binarized
    % conditions
    familiar_Z = zeros(length(Binaries), 1) * nan;
    novel_Z = zeros(length(Binaries), 1) *nan;
    
    Idxs_Used_log = zeros(1, length(Binaries)); Idxs_Used_log(Idxs_Used) = 1;
    familiar_Z(logical((Binaries == 2).* (Idxs_Used_log == 1))) = nanzscore(Weights.SubMem_Test.Raw(logical((Binaries == 2) .* (Idxs_Used_log == 1))));
    novel_Z(logical((Binaries == 1) .* (Idxs_Used_log == 1))) = nanzscore(Weights.SubMem_Test.Raw(logical((Binaries == 1) .* (Idxs_Used_log == 1))));
    
    Weights.SubMem_Test.Condition(3,:) = familiar_Z;
    Weights.SubMem_Test.Condition(4,:) = novel_Z;
    
    % Condition 5
    % Create the different parametric weights for first looks to old
    Weights.SubMem_Test.Condition(5,Idxs_Used) = FirstLook_old(Idxs_Used);
    
    % Condition 6 and 7
    % Store the duration of Old and New looks (overall)
    Weights.SubMem_Test.Condition(6,Idxs_Used) = Duration.Old(Idxs_Used);
    Weights.SubMem_Test.Condition(7,Idxs_Used) = Duration.New(Idxs_Used);
    
    % Condition 8
    % Make a quartile version of memory strength
    W = zeros(1, length(Weights.SubMem_Test.Raw)) * nan;
    W(Idxs_Used) = Weights.SubMem_Test.Raw(Idxs_Used);
    
    Q1 = prctile(W, 25);
    Q2 = prctile(W, 50);
    Q3 = prctile(W, 75);
    for Trial=1:length(W)
        if W(Trial) <=  Q1
            W(Trial) = 1;
        elseif W(Trial) > Q1 && W(Trial) <= Q2
            W(Trial) = 2;
        elseif W(Trial) > Q2 && W(Trial) <= Q3
            W(Trial) = 3;
        elseif W(Trial) > Q3
            W(Trial) = 4;
        end
        
    end
    
    Weights.SubMem_Test.Condition(8,:) = W;
    
    % Conditions 9 and 10 -- parametric for short and long lags separately
    Weights.SubMem_Test.Condition(9,Idxs_Used(TestLag_Used<60)) =  nanzscore(Weights.SubMem_Test.Raw(Idxs_Used(TestLag_Used<60)));
    Weights.SubMem_Test.Condition(10,Idxs_Used(TestLag_Used>60)) =  nanzscore(Weights.SubMem_Test.Raw(Idxs_Used(TestLag_Used>60)));
    
    % Condition 11 -- zscored delay 
    Weights.SubMem_Test.Condition(11,Idxs_Used) =  nanzscore(TestLag_Used);
    
    % Condition 12 -- binarize delay
    Binaries=zeros(1, length(Weights.SubMem_Test.Raw));
    ShortLag=find(Idxs_Used(TestLag_Used<=60));
    Binaries(ShortLag)=1;
    LongLag=find(Idxs_Used(TestLag_Used>60));
    Binaries(LongLag)=2;
    
    Weights.SubMem_Test.Condition(12, Idxs_Used)=Binaries(Idxs_Used);
    
    
    %% Pair Test with Encode trials
    %The moment we have been waiting for!
    
    % Now that you have determined what trials to include and made all the condition data, make the weights for
    % the encode trials
    
    % **Weights.SubMem_Categories is where it will be stored in and what will be picked up by the timing files **
    
    %Note that this will be too many images actually because it includes the
    %values for VPC but that's okay -- those will just be NaN!
    for BlockCounter=1:length(BlockList)
        Weights.SubMem_Categories.Condition.(BlockList{BlockCounter})=zeros(size(Weights.SubMem_Test.Condition,1), length(Data.Experiment_SubMem_Categories.(BlockList{BlockCounter}).Timing.ImageOns));
    end
    
    for TrialCounter = Idxs_Used
        
        %Pull out the mapping of Memtest onto Memencode
        Idxs=EyeTest2Encode{TrialCounter};
        
        %Pull out the weights
        Weights.SubMem_Categories.Parametric.(Idxs{1})(Idxs{2})=Weights.SubMem_Test.Parametric(TrialCounter);
        
        for condition_counter = 1:size(Weights.SubMem_Test.Condition, 1)
            Weights.SubMem_Categories.Condition.(Idxs{1})(condition_counter,Idxs{2})=Weights.SubMem_Test.Condition(condition_counter,TrialCounter);
        end
        
        % Pull out the timing information from these blocks
        TestLag_Encode.(Idxs{1})(Idxs{2})=Test_Timing.ImageOns(TrialCounter) - Data.Experiment_SubMem_Categories.(Idxs{1}).Timing.ImageOns(Idxs{2});

        % !!!! We will also add the parametric weights to the corresponding
        % test trial (to be used in retrieval GLMs)
        Idxs_Test=EyeTest2Test{TrialCounter};
        
        %Pull out the weights
        Weights.SubMem_Categories.Parametric.(Idxs_Test{1})(Idxs_Test{2})=Weights.SubMem_Test.Parametric(TrialCounter);
        
        
    end
    
    %% Report behavior
    %Do a t test of the used time points
    [~, p] = ttest(Proportion_Raw_Used, 0.5);
    
    %What is the mean and the p value of these weights
    fprintf('\nSubMem Test looking time results\n---------------------\n\nMean Proportion looking at familiar stimulus: %0.2f\np value: %0.2f\n\n', nanmean(Proportion_Raw_Used), p);
    
    fprintf('\nProportion of first looks to old: %0.2f\n', nanmean(FirstLook_old_Used));
    
    % Analyze the looking time for Mem data
    if sum(EyeData.SubMem_Test.exclude_trial == 1) > 0
        [~, p] = ttest(Weights.SubMem_Test.Raw(EyeData.SubMem_Test.exclude_trial == 1), 0.5);
        fprintf('\nProportion looking at test to a stimulus shown at encoding but not seen: %0.2f\np value: %0.2f\n\n', nanmean(Weights.SubMem_Test.Raw(EyeData.SubMem_Test.exclude_trial == 1)), p);
    end
    
    % Analyze the looking time for Mem data
    %if sum(EyeData.SubMem_Test.exclude_trial == 4) > 0
    %    [~, p] = ttest(Weights.SubMem_Test.Raw(EyeData.SubMem_Test.exclude_trial == 4), 0.5);
    %    fprintf('\nProportion looking at test when the delay was longer than 100 s: %0.2f\np value: %0.2f\n\n', nanmean(Weights.SubMem_Test.Raw(EyeData.SubMem_Test.exclude_trial == 4)), p);
    %end
    
    % Report the correlation between the lag in seconds and the difference from
    % chance looking time
    test_lag_familiarity_corr=corrcoef(abs(Proportion_Raw_Used - 0.5), TestLag_Used);
    if length(test_lag_familiarity_corr) > 1
        test_lag_familiarity_corr=test_lag_familiarity_corr(2);
    end
    %What is the mean and the p value of these weights
    fprintf('\nMemTest encode-test lag\n---------------------\n\nMean lag: %0.2fs, Range: %0.2fs - %0.2fs\nCorrelation between looking time and difference from chance: %0.2f\n\n', nanmean(TestLag_Used), min(TestLag_Used), max(TestLag_Used), test_lag_familiarity_corr);
    
    
    % Create a figure of the scatter
    figure
    scatter(TestLag_Used, Proportion_Raw_Used)
    title('Looking time bias and lag between exposure and test')
    xlabel('Encoding-test lag (s)')
    ylabel('Familiarity preference')
    
    savefig(gcf, 'analysis/Behavioral/Experiment_SubMem_Categories_lag.fig')
    saveas(gcf, 'analysis/Behavioral/Experiment_SubMem_Categories_lag.png')
    
    close(gcf)
    
    %% Create a figure depicting the time course of eye tracking for each stimulus
    
    % figure()
    % max_length = max(cellfun(@length, EyeData.Timecourse.SubMem_Categories));
    % for IdxCounter=find(cellfun(@isempty, EyeTest2Encode) == 0) %Idxs_Used
    %
    %     % Pull out the Idxs for this trial
    %     Idxs=EyeTest2Encode{IdxCounter};
    %
    %     if ~isempty(Idxs)
    %
    %         temp_trialcounter=((str2num(Idxs{1}(7)) - 1) * 12) + Idxs{2};
    %
    %         % Set the subplot
    %         subplot(3,30, temp_trialcounter);
    %
    %         %What block and repetition does this Idx correspond to
    %         Idx_Name=EyeData.Idx_Names.SubMem_Categories(IdxCounter,:);
    %         Block_Name=sprintf('Block_%d_%d', Idx_Name(1), Idx_Name(2));
    %
    %         % Because of how Eye Data computes idx number, if you selected block 1
    %         % (resume) and you are rerunning (rep 2) then the counter will restart
    %         % to 1 which means that you need to add to it
    %         if Idx_Name(1) == 1 && Idx_Name(2) > 1
    %             Trial_number = Data.Experiment_SubMem_Categories.(sprintf('Block_1_%d', Idx_Name(2) - 1)).TrialCounter;
    %
    %             Idx_Name(3) = Idx_Name(3) + Trial_number - 1; % Subtract 1 since rerun the last trial
    %         end
    %
    %
    %         %Which side the left (1) or the right (2) is the new stim on?
    %         VPC_Num=find(Data.Experiment_SubMem_Categories.(Block_Name).Timing.VPC_ImageOns==Data.Experiment_SubMem_Categories.(Block_Name).Timing.ImageOns(Idx_Name(3)));
    %
    %         NewStim=Data.Experiment_SubMem_Categories.(Block_Name).Stimuli.VPC_Side{VPC_Num};
    %
    %         %Extract the timecourse
    %         Timecourse=EyeData.Timecourse.SubMem_Categories{IdxCounter};
    %
    %         %Recode the timepoints for display purposes
    %         Timecourse_recoded=Timecourse;
    %         Timecourse_recoded(Timecourse==0)=nan;
    %         Timecourse_recoded(Timecourse==6)=nan;
    %         Timecourse_recoded(Timecourse==1)=-1;
    %         Timecourse_recoded(Timecourse==2)=1;
    %
    %         % Pull out the initial look
    %         FirstLook = (FirstLook_raw(IdxCounter) * 2) -3; % Make it in the range of -1 to 1
    %         minimum_idx = minimum_idx_all(IdxCounter);
    %         first_left_right_idx=first_left_right_idx_all(IdxCounter);
    %
    %         %What side did the novel stimulus appear on
    %         if NewStim==1
    %             Side='L';
    %         else
    %             Side='R';
    %         end
    %
    %         hold on
    %         plot(Timecourse_recoded,1:length(Timecourse_recoded));
    %         plot([-1, 1], [minimum_idx, minimum_idx], 'g');
    %         title(Side);
    %         set(gca, 'YTick', [], 'YTickLabel', {},'XTick', [-1 1], 'XTickLabel', {'L', 'R'})
    %         xlim([-1.5, 1.5]);
    %         ylim([0, max_length]);
    %         if ~isempty(FirstLook) || FirstLook == -1
    %             scatter(FirstLook, first_left_right_idx, 'ko');
    %         end
    %
    %         % If this trial is excluded then set the axis color
    %         if isempty(find(Idxs_Used == IdxCounter))
    %             ax = gca;
    %             ax.XColor = 'red';
    %             ax.YColor = 'red';
    %         end
    %
    %         hold off
    %
    %     end
    % end
    %
    % %Save all the figures and create
    % savefig(gcf, 'analysis/Behavioral/Experiment_SubMem_Categories_Timecourse.fig')
    % saveas(gcf, 'analysis/Behavioral/Experiment_SubMem_Categories_Timecourse.png')
    % close(gcf);
    
    %% Important: If this is a repeat, only save weights for trials that were shown
    % If this block is a repeat of Trial 1 (start from last trial), that means
    % that we will begin at index X and have 0's (or NaNs) for all of the
    % trials that did not happen in this block. But in
    % Timing_SubMem_Cateogires, we only recorded those trials we actually
    % showed (of course, because we only have timing for those images)!
    % Thus, while the EyeData.Weights.SubMem_Categories_bkp will have all of
    % the trials, we will store EyeData.Weights.SubMem_Categories only for the
    % trials that were relevant to this block
    
    %Store the data and it's backup
    EyeData.Weights.SubMem_Categories_bkp=Weights.SubMem_Categories;
    
    % Go through each block and only retain trials that were shown
    for BlockCounter=1:length(BlockList)
        EyeData.Weights.SubMem_Categories.Condition.(BlockList{BlockCounter})=Weights.SubMem_Categories.Condition.(BlockList{BlockCounter})(:,Data.Experiment_SubMem_Categories.(BlockList{BlockCounter}).Timing.ImageOns~=0); %this is essential to making timing files
        EyeData.Weights.SubMem_Categories.Parametric.(BlockList{BlockCounter})=Weights.SubMem_Categories.Parametric.(BlockList{BlockCounter})(:,Data.Experiment_SubMem_Categories.(BlockList{BlockCounter}).Timing.ImageOns~=0); %this is essential to making timing files
    end
    
    % Store some additional files for later to reference
    EyeData.TestLag.SubMem_Test=TestLag_Used;
    EyeData.TestLag.SubMem_Categories=TestLag_Encode;
    
    EyeData.Weights.SubMem_Test=Weights.SubMem_Test;
    EyeData.Weights.SubMem_Test.Raw_used=Proportion_Raw_Used; % Store the mem test weights that were used, aligned with the EyeData.TestLag.MemTest
    EyeData.Weights.SubMem_Test.FirstLook_used=FirstLook_old_Used;
    EyeData.Weights.SubMem_Test.ProportionOffScreen=ProportionOffScreen;
    EyeData.Weights.SubMem_Test.ProportionUndetected=ProportionUndetected;
    EyeData.Weights.SubMem_Test.Duration.Old = Duration.Old;
    EyeData.Weights.SubMem_Test.Duration.New = Duration.New;
    
    EyeData.SubMem_Test.Idxs_Used = Idxs_Used;
    EyeData.SubMem_Test.ProportionOld_Timecourse_all=ProportionOld_Timecourse_all;
    EyeData.SubMem_Test.EyeTest2Encode = EyeTest2Encode;
    EyeData.SubMem_Test.EyeTest2Test = EyeTest2Test;
    
    % for timing_condition script to work, set all of the NaNs in the
    % SubMem_Test weights to 0 instead
    EyeData.Weights.SubMem_Test.Condition(isnan(EyeData.Weights.SubMem_Test.Condition))=0;
    EyeData.SubMem_Test.Test2EyeTest = Test2EyeTest;
end

end


% Perform z scoring but ignoring nans 
function Z = nanzscore(X)
    Z = (X - nanmean(X)) / nanstd(X);
end

