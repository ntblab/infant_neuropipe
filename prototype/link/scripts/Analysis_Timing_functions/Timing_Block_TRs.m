%% Determine what TRs correspond to the start and end of this block.

function AnalysedData = Timing_Block_TRs(TempData, NextExperiment, AnalysedData, Data, BlockCounter, ExperimentName, BlockName, Functional_Counter, Default_BurnInTRNumber, BurnIn, Run_BurnIn_fid)

%Determine the Burn In, Task and Rest TRs

TaskStartingIdx=find(TempData.TR<TempData.TestStart,1, 'last'); % TR that triggered the experiment onset

% If all of the TRs are greater than the test start then you
% skipped burn in so you should set this accordingly
if isempty(TaskStartingIdx) && all(TempData.TR>TempData.TestStart)
    TaskStartingIdx=1;
end

BurnInTRs=TempData.TR(1:TaskStartingIdx-1); %What are the timestamps of the warm-up TRs (TRs before starting TR)

%Determine if this is the last experiment TR of a run and if so then
%don't take the last TR but rather the second to last one. This
%is because there might not be a TR volume for the last TR
%acquired. NextExperiment is empty when at the end of the session
%(there are no runs left) or when the next block has no TRs
%recorded in it

if isempty(NextExperiment.Timing.TR) || (Data.Global.RunOrder{BlockCounter+1, 4}-TempData.TR(end)) > AnalysedData.TR(Functional_Counter)*3
    LastTR=length(TempData.TR)-1; %Take the second to last TR because the last one wasn't finished
else
    LastTR=length(TempData.TR); %Take the last TR as a default
end

%What TR times correspond to the task?
if ~isempty(TaskStartingIdx) && length(TempData.TR)>=TaskStartingIdx
    %TaskTRTimestamps=TempData.TR(logical((logical(TempData.TestEnd>TempData.TR) .* logical(1:length(TempData.TR)>=TaskStartingIdx)))); %What TRs were used for the task
    TaskTRTimestamps=TempData.TR(logical((logical(TempData.TestEnd-TempData.TR>(AnalysedData.TR(Functional_Counter)/2)) .* logical(1:length(TempData.TR)>=TaskStartingIdx)))); %What TRs were used for the task
else
    TaskTRTimestamps=[];
end

%How many task TRs are there?
TaskTRs=length(TaskTRTimestamps);

%How many TRs after the task ends are there? Do some rounding so that if
%there is more than half a TR round up
%RestTimestamps=TempData.TR(TempData.TestEnd<TempData.TR(1:LastTR)); %What time are the TRs
RestTimestamps=TempData.TR(TempData.TestEnd-TempData.TR(1:LastTR)<(AnalysedData.TR(Functional_Counter) / 2)); %What time are the TRs
RestTRs=length(RestTimestamps);

% Correct these estimates in the case of errors

% If the last Burn in TR and first task TR are the same, something
% is wrong. Delete last burn in TR
if ~isempty(BurnInTRs) && ~isempty(TaskTRTimestamps) && TaskTRTimestamps(1)==BurnInTRs(end)
    fprintf('Your first task TR and your Burn In TR is the same. This can happen when the Burn in is skipped. Check it out. Deleting Burn in TR');
    BurnInTRs(end)=[];
end

% If the Task TRs are very few (ie, 2 task TRs and no rest TRs)
% then assume that this was a quit block and delete a TR (could be
% fixed by deleting a TR but this actually won't work if there are
% too few TRs)
if TaskTRs==2 && RestTRs==0 && Data.(ExperimentName).(BlockName).Quit==0
    fprintf('Assuming this block was quit so, a TR is being deleted. ');
    TaskTRs=TaskTRs-1;
end

%Find how many seconds from the first until the last task TR, and
%round to nearest integer
if TaskTRs>0
    TaskTime=round(TaskTRTimestamps(end)-TaskTRTimestamps(1)) + AnalysedData.TR(Functional_Counter);
else
    TaskTime=0;
end

%Store additional information that is need as an output
AnalysedData.(ExperimentName).(BlockName).TaskTime=TaskTime;
AnalysedData.(ExperimentName).(BlockName).TaskTRs = TaskTRs;
AnalysedData.(ExperimentName).(BlockName).RestTRs=RestTRs;
AnalysedData.(ExperimentName).(BlockName).BurnInTRs=BurnInTRs;
AnalysedData.(ExperimentName).(BlockName).RestTimestamps=RestTimestamps;

if BurnIn==1
    
    %If there are a surplus of burn in TRs then count these extra
    %ones, if there is less burn in TRs then expected, use this
    %number
    if length(BurnInTRs)>=Default_BurnInTRNumber
        %Add the number of TRs that are greater than the default, incase
        %there is a long burn in
        BurnInTR_Number=length(BurnInTRs)-Default_BurnInTRNumber; % number of surplus burn-ins
        Run_BurnInTRNumber=Default_BurnInTRNumber; % How many Burn in TRs are there for this run? Set to default
        
        % What is the first TR of the run
        AnalysedData.Run_Start_TR = BurnInTRs(Default_BurnInTRNumber) + AnalysedData.TR(Functional_Counter);
    else
        %If there are fewer TRs then expected change the Burn
        %number
        BurnInTR_Number=0; % no surplus burn-ins
        Run_BurnInTRNumber=length(BurnInTRs); % How many Burn in TRs are there for this run?
        
        % What is the first TR of the run
        AnalysedData.Run_Start_TR = TaskTRTimestamps(1);
    end
    
    %Report this
    fprintf('\nBurn In detected, %d TRs labelled\n', Run_BurnInTRNumber);
    
    % If this is not 3 then throw an error
    if Run_BurnInTRNumber~=3
        warning('Burn is not 3 for run %d but is instead %d. Rerunning the prep_raw_data with the appropriate burn in and then storing this run information for render-fsf-template. Note that if this is done unnecessarily then it will have flow on effects that are hard to detect. To overwrite, you need to rerun prep_raw_data with the correct parameters\n\n', Functional_Counter, Run_BurnInTRNumber);
        
        % Make sure you don't mess with the figures
        timecourse_fig=gcf;
        figure;
        
        % Run the prep_raw_data script with the appropriate burn in
        prep_raw_data([7,8,9], Functional_Counter, Run_BurnInTRNumber)
        
        % Return to original time course figure
        figure(timecourse_fig);
        
        % Write the functional run that ought to be excluded to
        % this file
        fprintf(Run_BurnIn_fid, sprintf('functional%02d %d\n', Functional_Counter, Run_BurnInTRNumber));
        
        % Edit the fsf file (only if it hasn't been editted already) and
        % find replace the burn in number
        fsf_file = sprintf('./analysis/firstlevel/functional%02d.fsf', Functional_Counter);
        temp_file = './temp_fsf.fsf';
        
        if exist(fsf_file) > 0
            command=sprintf('cat %s | sed "s:set fmri(ndelete) %d:set fmri(ndelete) %d:g" > %s', fsf_file, Default_BurnInTRNumber, Run_BurnInTRNumber, temp_file)
            unix(command);
            
            % Move the newly created fsf file
            movefile(temp_file, fsf_file);
        end
    end
    
else
    BurnInTR_Number=length(BurnInTRs);

end

% Add surplus burn-in TRs (not including default TRs) to the total
% time since the experiment began (but excluding runs we didn't use), as if the total time is now starting after any of the extra
% burn in that isn't being removed by FSL
AnalysedData.block_onset_time = AnalysedData.block_onset_time + (BurnInTR_Number * AnalysedData.TR(Functional_Counter));

% Time elapsed during block, adding up task and rest
AnalysedData.block_duration = (TaskTRs + RestTRs) * AnalysedData.TR(Functional_Counter);

% Store additional data
AnalysedData.BurnIn_Surplus = BurnInTR_Number;

% Only store if it is a burn in
if exist('Run_BurnInTRNumber', 'var') == 1
    AnalysedData.Run_BurnInTRNumber = Run_BurnInTRNumber;
end

% Check that the estimated block onset time is correct (This is the
% computation that Timing_MakeTimingFile does to specify the block onset time)
estimated_block_onset_time = Data.(ExperimentName).(BlockName).Timing.TestStart - AnalysedData.Run_Start_TR;
if Functional_Counter > 1
    estimated_block_onset_time = estimated_block_onset_time + sum(AnalysedData.FunctionalLength(1:end-1));
end

if abs(AnalysedData.block_onset_time - estimated_block_onset_time) > AnalysedData.TR(Functional_Counter)
    warning('The block onset time does not match the estimate based on the block start time relative to the run start (difference: %0.2f). Positive values suggest that there is some unaccounted for lag and should be taken seriously. Negative values might mean that the TRs began before the block, in which case you might be able to ignore them. Negative values also occur when the run is set to be excluded manually (rather than by Analysis_Timing). Further investigate this to check that this is correct', AnalysedData.block_onset_time - estimated_block_onset_time);
end

