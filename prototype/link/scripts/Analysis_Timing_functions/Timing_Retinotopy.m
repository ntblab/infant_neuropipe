%% Extract timing information for Retinotopy
% Prepare details about the timing of the retinotopy task
%
% Output the AnalysedData and necessary timing file information
%
% First take in the block names
% Specify information about the TR timing
%
% Created by C Ellis 7/31/16
function [AnalysedData, Timing]=Timing_Retinotopy(varargin)

%What inputs are relevant
GenerateTrials_All=varargin{1};
Data=varargin{2};
BlockName=varargin{3};
Data_Timing=varargin{4};
Window=varargin{5};

%You know the experiment name
ExperimentName='Experiment_Retinotopy';
GenerateTrials=GenerateTrials_All.(ExperimentName);


%What is the timing in this experiment?
try
    AnalysedData.TotalRunTime = Data_Timing.totalRunTime;
catch
    AnalysedData.TotalRunTime = Data_Timing.BlockEndTime-Data_Timing.InitPulseTime;
end
AnalysedData.InitialPulse = Data_Timing.InitPulseTime;

%Save things for the text file
%Does this file exist first

%What block is being done?
Idx=strfind(BlockName, '_');
iBlockCounter=str2num(BlockName(Idx(1)+1:Idx(2)-1));

%What is the block number
iBlockName=GenerateTrials.Parameters.BlockNames(iBlockCounter);
iBlockName=iBlockName{1};

%If this is an old design then remove this
if length(GenerateTrials.Parameters.NumConditions)>4
    iBlockName=iBlockName(1:end-1);
end

%What is the file name?
Timing.Name=[ExperimentName(min(strfind(ExperimentName, '_'))+1:end), '-', iBlockName];

% Pull out some info
start_time = Data.Experiment_Retinotopy.(BlockName).Timing.TestStart; % When did the block start
if isfield(GenerateTrials.Parameters, 'rot_period')
    rot_period =  GenerateTrials.Parameters.rot_period;           % rotation period of wedge or ring
    Redundancy =  GenerateTrials.Parameters.Redundancy;           % How much extra time will you sample
else
    % Add this info
    rot_period =  AnalysedData.TotalRunTime;
    Redundancy =  0;
end
type = GenerateTrials.Parameters.BlockNames{iBlockCounter};

% Get the information when an event happens in the retinotopy (e.g. a flash
% or an orientation change)
if isfield(Data.Experiment_Retinotopy.(BlockName), 'flash_Time')
    flipTimes = Data.Experiment_Retinotopy.(BlockName).flash_Time; % Pull out the timing of each flip
else
    % There are no events if it isn't specified
    flipTimes = [];
end

% The first time the time frac is calculated the value is start_time so add
% that to the list
flipTimes = [start_time, flipTimes];

% Calculate the timing fraction for every filp 
time_frac = (flipTimes - start_time)/rot_period - ((Redundancy - Window.frameTime * 2)/rot_period); %fraction of cycle we've gone through
time_frac(time_frac<0)=1+time_frac(time_frac<0); %If it is less than zero then correct
time_frac=time_frac-floor(time_frac); %If it is more than one then correct

% Determine the last frame of  a cycle.
cycle_offset_idxs=diff(time_frac)<-0.9; % when there is a big change in adjacent timepoints it is a cycle back (won't work if there is only one cycle in the block)

% When does the cycle start (based on the offset)
cycle_onset_idxs = [1, find(cycle_offset_idxs==1) + 1];

% Make sure there is an offset for every onset
cycle_onset_idxs=cycle_onset_idxs(1:sum(cycle_offset_idxs));

% When did the cycle onset in flip time
cycle_onset = flipTimes(cycle_onset_idxs);

% Make timing files if it is the vertical/horizontal and high/low first condition
if ~isempty(strfind(GenerateTrials.Parameters.BlockNames{iBlockCounter}, 'first')) || ~isempty(strfind(GenerateTrials.Parameters.BlockNames{iBlockCounter}, 'high'))
    
    % Calculate the flips that are in the first half
    is_first_half = time_frac < 0.5;
    ishorizontal_high=ones(size(is_first_half));
    if strcmp(type, {'horizontal_first'}) || strcmp(type, {'highlow'})
        ishorizontal_high(find(is_first_half==0))=0;
    elseif strcmp(type, {'vertical_first'}) || strcmp(type, {'lowhigh'})
        ishorizontal_high(find(is_first_half==1))=0;
    end

    % Find the transients in the orientation
    orientation_change=diff([1-ishorizontal_high(1), ishorizontal_high]); % Start so that there is always a transient
    horizontal_high_onset_idx = find(orientation_change==1); %Find all the indexes that correspond to transitions from vertical to horizontal or low to high
    vertical_low_onset_idx = find(orientation_change==-1); %Find all the indexes that correspond to transitions from horizontal to vertical or high to low
    
    % Ensure that these are the same length
    horizontal_high_onset_idx=horizontal_high_onset_idx(1:min([length(vertical_low_onset_idx), length(horizontal_high_onset_idx)]));
    vertical_low_onset_idx=vertical_low_onset_idx(1:min([length(vertical_low_onset_idx), length(horizontal_high_onset_idx)])); 
    
    % Order the events 
    [events, sorting_idx] = sort([flipTimes(horizontal_high_onset_idx), flipTimes(vertical_low_onset_idx)]);
    
    % Make a matching list of the indexes above using the names for this
    % condition
    if ~isempty(strfind(GenerateTrials.Parameters.BlockNames{iBlockCounter}, 'first'))
        Conditions=[repmat({'horizontal'}, 1,length(horizontal_high_onset_idx)), repmat({'vertical'}, 1,length(horizontal_high_onset_idx))];
    else
        Conditions=[repmat({'high'}, 1,length(horizontal_high_onset_idx)), repmat({'low'}, 1,length(horizontal_high_onset_idx))];
    end
    
    % Reorder the list based on the order of events
    Timing.Event_Conditions=Conditions(sorting_idx);
    
    %Record the data necessary for the event related design
    Timing.InitialWait=0; %How long before the first task event?
    
    %What is the file name for the events
    Timing.Events=length(events);  % How many events are there?
    Timing.Name_Events=repmat({[Timing.Name, '_Events']}, Timing.Events,1);

    % How long is each event
    if length(events) > 0
        Timing.Task_Event=[diff(events), Data_Timing.TestEnd-events(end)];
        
        % How long between each event
        Timing.TimeElapsed_Events=Timing.Task_Event;
    end
end

% Is this a radial condition
if ~isempty(strfind(GenerateTrials.Parameters.BlockNames{1}, 'radial'))
    
    %Pull out the sequence of stimuli
    Timing.Stimuli_sequence=Data.Experiment_Retinotopy.(BlockName).Stimuli.flash_sequence;
    
    %Record the data necessary for the event related design
    
    Timing.InitialWait=Data.Experiment_Retinotopy.(BlockName).flash_Time(1)-Data_Timing.TestStart; %How long before the first task event?
    
    %What is the file name for the events
    Timing.Events=length(Data.Experiment_Retinotopy.(BlockName).flash_Time);
    Timing.Name_Events=repmat({[Timing.Name, '_Events']}, Timing.Events,1);
    
    %What are the timing properties of the events
    
    Timing.Task_Event=[diff(Data.Experiment_Retinotopy.(BlockName).flash_Time)'; Data_Timing.TestEnd-Data.Experiment_Retinotopy.(BlockName).flash_Time(end)]; %How long is each trial relevant event
    
    Timing.TimeElapsed_Events=[diff(Data.Experiment_Retinotopy.(BlockName).flash_Time)'; Data_Timing.TestEnd-Data.Experiment_Retinotopy.(BlockName).flash_Time(end)]; %How long is it between the large image appearances?
    
end
end
