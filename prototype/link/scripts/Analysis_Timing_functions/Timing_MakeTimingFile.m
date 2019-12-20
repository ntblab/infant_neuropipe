% Make a timing file
%
% Take in the necessary information and generate timing files.
%
% Three timing file labels exist (may be prefixed by functional name):
%
% $EXPERIMENT-$BLOCKNAME.txt: Specifies the block times of all blocks with
%                               the same name
%
% $EXPERIMENT-$BLOCKNAME_Events.txt: Specifies the event times of the above
%
% $EXPERIMENT-$BLOCKNAME_Condition_$CONDITIONS.txt: Specifies the event
%                               times of the different conditions. THis is
%                               necessary when the conditions are events
%                               across blocks
%
% $EXPERIMENT is the experiment name, without the prefix of Experiment_
% $BLOCKNAME is the name of the block as specified in Parameters.BlockNames
% $CONDITIONS identifies different conditions of the data, where necessary
%
% Naming matters! FunctionalSplitter is looking for timing files by the
% hyphen (any text file without a hyphen is ignored). It will also not use
% the Events or Condition files to pull out TRs, these labels will just be
% used to create timing files. If it wasn't doing this then you may end up
% pulling out the same TRs multiple times
%
% While reading this notice two types of labels: ID and Name. ID are the
% names of DesignID subfields. These only contain underscores because
% hyphens are illegal in field names. However, because I want hyphens for
% the names of the text files to produced, I also have the other label of
% Name to refer to the file name to be created.
%
% Three types of timing files can be made:
%
% The timing file bracketing all of the blocks based on block name. If you
% run a given block name multiple times then this will be entered as
% multiple rows in the timing file For instance when are the structured
% versus random blocks in statistical learning
%
% If timings of events is supplied then for each block name list the timing
% of events for a given condition. For instance when is there an event in
% the posner task.
%
% If Condition weights are supplied then this will create two timing files
% for each of the conditions. This requires labels for each experiment, how
% they are organized. A script must be made in the TIming_Scripts folder
% named: Timing_Condition_$Experiment which takes in parameters to produce
% the
%
% This is how Timing_Condition_$Experiment works. For this experiment find
% the condition filenames. These names are stored in the following format.
% For each element of the Name_Condition structure outlines a different way
% of organizing the events (e.g. Left vs right, or valid vs invalid vs
% neutral). The subfields of this structure refer to each level (first or
% second) that these timing files will be made for. Finally for each level
% there are indexes of cells referring to the different possible names for
% this condition. Usually this will only be one element long but if an
% event belongs to multiple conditions simultaneously (if the conditions
% aren't mutually exclusive, like if the conditions were features of a
% stimulus) then this corresponds to different elements of this field. To
% ignore an event, supply nans.
%
% Event and Condition types are confusable. Think of Events as taking a
% block name (like structured) and decimating it into events. Think of
% Conditions as taking all of the events (be them blocks or otherwise) and
% then reorganizing them into conditions If you want to pass information
% about what event each condition belongs to then add it to the Timing
% structure in the Timing_$ExperimentName script and make it readable. For
% instance, different conditions might be valid versus invalid in posner or
% remembered versus forgotten in subsequent memory.
%
%
% Adding a new experiment
%
% If you want to add a new experiment then blocks will automatically be
% pulled out without any special effort on your part. If you want to
% specify events for this new experiment then make sure there are Timing.ID
% and Timing.Name fields made for this experiment in Timing_$Experiment. If
% you want different conditions then make a Timing_Condition_$Experiment
% function to specify these names.
%
%
% Timing
%
% The main time stamping comes from two fields of the Timing structure:
% Firstlevel_block_onset and Secondlevel_block_onset which determine how
% long since the start of the run and session, respectively, this block
% began.
%
% C Ellis 2016
% Added nuisance file creation 3/23/17 C Ellis
% Changed the naming to use first and secondlevel timestamps 2/27/19 C Ellis

function [FileIDs, Timing] = Timing_MakeTimingFile(Timing, FileIDs, EyeData)

% Pull out some information from the Timing matrix

% Most importantly, when did the timing of the block start, according to
% the firstlevel count (time since the run began) and according to the
% secondlevel count (time since the session began) while taking account
% of burn in differences
Firstlevel_block_onset = Timing.Firstlevel_block_onset; % How long since the run started did this block begin?
Secondlevel_block_onset = Timing.Secondlevel_block_onset;  % How long since the session started did this block begin?

TaskTime = Timing.TaskTime; % How long was the block task
Include_Events = Timing.Include_Events; % Which events are being included
ExperimentName=Timing.ExperimentName; % What experiment is this block
BlockName = Timing.BlockName; % What is the block name
Motion_Exclude_Epoch = Timing.Motion_Exclude_Epoch;  % Do epochs also need to be excluded for motion
Functional_name = Timing.Functional_name; % What is the name to be stored

%What levels of analysis are there?
Levels={'First', 'Second', 'Confounds'};
if Motion_Exclude_Epoch==1
    NuisanceFileName={'EyeData_Exclude_Epochs', 'Motion_Exclude_Epochs'};
else
    NuisanceFileName={'EyeData_Exclude_Epochs'};
end

ConditionFunction=str2func(sprintf('Timing_Condition_%s', ExperimentName(12:end)));

%Convert the names to IDs (exclude all illegal characters that are
%necessary for other reasons)
Timing.ID=Timing.Name; %Preset to the same
Timing.ID(strfind(Timing.Name, '-'))='_';
Timing.ID(strfind(Timing.Name, '+'))='_';

if isfield(Timing, 'Name_Events')
    Timing.ID_Events=Timing.Name_Events; %Preset to the same
    for EventCounter =1:size(Timing.ID_Events,1)
        for EventTypeCounter =1:size(Timing.ID_Events,2)
            Temp=Timing.Name_Events{EventCounter, EventTypeCounter};
            Temp(strfind(Temp, '-'))='_';
            Temp(strfind(Temp, '+'))='_';
            Timing.ID_Events{EventCounter, EventTypeCounter}=Temp;
        end
    end
end

% If at least one of the events from this block (if it is purely block design
% there is only one event) are included then add timing to an experiment
% specific file. If this block should be excluded then add this block to
% the nuisance event timing file

if all(mean(Include_Events, 1)>0)
    %What is the name of the block file. The two levels have different
    ID.First={[Functional_name, '_', Timing.ID]};
    Name.First={[Functional_name, '_', Timing.Name]};
    
    ID.Second={Timing.ID};
    Name.Second={Timing.Name};
    
    %What should be run
    Levels_Selected=[1,2];
    
    Weight=[1, 1]; %Default to 1
else
    
    % Get the names for the timing files you will insert zeros in to
    ID.First={[Functional_name, '_', Timing.ID]};
    Name.First={[Functional_name, '_', Timing.Name]};
    
    ID.Second={Timing.ID};
    Name.Second={Timing.Name};
    
    %Preset
    ID.Confounds={};
    Name.Confounds={};
    
    %Iterate throught the nuisance variables
    for BlockTypeCounter = 1:length(NuisanceFileName)
        
        % If all events for this type of event exclusion should be excluded
        % then do so here.
        if all(Include_Events(:,BlockTypeCounter)==0)
            %What is the name of the block file. The two levels have different
            ID.Confounds{end+1}=[NuisanceFileName{BlockTypeCounter}, '_', Functional_name];
            Name.Confounds{end+1}=[NuisanceFileName{BlockTypeCounter}, '_', Functional_name];
        end
    end
    
    Weight=[0, 0, 1]; % Set to zero and don't change it (except for the confound file)
    
    % Run all three types
    Levels_Selected=[1,2,3];
    
end

%What are the extensions
TimingFile.First='analysis/firstlevel/Timing/';
TimingFile.Second='analysis/secondlevel/Timing/';
TimingFile.Confounds='analysis/firstlevel/Confounds/';

%% Overall block

%Should you make an entry in the timing file for this run?

if isfield(Timing, 'ID')
    
    for LevelCounter=Levels_Selected
        
        Level=Levels{LevelCounter};
        
        BlockTypes=length(ID.(Level));
        for BlockTypeCounter=1:BlockTypes
            %Save things for the text files
            %Does this file exist first
            if isempty(strcmp(fieldnames(FileIDs), ID.(Level){BlockTypeCounter})) || all(strcmp(fieldnames(FileIDs), ID.(Level){BlockTypeCounter})==0)
                
                output_name = [TimingFile.(Level), Name.(Level){BlockTypeCounter}, '.txt'];
                FileIDs.(ID.(Level){BlockTypeCounter})=fopen(output_name, 'w+');
                
                Timing.Blocks.(Level).(ID.(Level){BlockTypeCounter}).output_name = output_name;
            end
            
            % Determine the timing of the events
            if strcmp(Level, 'Second')
                timing_columns = [Secondlevel_block_onset, TaskTime, Weight(LevelCounter)];
            else
                timing_columns = [Firstlevel_block_onset, TaskTime, Weight(LevelCounter)];
            end
            
            fprintf(FileIDs.(ID.(Level){BlockTypeCounter}), '%0.3f\t%0.3f\t%0.3f\n', timing_columns(1), timing_columns(2), timing_columns(3));
            Timing.Blocks.(Level).(ID.(Level){BlockTypeCounter}).timing_columns = timing_columns;
            
        end
    end
end
%% Event files

%Should you make a timing files for this run?
if isfield(Timing, 'Events') && all(mean(Include_Events, 1)>0)
    
    % When is the first event for each timing count
    Firstlevel_event_onset = Firstlevel_block_onset + Timing.InitialWait;
    Secondlevel_event_onset = Secondlevel_block_onset + Timing.InitialWait; 
    
    %What is the event you are up to
    for EventCounter=1:Timing.Events
        
        %% Generate the weights
        
        %If the weights for this event are not uniform then pull this
        %out here.
        
        %Pull out the weights if possible
        
        Event_Weight=1; % Default to 1
        if isfield(EyeData, 'Weights') && isfield(EyeData.Weights, ExperimentName(12:end)) && isfield(EyeData.Weights.(ExperimentName(12:end)), 'Parametric')
            
            %What weight should be put on this
            %trial
            
            if isfield(EyeData.Weights.(ExperimentName(12:end)).Parametric, BlockName)
                if length(EyeData.Weights.(ExperimentName(12:end)).Parametric.(BlockName))>=EventCounter
                    Event_Weight=EyeData.Weights.(ExperimentName(12:end)).Parametric.(BlockName)(EventCounter);
                else
                    fprintf('Skipping Event %d because weights not collected\n', EventCounter);
                    continue
                end
            else
                fprintf('Skipping %s because weights not collected\n', BlockName);
                continue
            end
            
            
        end
        
        %% Create the condition files
        
        %Is there a Condition function and is this event to be included?
        if exist(sprintf('scripts/Analysis_Timing_functions/%s',func2str(ConditionFunction)))>0 && ~isnan(Event_Weight) && all(Include_Events(EventCounter,:))==1
            
            
            %For this experiment find the condition filenames. These names
            %are stored in the following format. For each element of the
            %Name_Condition structure outlines a different way of
            %organizing the events (e.g. Left vs right, or valid vs invalid
            %vs neutral). The subfields of this structure refer to each
            %level (first or second) that these timing files will be made
            %for. Finally for each level there are indexes of cells
            %referring to the different possible names for this condition.
            %Usually this will only be one element long but if an event
            %belongs to multiple conditions simultaneously (if the
            %conditions aren't mutually exclusive, like if the conditions
            %were features of a stimulus) then this corresponds to
            %different elements of this field. To ignore an event, supply
            %nans.
            
            outputs = cell(1,nargout(ConditionFunction));
            [outputs{:}] = ConditionFunction(EyeData, Timing, EventCounter, Functional_name, BlockName);
            
            % What is the name of the condition
            Name_Condition=outputs{1};
            
            % If a weight is outputted, grab it
            if length(outputs)==2 && length(outputs{2}) > 0 
                Condition_Weights=outputs{2};
            else
                Condition_Weights=cell(1, length(Name_Condition));
                Condition_Weights(:) = {1};
            end
            
            %Make the first and second level files
            Levels_Selected=[1,2];
            
            %Cycle through the different trial types to print these
            %events to these files (if they don't already exist
            for ConditionType=1:length(Name_Condition) %How many different condition types are there)
                
                % WHat is the weight for this condition
                Condition_Weight = Condition_Weights{ConditionType};
                
                for ConditionColumns=1:length(Name_Condition(ConditionType).First) %If an event is in multiple conditions of the same type then treat this as rows
                    
                    %Iterate through the first and secon levels
                    for LevelCounter=Levels_Selected
                        
                        Level=Levels{LevelCounter};
                        
                        %Set the ID name and then remove the
                        %hyphens
                        ID_Condition=Name_Condition(ConditionType).(Level){ConditionColumns};
                        ID_Condition(strfind(ID_Condition,'-'))='_';
                        
                        %skip nans or weights of zero
                        if any(~isnan(ID_Condition)) && Condition_Weight~=0 && ~isnan(Condition_Weight)
                            
                            %Make the file if it doesn't exist
                            if isempty(strcmp(fieldnames(FileIDs), ID_Condition)) || all(strcmp(fieldnames(FileIDs), ID_Condition)==0)
                                
                                output_name=[TimingFile.(Level), Name_Condition(ConditionType).(Level){ConditionColumns}, '.txt'];
                                
                                FileIDs.(ID_Condition)=fopen(output_name, 'w');
                                Timing.Condition.(Level).(ID_Condition).output_name = output_name;
                            end
                            
                            % Determine the column format
                            if strcmp(Level, 'Second')
                                timing_columns = [Secondlevel_event_onset, Timing.Task_Event(EventCounter), Condition_Weight];
                            else
                                timing_columns = [Firstlevel_event_onset, Timing.Task_Event(EventCounter), Condition_Weight];
                            end
                            
                            % Output the timing information
                            fprintf(FileIDs.(ID_Condition), '%0.3f\t%0.3f\t%0.3f\n', timing_columns(1), timing_columns(2), timing_columns(3));
                            
                            % Add the timing file information (or create it if it
                            % doesn't exist yet)
                            if isfield(Timing, 'Condition') && isfield(Timing.Condition, Level) && isfield(Timing.Condition.(Level), ID_Condition) && isfield(Timing.Condition.(Level).(ID_Condition), 'timing_columns')
                                Timing.Condition.(Level).(ID_Condition).timing_columns(end + 1, :) = timing_columns;
                            else
                                Timing.Condition.(Level).(ID_Condition).timing_columns = timing_columns;
                            end
                            
                        end
                    end
                end
            end
        end
        
            
        %% Create the event files
        
        %How many event files are there for this trial? Event types are
        %specified as columns in the ID_Events subfield. However, the
        %motion and eye tracking exclusion files will also be treated as different
        %event types when appropriate.
        
        EventTypes=size(Timing.ID_Events,2);
        
        %Overwrite the number of events if this event is to be excluded
        if any(Include_Events(EventCounter,:)==0)
           EventTypes=length(NuisanceFileName);
        end
        
        for EventTypeCounter=1:EventTypes
            if ~isnan(Event_Weight) && all(Include_Events(EventCounter,:))==1
                %What name on this trial
                ID_Events.First=[Functional_name, '_', Timing.ID_Events{EventCounter, EventTypeCounter}];
                ID_Events.Second=Timing.ID_Events{EventCounter, EventTypeCounter};
                
                Name_Events.First=[Functional_name, '_', Timing.Name_Events{EventCounter, EventTypeCounter}];
                Name_Events.Second=Timing.Name_Events{EventCounter, EventTypeCounter};
                Levels_Selected=[1,2];
            else
                % Is this event type to be excluded
                if Include_Events(EventCounter, EventTypeCounter)==0
                    Levels_Selected=[]; % Don't print to the event files now
                else
                    % If not then skip to the next event type
                    continue
                end
                
            end
            
            %Iterate through the levels
            for LevelCounter=Levels_Selected
                
                Level=Levels{LevelCounter};
                
                %Has the file been created
                if isempty(strcmp(fieldnames(FileIDs), ID_Events.(Level))) || all(strcmp(fieldnames(FileIDs), ID_Events.(Level))==0)
                    
                    output_name = [TimingFile.(Level), Name_Events.(Level), '.txt'];
                    FileIDs.(ID_Events.(Level))=fopen(output_name, 'w');
                    
                    Timing.Event.(Level).(ID_Events.(Level)).output_name = output_name;
                    
                end
                
                %Store the timing information
                if strcmp(Level, 'Second')
                   timing_columns = [Secondlevel_event_onset, Timing.Task_Event(EventCounter), Event_Weight];
                else
                   timing_columns = [Firstlevel_event_onset, Timing.Task_Event(EventCounter), Event_Weight];
                end
                
                fprintf(FileIDs.(ID_Events.(Level)), '%0.3f\t%0.3f\t%0.3f\n', timing_columns(1), timing_columns(2), timing_columns(3));
                
                % Add the timing file information (or create it if it
                % doesn't exist yet)
                if isfield(Timing , 'Event') && isfield(Timing.Event, Level) && isfield(Timing.Event.(Level), ID_Events.(Level)) && isfield(Timing.Event.(Level).(ID_Events.(Level)), 'timing_columns')
                    Timing.Event.(Level).(ID_Events.(Level)).timing_columns(end + 1, :) = timing_columns;
                else
                    Timing.Event.(Level).(ID_Events.(Level)).timing_columns = timing_columns;
                end
            end
                
        end
        
        %Increment this by how long the event was on this trial
        Firstlevel_event_onset = Firstlevel_event_onset + Timing.TimeElapsed_Events(EventCounter); 
        Secondlevel_event_onset = Secondlevel_event_onset + Timing.TimeElapsed_Events(EventCounter);
        
    end
    
end