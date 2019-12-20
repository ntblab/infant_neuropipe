%% Analyse the timing information for each experiment to make timing files
%
% When collecting data from infants, each session is unpredictable. This
% means the same consistency we expect from adult scans cannot be expected
% with infants. To accommodate the unpredictability the 'Analysis_Timing.m'
% script has the *very* hard job of searching through all of the timing
% data stored in the matlab file output by Experiment Menu (including block
% onset times and TR trigger times), as well as the eye tracking timing. It
% then uses all this information to determine when blocks start and stop,
% which blocks to exclude and how to use any condition or behavioral data
% to generate timing files.
%
% This script is very important and so should be understood. For a thorough
% description of how this script works, refer to
% $SUBJ_DIR/scripts/Analysis_Timing_functions/README.md
%
% Relatively completed: C Ellis 5/31/16
% Moved to the cluster: C Ellis 9/12/16
% Reorganized and made more components functions: C Ellis 10/12/16
% Updated to deal with nuisance epochs: C Ellis 3/23/17
% Reordered when timing files are created and made pseudoruns possible: C Ellis 2/27/18
%
function AnalysedData= Analysis_Timing

%Remove the diary if it is present
if exist('analysis/Behavioral/AnalysedData_Log')==2
    delete('analysis/Behavioral/AnalysedData_Log');
end
    
diary('analysis/Behavioral/AnalysedData_Log'); %Start a log file

% Make sure all warnings are turned on
warning('on', 'all');

%Pull out name of data file
Temp=dir('data/Behavioral/*.mat');
for Counter=1:length(Temp)
    if isempty(strfind(Temp(Counter).name, 'Coder')) && isempty(strfind(Temp(Counter).name, 'riginal')) && isempty(strfind(Temp(Counter).name, '_bkp')) %Exclude the 'O' since this is case sensitive
        LoadName=Temp(Counter).name;
    end
end
        
%Load the data, delete everything except what is necessary
load(['data/Behavioral/', LoadName], 'Data', 'GenerateTrials', 'Window')

% Get experiment names (e.g., 'Experiment_PlayVideo')
ExperimentNames=fieldnames(Data);
ExperimentNames=ExperimentNames(2:end);
% Letter index at which specific name begins (e.g., index before 'PlayVideo')
ExpIdx=min(strfind(ExperimentNames{1}, '_'))+1;

% Set first and second level analysis directories
FirstLevel_Dir='analysis/firstlevel/';
SecondLevel_Dir='analysis/secondlevel/';
Confound_Dir='analysis/firstlevel/Confounds/';

%% ############# Critical parameters #############

AnalysedData.block_onset_time=0; %Start the timing counter here
BlockCounter=1; %What experimental block do you want to start on?
Included_TR_Threshold=0.5; %What proportion of TRs for a run are required for inclusion
default_TR = 2; % Assume the default TR is 2s

Motion_Exclude_Epoch=1; %Do you want to create a timing regressor for motion
EditTRs=1; %Do you want to edit TRs that werent recorded otherwise?
Default_BurnInTRNumber=3; %how many TRs are considered in the burn in

% What criteria do you want to use to make a pseudorun?
%       0: Do not do a pseudorun analysis
%       1: Divide runs based on experiment changes
%       2: Divide runs based on excluded blocks
%       3: Divide runs based on either experiment changes or excluded blocks
pseudorun_criteria = 1; 

%% ################################################

AnalysedData.FunctionalLength=0; %Preset value
FileIDs=struct();
MostRecentExperiment.TR=[]; %Set as empty

%Add folder with critical functions
addpath('scripts/Analysis_Timing_functions/');

% Create a text file to write any runs that have a burn in different from 3 in order to recall them in render-fsf-template 
Run_BurnIn_fid=fopen('analysis/firstlevel/run_burn_in.txt', 'w');

% Delete the files that would be created by this script so that they don't
% persist (e.g. you run motion thresholding at a strict threshold then
% raise it, you will retain the motion_exclude_epoch
Motion_Exclude_Epoch_files = dir([Confound_Dir, 'Motion_Exclude_Epochs_functional0*']);
for file_counter = 1:length(Motion_Exclude_Epoch_files)
    delete([Confound_Dir, Motion_Exclude_Epoch_files(file_counter).name]);
end

Eye_Exclude_Epoch_files = dir([Confound_Dir, 'EyeData_Exclude_Epochs_functional0*']);
for file_counter = 1:length(Eye_Exclude_Epoch_files)
    delete([Confound_Dir, Eye_Exclude_Epoch_files(file_counter).name]);
end

% Delete timing files
delete('analysis/firstlevel/Timing/*');
delete('analysis/secondlevel/Timing/*');

%% Exclude runs

% If this file exists then extract its contents. This file should contain
% just the numbers with a space between them.
Excluded_Runs=[];
if exist([Confound_Dir, 'Excluded_Runs'])==2
    Excluded_Runs=textread([Confound_Dir, 'Excluded_Runs']);
    
    fprintf('\n\nExcluding runs: %s\n\n', sprintf('%d ', Excluded_Runs));
end

%% Extract the motion exclude list

%Load in the Motion_Exclude_TR document: for each TR that needs to be
%excluded from the raw functional volume enter its index (as seen on
%FSLView) and for each run have a new line. The start of the line begins
%with 'functional01:' to mean functional run 01. 
% DO NOT use pseudorun numbering. This will be dealt with in the pseudorun
% script. Instead signal which TRs need to be excluded from the original
% run.
Motion_Exclude_TRs =struct;
if exist(sprintf('%s/Motion_Exclude_TRs.txt', Confound_Dir))>0
    fprintf('\n\nMotion Exclude list found\n\n');
    
    %Open Text document
    fid=fopen(sprintf('%s/Motion_Exclude_TRs.txt', Confound_Dir));
    
    %Iterate through the file and pull out the TRs of interest for each 
    while 1
        
        %Pull out the line
        Line=fgetl(fid);
        
        %Are you at the end of the document
        if all(Line==-1)
            break
        end
        
        % What is the run number
        colon_idx = min(strfind(Line, ':'));
        func_run = Line(strfind(Line, 'functional') + 10:colon_idx - 1);
        
        if length(func_run) > 2
            warning('Your func run %s is more than 2 characters, this is most likely inappropriate', func_run);
        end
        
        % What TRs are excluded
        excluded_TRs_str = strsplit(Line(colon_idx + 1:end));
        
        excluded_TRs = [];
        for counter = 1:length(excluded_TRs_str)
            
            if ~isempty(excluded_TRs_str{counter}) && all(isstrprop(excluded_TRs_str{counter}, 'digit'))
                excluded_TRs(end + 1) = str2num(excluded_TRs_str{counter});
                
                % Is this a colon index for a vector?
            elseif mean(isstrprop(excluded_TRs_str{counter}, 'digit')) > 0.5 && length(strfind(Line, ':')) > 1
                vec = eval(excluded_TRs_str{counter});
                excluded_TRs(end + 1: end + length(vec)) = vec;
            end
            
        end
        
        Motion_Exclude_TRs.(sprintf('functional%s', func_run)) = excluded_TRs;
        
    end
    fclose(fid);
    
else
    fprintf('\n\nMotion Exclude list not found\n\n');
end

%% Extract the motion confound list

% What TRs are flagged by Motion_Outliers as being worth removal

%What functionals are there
Func_Files=dir('data/nifti/*functional*.nii.gz');

%Iterate through the files
Motion_Confound_TRs = struct;
for FileCounter=1:length(Func_Files)
    
    %Pull out the file name
    Idx=strfind(Func_Files(FileCounter).name, '.nii.gz');
    FileCounterStr=Func_Files(FileCounter).name(Idx-2:Idx-1);
    
    %What is the name of the file
    File=sprintf('%s/MotionConfounds_functional%s.txt', Confound_Dir, FileCounterStr);
    
    %Check if the file exists
    if exist(File)==2
        
        %Report that it was found
        fprintf('\n\nMotionConfounds_functional%s.txt found\n\n',  FileCounterStr);
        
        %Open Text document
        ConfoundMat=textread(File);
        
        %So that the list has the same number of entries as the exclude and the
        %run general, insert TRs for the burn in
        ConfoundMat=[zeros(Default_BurnInTRNumber, size(ConfoundMat,2)); ConfoundMat];
        
        %Find the row indices of the ones in the mat
        [ConfoundList, ~]=find(ConfoundMat==1);
        
        %Confound
        Motion_Confound_TRs.(sprintf('functional%s', FileCounterStr))=ConfoundList;
    end
end

%If ConfoundMat doesn't exist then report so
if exist('ConfoundMat')==0
    fprintf('\n\nNo confound files found\n\n');
end

%% Ignore TRs that don't have a functional volume associated with them
% If you recieved triggers, such as for a calibration, but did not keep the
% functional volume associated with it then you will want to exclude those
% TRs from the data. To do this, you can specify a time window (relative to
% the start of the menu) that you will exclude TRs between. This is a two
% column file with each row as a window and the first column being the
% start (in seconds since experiment start) and the second column being the
% end (in seconds). This file must be called:
% analysis/Behavioral/Analysis_Timing_TR_ignore.txt
ignore_file = 'analysis/Behavioral/Analysis_Timing_TR_ignore.txt';
if exist(ignore_file) > 0
    
    % Load the file
    ignore_list = textread(ignore_file);
    
    % Cycle through the rows
    expt_names = fieldnames(Data);
    session_start = Data.Global.Timing.Start;
    for window_counter = 1:size(ignore_list, 1)
        
        % When do the times start and stop?
        start_time = ignore_list(window_counter, 1);
        end_time = ignore_list(window_counter, 2);
        
        % What TRs are in this window
        window_idxs = logical(((Data.Global.Timing.TR - session_start) > start_time) & ((Data.Global.Timing.TR - session_start) <= end_time));
        
        % Remove these idxs
        Data.Global.Timing.TR = Data.Global.Timing.TR(window_idxs == 0);
        
        fprintf('Ignoring %d TRs between %0.1fs and %0.1fs as manually specified\n', sum(window_idxs), start_time, end_time); 
        
        % Cycle through experiments
        expected_exclusions = sum(window_idxs);
        observed_exclusions = 0;
        for expt_name = expt_names'
            
            if strfind(expt_name{1}, 'Experiment') > 0
            
                % Cycle through the blocks
                block_names = fieldnames(Data.(expt_name{1}));
                
                for block_name = block_names'
                    
                    % What TRs are in this window
                    window_idxs = logical(((Data.(expt_name{1}).(block_name{1}).Timing.TR - session_start) > start_time) & ((Data.(expt_name{1}).(block_name{1}).Timing.TR - session_start) <= end_time));
                    
                    % How many exclusions are you up to seeing?
                    observed_exclusions = observed_exclusions + sum(window_idxs);
                    
                    % Remove these idxs
                    Data.(expt_name{1}).(block_name{1}).Timing.TR = Data.(expt_name{1}).(block_name{1}).Timing.TR(window_idxs == 0);
                end
            end
        end 
        
        % Check that there is a match in the number of excluded time points
        if expected_exclusions ~= observed_exclusions
            fprintf('Mismatch in ignored TRs\nNumber from counting in experiments: %d; Number from globals: %d', sum(observed_exclusions), expected_exclusions);
        end
        
    end 
end

%% Perform the eye tracking preparation analysis 

%Report the number of coders
if length(dir('data/Behavioral/*Coder*'))<2
    fprintf('\nYou only have %d coders\n\n', length(dir('data/Behavioral/*Coder*')));
end

% %Pull out all of the eye tracking when it is organized the way it is
try
    
    % Aggregate all of the timing information across coders
    EyeData=EyeTracking_Aggregate(GenerateTrials);
    
    % Edit the event information if necessary (e.g. create or remove
    % events)
    EyeData=EyeTracking_Edit_Events(EyeData, Data, GenerateTrials);
    
    %Summarise how many frames from each block were collected.
    EyeTracking_summarise_image_list(EyeData.Indexes, EyeData.ImageList, Data);
    
    %Extract the responses from the eye tracking data
    EyeData=EyeTracking_Reliability(EyeData, Data);
    
    %Extract the responses from the eye tracking data
    EyeData=EyeTracking_Responses(EyeData);
    
    %Perform experiment specific analyses. Edit this for new experiments
    EyeData=EyeTracking_Experiment(EyeData, Data, GenerateTrials);
    
    %Decide which events to exclude
    EyeData=EyeTracking_Exclude(EyeData);
catch msg
    
    warning('Eye tracking analysis failed. Error is:');
    
    fprintf(msg.message)
    
    fprintf('\nDo you want to continue despite this error? If so press any key to continue.\n');
    pause;
    
    % Make the eye data struct if it doesn't exist
    if exist('EyeData')==0
        EyeData=struct;
    end
end

%Set up the display for showing which TRs are accounted for
%Set up the figure
figure;
set(gca, 'YTick', 0:length(ExperimentNames), 'YTickLabel', fieldnames(Data))
ylabel(' ') % y axis: experiment (categorical)
ylim([0,length(ExperimentNames)+0.05]); %Set the limit
xlabel('Seconds') % x axis: seconds, from beginning to end of experiment  
hold on

%Start off by plotting all the TRs recorded globally
RecordedTRs=Data.Global.Timing.TR - Data.Global.Timing.Start; %When did the TRs occur
scatter(RecordedTRs, zeros(1,length(RecordedTRs))) %Plot in position in the list of experiments run (global, 0)
xlim([0, RecordedTRs(end)]);

%Store the data
save('analysis/Behavioral/EyeData.mat', 'EyeData');
AnalysedData.EyeData=EyeData;

%% Iterate through each block
fprintf('\nIterating through the block\n------------------------------------------------------------\n\n');
                    
Functional_Counter=0; %What block (scanning period) are you on
Include_Run=1; %Is this run included (Does it increment the total time counter?)
block_fid = fopen('analysis/Behavioral/block_order.txt', 'w');
fprintf(block_fid, 'Experiment\tBlock\tDuration\tTRs\tExcluded eyetracking\tExcluded TRs\n');
while BlockCounter<=size(Data.Global.RunOrder,1)
    
    %% Collect information from this block
    
    ExperimentName=Data.Global.RunOrder{BlockCounter,1}; %What experiment is this called
    
    IndexTemp=strfind(ExperimentNames, ExperimentName);
    %What experiment is this, in terms of y-axis of the TR plot: 1 being
    %the first experiment, 2 being the second, etc. 
    ExperimentCounter = find(not(cellfun('isempty', IndexTemp))); 

    BlockName=Data.Global.RunOrder{BlockCounter,2}; %What is the block name
    % Block is named as Block_X_Y, where X is block number referring to 
    % experimental condition, and Y is the repetition number of that
    % condition. Pull out these numbers. 
    Temp=strfind(BlockName, '_');
    BlockNumber=BlockName(Temp(1)+1:Temp(2)-1);
    RepetitionCounter=BlockName(Temp(2)+1:end);
    
    PrintLog=''; %Collect all of the information that you want to print for this block
    
    %What is the TR length in sec? Get a different TR if the last column of
    %RunOrder has a T as the first letter then assume this is the TR
    if strcmp(Data.Global.RunOrder{BlockCounter,end}(1), 'T')
        Window.TR=str2num(Data.Global.RunOrder{BlockCounter,end}(3:end));
    end
    TR=Window.TR;
    
    %What are the block names of the experiments
    BlockNames=fieldnames(Data.(ExperimentName));
    IndexTemp=strcmp(BlockNames, BlockName); % index of current block
    
    %Is this an odd or an even block
    %If odd, plot 0.05 below experiment line on y-axis. If even, plot 0.05
    %above.
    YHeight=ExperimentCounter-((mod(find(IndexTemp==1),2)/10))+0.05;
    
    %What is the next experiment to be run (if there isn't one then make
    %the variable and make it empty)
    if BlockCounter<size(Data.Global.RunOrder,1)
        NextExperiment=Data.(Data.Global.RunOrder{BlockCounter+1,1}).(Data.Global.RunOrder{BlockCounter+1,2});
    else
        NextExperiment.Timing.TR=[];
    end
    
    % Raw data: what TRs really happened (versus those you interpolated)
    RealTRs=Data.(ExperimentName).(BlockName).Timing.TR;
    
    %% Edit the TRs if necessary: duplicates, interpolate, generate, etc
    
    %If the file is deficient in information then add it
    Data.(ExperimentName).(BlockName).Timing=Timing_UpdateInformation(Data.(ExperimentName).(BlockName), ExperimentName);
    
    if EditTRs==1
        
        [TempData, InterpolatedTRs, PlottedGuessedTRs, Temp_PrintLog]=Analysis_EditTRs(Data.(ExperimentName).(BlockName), MostRecentExperiment, Window, Data.Global.RunOrder{BlockCounter,6}, ExperimentName);
        
        %Report what is happening 
        PrintLog = [sprintf('\n%s: %s', ExperimentName, BlockName), Temp_PrintLog];
    end
    
    %% Prepare the timing data for different files
    % Takes in each experiment and prepares it to make timing files.
    % Specifically it identifies the timing file names and timing details
    % for the events and conditions, if appropriate
    
    Timing_Experiment=str2func(['Timing_', ExperimentName(ExpIdx:end)]);
    
    % Each experiment has its own timing function named Timing_EXPERIMENTNAME
    % that prepares timing information specific to that experiment. Call
    % that function here
    try
        [AnalysedData.(ExperimentName).(BlockName), Timing_File_Struct]=Timing_Experiment(GenerateTrials, Data, BlockName, TempData, Window);
    catch
        
        % If experimental timing function fails to generate output, throw
        % a warning
        fh = functions(Timing_Experiment); % Create a function handle object
        if Data.(ExperimentName).(BlockName).Quit==1
            text=sprintf('Failed to generate timing information for %s %s. This might be because the experiment was quit before the first trial was completed. No timing files will be generated.', ExperimentName,BlockName);
        elseif isempty(fh.file)
            text=sprintf('Failed to generate timing information for %s %s. This might be because the timing file function: %s does not exist. No timing files will be generated.', ExperimentName,BlockName,['Timing_', ExperimentName(ExpIdx:end)]);
        else
            text=sprintf('Failed to generate timing information for %s %s. Investigate what might be wrong. No timing files will be generated.', ExperimentName,BlockName);
        end
        
        warning(text);
        
        % Change to structures so that you can add information on later
        AnalysedData.(ExperimentName).(BlockName)=struct;
        Timing_File_Struct=struct;
    end
    
    
    %% Plot information for this block
    
    % Y axis: Where in the plot should things appear
    Yposition=ones(1,length(TempData.TR)+length(InterpolatedTRs)+length(PlottedGuessedTRs))*YHeight;
    
    % plot real TRs as red points (if there are inconsistent time points it
    % is probably because of over sampling the RealTRs)
    if length(RealTRs) == length(Yposition)
        scatter((RealTRs - Data.Global.Timing.Start), Yposition(1:length(RealTRs)), 'r.'); %Put it in the position in the list of experiments run
    else
        scatter((RealTRs - Data.Global.Timing.Start), repmat(Yposition(1), 1, length(RealTRs)), 'r.');
    end
    
    %Plot inferred TRs, if there are any, as red and yellow circles
    scatter((InterpolatedTRs - Data.Global.Timing.Start), Yposition(1:length(InterpolatedTRs)), 'ro') %Put it in the position in the list of experiments run
    scatter((PlottedGuessedTRs - Data.Global.Timing.Start), Yposition(1:length(PlottedGuessedTRs)), 'yo') %Put it in the position in the list of experiments run
    
    %Plot a black line between start of block and end of block, representing the block duration
    plot([TempData.TestStart-Data.Global.Timing.Start, TempData.TestEnd-Data.Global.Timing.Start], [ExperimentCounter, ExperimentCounter], 'k')
    
    
    if isfield(Timing_File_Struct, 'Name') && ~isempty(TempData.TR) %Is there a timing file to store and are there TRs in this data
        
        % Only add this if there are TRs on this functional (or else
        % ending a session on a movie would add to this).
        AnalysedData.TR(Functional_Counter+1)=TR;
        
        %% Determine if a Burn In occurred and start a new run if it did
        
        %Is there a burn in?    
        %CHeck that this isn't the first loop and that there are TRs in the current and past block
        if exist('MostRecentExperiment') && ~isempty(MostRecentExperiment.TR) && ~isempty(TempData.TR) && (TempData.TR(1)-MostRecentExperiment.TR(end))<(TR*1.5)
            if TempData.TR(1)-MostRecentExperiment.TR(end)<TR*3 %If you missed less than two TRs then assume there was no burn in
                BurnIn=0; %There is no burn in
            end
        else
            %If there is a burn in then this means it is the start of a new
            %event
            BurnIn=1; %Default that there is a burn in
            
            %Are there TRs in this data
            if ~isempty(TempData.TR)
                
                %If it is no longer the first functional then compare the
                %duration of this functional with the claimed duration
                if Functional_Counter>0
                    
                    % Explain what to do if the TR is not 2s
                    if TR~=default_TR
                        warning('The TR is not 2s for this block but is instead %0.2f. Take the following steps:\n1. Change the TR value in analysis/firstlevel/Confounds/Epochs_design.fsf. If only one block has a different TR, this may require more surgical changes to both this fsf file and to FEAT_firstlevel.sh', TR);
                    end
                    
                    % If there are no blocks from this run then exclude it
                    % after the fact
                    if length(AnalysedData.Included_BlocksPerRun{Functional_Counter}) == 0
                        try
                            % Move the file (only if it hasn't be moved
                            % yet)
                            if exist(sprintf('analysis/firstlevel/functional0%d_excluded_run.fsf',Functional_Counter)) == 0
                                movefile(sprintf('analysis/firstlevel/functional0%d.fsf',Functional_Counter), sprintf('analysis/firstlevel/functional0%d_excluded_run.fsf',Functional_Counter));
                            end
                            
                            % If the run is to be excluded then subtract
                            % the run duration for this run from the count
                            AnalysedData.block_onset_time = AnalysedData.block_onset_time - AnalysedData.FunctionalLength(Functional_Counter);
                            
                            % Now delete the length of the functional data
                            AnalysedData.FunctionalLength(Functional_Counter) = 0;
                            
                            % Delete the timing files for this run from
                            % first level. This will leave intact the
                            % timing files at second level but since
                            % they are zeroed out by necessity they
                            % shouldn't be used by FunctionalSplitter
                            delete(sprintf('analysis/firstlevel/Timing/functional0%d_*', Functional_Counter));
                            
                            warning('Run %d will not be included!\nfsf file for this run has been changed to avoid running this.\nNo timing files were created at firstlevel (some timestamps may be added to second level but these should not interfere with further computation). The TRs from this run were deleted from the count, hence it will not contribute to the total time (affecting other run timing files).\n', Functional_Counter);
                            
                        catch
                            warning('Run %d will not be included!\nfsf file was not renamed\nTiming files will not be created and this run will not contribute to the total time (affecting other run timing files).\n', Functional_Counter);
                        end
                        
                        % Set included to zero
                        Include_Run = 0;
                        
                    else
                        % fsf file labelled for removal but should be
                        % included
                        if exist(sprintf('analysis/firstlevel/functional0%d_excluded_run.fsf',Functional_Counter)) > 0
                            movefile(sprintf('analysis/firstlevel/functional0%d_excluded_run.fsf',Functional_Counter), sprintf('analysis/firstlevel/functional0%d.fsf',Functional_Counter));
                            warning('Found analysis/firstlevel/functional0%d_excluded_run.fsf for removal, including it instead\n', Functional_Counter);
                        end
                        
                    end
                    
                    % Store the run inclusion information
                    AnalysedData.Include_Run(Functional_Counter) = Include_Run;
                    
                    % Divide run into a pseudo-run
                    if Include_Run == 1
                        
                        AnalysedData = pseudorun_divide(AnalysedData, Functional_Counter, pseudorun_criteria, Run_BurnIn_fid);
                    end
                    
                    % Get the summary
                    [AnalysedData, FileIDs] = RunSummary(Func_Files, Functional_Counter, AnalysedData, AnalysedData.Run_BurnInTRNumber, FileIDs);
                    
                end
                
                % Set up the new run
                Functional_Counter=Functional_Counter+1; %Increment the functional
                
                AnalysedData.FunctionalLength(Functional_Counter)=0; %Set to zero
                AnalysedData.Excluded_TRs{Functional_Counter}=[]; %Preset
                AnalysedData.Eye_Data_Excluded_TRs{Functional_Counter}=[]; %Preset
                AnalysedData.Included_BlocksPerRun{Functional_Counter}={};%Preset
                AnalysedData.All_BlocksPerRun{Functional_Counter}={};%Preset
                
                %Is this run listed in those to be excluded? 
                if any(Excluded_Runs==Functional_Counter)
                    Include_Run=0;
                    try
                        movefile(sprintf('analysis/firstlevel/functional0%d.fsf',Functional_Counter), sprintf('analysis/firstlevel/functional0%d_excluded_run.fsf',Functional_Counter));
                        warning('Run %d will not be included!\nfsf file for this run has been changed to avoid running this.\nTiming files will not be created and this run will not contribute to the total time (affecting other run timing files).\n', Functional_Counter);
                    catch
                        warning('Run %d will not be included!\nfsf file was not renamed\nTiming files will not be created and this run will not contribute to the total time (affecting other run timing files).\n', Functional_Counter);
                    end
                    
                else
                    
                    Include_Run=1;
                end
                
            end
        end
        
        %% Determine what TRs correspond to the start and end of this block. 
        % This creates a number of new fields in AnalysedData and updates
        % some status variables. Of particular import is the
        % block_onset_time (when does the block start, after any burn in or
        % delay between blocks) and BurnIn_Surplus (Are there more than 3
        % (if burn in) or more than 0 (if between blocks) TRs recorded as
        % burn in and if so, how many.
        AnalysedData = Timing_Block_TRs(TempData, NextExperiment, AnalysedData, Data, BlockCounter, ExperimentName, BlockName, Functional_Counter, Default_BurnInTRNumber, BurnIn, Run_BurnIn_fid);
        
        %% Identify every TR with an experiment, block, repetition and event
        % When do the blocks start (start of burn in) and end (end of burn
        % out, not when the stimuli offset)
        block_start_TR=(AnalysedData.FunctionalLength(Functional_Counter)/TR)+1; %What TR are you up to at the start of this block. The start is 1

        if BurnIn==1
            block_start_TR=block_start_TR + AnalysedData.BurnIn_Surplus;
            block_end_TR=(AnalysedData.(ExperimentName).(BlockName).TaskTRs + AnalysedData.(ExperimentName).(BlockName).RestTRs)+block_start_TR; %What is the first TR of the next block
        else
            block_end_TR=(AnalysedData.BurnIn_Surplus + AnalysedData.(ExperimentName).(BlockName).TaskTRs + AnalysedData.(ExperimentName).(BlockName).RestTRs)+block_start_TR; %What is the first TR of the next block
        end
        
        % What TRs are used in this block?
        block_TRs=block_start_TR:block_end_TR-1;  
        
        AnalysedData.(ExperimentName).(BlockName).block_TRs=block_TRs;
        
        [AnalysedData, PrintLog] = Timing_TR_Timecourse(AnalysedData, ExperimentName, BlockName, Functional_Counter, Timing_File_Struct, PrintLog);

        %% Determine which events should be excluded because their eyes were closed
        % Set up a regressor which represents the activity of eyes being
        % closed or inappropriately positioned (e.g. off centre in
        % retinotopy)

        %Default to include all events. The first column represents the eye
        %tracking, the second column is the motion
        if isfield(Timing_File_Struct, 'Events')
            if Motion_Exclude_Epoch==1
                Include_Events=ones(Timing_File_Struct.Events,2);
            else
                Include_Events=ones(Timing_File_Struct.Events,1);
            end
            Proportion_EyeTracking_Excluded=zeros(Timing_File_Struct.Events,1);
        else
            % If this is only a block design then treat the block as an
            % event for now. This may be updated if there is eye tracking
            % information stored below
            if Motion_Exclude_Epoch==1
                Include_Events=[1, 1]; 
            else
                Include_Events=1; 
            end
            Proportion_EyeTracking_Excluded=0;
        end
        
        %If no eye tracking was provided then assume it will be included.
        %This works for something like RestingState
        EyeTracking_Excluded_TRs = [];
        Pseudo_ExperimentName=ExperimentName(12:end); % Take only the suffix
        
        % Deal with the hacky scenario where you care about eye tracking
        % for certain PlayVideo blocks
        if strcmp(Pseudo_ExperimentName, 'PlayVideo') && strcmp(BlockName(1:7), 'Block_3')
            Pseudo_ExperimentName=sprintf('%s_%s', Pseudo_ExperimentName, BlockName(1:7));
        end
        
        if isfield(EyeData, 'TrialsIncluded') && isfield(EyeData.TrialsIncluded, Pseudo_ExperimentName) && isfield(EyeData.TrialsIncluded.(Pseudo_ExperimentName), BlockName)
            
            % If data wasn't collected half way through then you might have
            % more trials than eye tracking data
            if size(EyeData.TrialsIncluded.(Pseudo_ExperimentName).(BlockName),1)>=size(Include_Events,1)
                
                % Exclude all events which have inappropriate eye movements
                Include_Events(:,1)=EyeData.TrialsIncluded.(Pseudo_ExperimentName).(BlockName)(1:size(Include_Events,1),1);
                
                % What is the proportion of eyetracking collected on
                % this trial for later reporting
                Proportion_EyeTracking_Excluded=1-EyeData.TrialsIncluded.(Pseudo_ExperimentName).(BlockName)(1:size(Include_Events,1),2);
            else
                
                % Do the same as above but limit the amount of events
                % considered
                Temp_Events=size(EyeData.TrialsIncluded.(Pseudo_ExperimentName).(BlockName),1);
                Include_Events(1:Temp_Events,1)=EyeData.TrialsIncluded.(Pseudo_ExperimentName).(BlockName)(1:Temp_Events,1);
                
                Proportion_EyeTracking_Excluded(1:Temp_Events)=1-EyeData.TrialsIncluded.(Pseudo_ExperimentName).(BlockName)(1:Temp_Events,2);
                Proportion_EyeTracking_Excluded(Temp_Events+1:end)=1;
                
                Include_Events(Temp_Events+1:end,1)=0;
                
            end
            
            % Go through the events that were collected and list the TRs
            % that are excluded because events are excluded (will be
            % helpful to have a list of motion excluded TRs and eye
            % tracking excluded TRs)
            for event_counter =1:size(Include_Events, 1)
                
                % For the events that should be excluded, figure out the
                % TRs that will also be excluded as a result
                if Include_Events(event_counter, 1) == 0
                    
                    % Is this eventwise, or blockwise
                    if isfield(Timing_File_Struct, 'Events')
                        
                        % When did the event start and end
                        event_start_time = sum(Timing_File_Struct.TimeElapsed_Events(1:event_counter - 1)) + Timing_File_Struct.InitialWait;
                        event_end_time = event_start_time + Timing_File_Struct.Task_Event(event_counter);
                        
                        % Find the TRs that will be ignored. Use rounding
                        % to ensure that you over estimate this
                        block_TRs_temp = (round((event_start_time / AnalysedData.TR(Functional_Counter))):round(event_end_time / AnalysedData.TR(Functional_Counter)));
                        
                        % Remove any zeros
                        block_TRs_temp=block_TRs_temp(block_TRs_temp>0);
                        
                        EyeTracking_Excluded_TRs = [EyeTracking_Excluded_TRs, block_TRs_temp];
                    else
                        % If this is blockwise and you should exclude it
                        % then all TRs should be excluded
                        EyeTracking_Excluded_TRs = [EyeTracking_Excluded_TRs, block_TRs];
                        
                    end
                    
                end
                
            end
            
        end
        
        
        %% Does this block/event require removal because too many TRs are missing?
        
        %Are a suffcient number of TRs to be excluded in order to exclude
        %this block.
        
        %What TRs ought to be excluded. Since Motion_Confounds do not
        %exclude burn in you should do this here.
        if isfield(Motion_Exclude_TRs, sprintf('functional%02d', Functional_Counter))
            temp_exclude = Motion_Exclude_TRs.(sprintf('functional%02d', Functional_Counter));
        else
            temp_exclude = [];
        end
        if isfield(Motion_Confound_TRs, sprintf('functional%02d', Functional_Counter))
            temp_confound = Motion_Confound_TRs.(sprintf('functional%02d', Functional_Counter))';
        else
            temp_confound = [];
        end
        ExcludedTRs = [temp_exclude, temp_confound] - AnalysedData.Run_BurnInTRNumber;
        ExcludedTRs = unique(ExcludedTRs); % Make sure to remove redundancy
        
        %Bound them to the TRs for this block
        ExcludedTRs=ExcludedTRs(block_start_TR<=ExcludedTRs);
        ExcludedTRs=ExcludedTRs(block_end_TR>ExcludedTRs);
        
        %Add all the TRs to be excluded to the list
        AnalysedData.Excluded_TRs{Functional_Counter}(end+1:end+length(ExcludedTRs))=ExcludedTRs;
        
        %How many TRs are excluded because of this
        Proportion_TRs_Excluded=length(ExcludedTRs)/length(block_TRs);
        
        % DId they quit the block (ignore if it is resting state or PlayVideo since
        % these blocks are always quit 
        if ~strcmp(ExperimentName, 'Experiment_RestingState')
            QuitBlock=Data.(ExperimentName).(BlockName).Quit;
        else
            QuitBlock=0;
        end
        
        %% Decide which events/blocks should be excluded
        
        %Is this block to be included given the number of TRs to be excluded
        if Proportion_TRs_Excluded<Included_TR_Threshold
            Include_Block=1;
        else
            Include_Block=0;
            
            % Set all the events to zero so that the timing file will make
            % the appropriate nuissance regressor file
            Include_Events(:)=0;
            
        end
        
        % Exclude block if it is quit
        if QuitBlock==1
            
            Include_Block=0;
            Include_Events(:)=0;
            
            PrintLog=[PrintLog, sprintf('\nExcluding this block because it was quit.\n')];
        end
        
       
        % Iterate through the time course and identify the TRs associated
        % with events, determing whether to include the event or not
        if isfield(Timing_File_Struct, 'Events') && Include_Block == 1
            for EventCounter=1:Timing_File_Struct.Events
                
                %What TRs did this event occur in
                EventIdxs=[];
                for TRCounter=1:length(AnalysedData.(ExperimentName).(BlockName).EventList)
                    if ~isempty(find(AnalysedData.(ExperimentName).(BlockName).EventList{TRCounter}==EventCounter))
                        EventIdxs(end+1)=TRCounter;
                    end
                end
                
                %How many TRs of this event have been excluded?
                Proportion_TRs_Excluded_Events(EventCounter)=(length(EventIdxs) - length(setdiff(EventIdxs+block_start_TR, ExcludedTRs)))/length(EventIdxs);
                
                %If no TRs excist for the event then exclude it
                if isnan(Proportion_TRs_Excluded_Events(EventCounter))
                    Proportion_TRs_Excluded_Events(EventCounter)=1;
                end
                
                %Is this event to be included
                if Proportion_TRs_Excluded_Events(EventCounter)>Included_TR_Threshold && Motion_Exclude_Epoch==1
                    
                    %Set to zero
                    Include_Events(EventCounter,2)=0;
                end
                
            end
            
            % Exclude the relevant events
            for EventCounter=1:size(Include_Events,1)
                if any(Include_Events(EventCounter,:)==0)
                    PrintLog=[PrintLog, sprintf('\nEvent %d was excluded.\nProportion of eyetracking frames excluded: %0.2f\nProportion of TRs excluded: %0.2f\n\n', EventCounter, Proportion_EyeTracking_Excluded(EventCounter), Proportion_TRs_Excluded_Events(EventCounter))];
                end
            end
        end
        
        %If no events in the block are included then exclude this block.
        if all(Include_Events(:,1)==0)
            Include_Block=0;
        end
        
        % Report back on whether the block was included
        if Include_Block == 0
            PrintLog=[PrintLog, sprintf('\n### Excluding this block! ###\n\n')];
        end
        
        % Print the inclusion and exclusion rates
        PrintLog=[PrintLog, sprintf('Proportion of EyeTracking Exclusion; %0.2f\nProportion of TRs excluded: %0.2f\n', mean(Proportion_EyeTracking_Excluded), Proportion_TRs_Excluded)];
        
        fprintf(block_fid, '%s\t%s\t%0.2f\t%d\t%0.2f\t%0.2f\n', ExperimentName, BlockName, AnalysedData.(ExperimentName).(BlockName).TaskTime, length(TempData.TR), mean(Proportion_EyeTracking_Excluded), Proportion_TRs_Excluded);
        
        %% Store the relevant information 
        
        AnalysedData.(ExperimentName).(BlockName).Proportion_EyeTracking_Excluded=Proportion_EyeTracking_Excluded;
        AnalysedData.(ExperimentName).(BlockName).TRs=TempData.TR;
        AnalysedData.(ExperimentName).(BlockName).Include_Block=Include_Block;
        AnalysedData.(ExperimentName).(BlockName).ExcludedTRs=ExcludedTRs-block_start_TR;
        AnalysedData.(ExperimentName).(BlockName).Proportion_TRs_Excluded=Proportion_TRs_Excluded;
        AnalysedData.(ExperimentName).(BlockName).Include_Events=Include_Events;
        AnalysedData.(ExperimentName).(BlockName).EyeTracking_Excluded_TRs=EyeTracking_Excluded_TRs;
        
        %Change the colors of the rest TRs
        if ~isempty(AnalysedData.(ExperimentName).(BlockName).BurnInTRs); 
%             hold on
            scatter((AnalysedData.(ExperimentName).(BlockName).BurnInTRs - Data.Global.Timing.Start), Yposition(1:length(AnalysedData.(ExperimentName).(BlockName).BurnInTRs)), 'g.'); 
        end
        
        scatter((AnalysedData.(ExperimentName).(BlockName).RestTimestamps - Data.Global.Timing.Start), Yposition(1:AnalysedData.(ExperimentName).(BlockName).RestTRs), 'k.') %Put it in the position in the list of experiments run
        
        % Store all run information here
        AnalysedData.All_BlocksPerRun{Functional_Counter}(end+1,:)={Timing_File_Struct.Name, AnalysedData.block_onset_time, BlockName}; %Add this event to the timing file
        
        %% Store information for timing files
       
        % Determine the first and secondlevel timing information
       
        % When did this block begin in secondlevel time
        Secondlevel_block_onset = AnalysedData.block_onset_time;
        
        % When did this functional run begin in secondlevel time
        if Functional_Counter>1
            %If there is more than one functional run then the elapsed time is the
            %functional length from the past blocks
            Secondlevel_run_onset=sum(AnalysedData.FunctionalLength(1:end-1));
        else
            Secondlevel_run_onset=0;
        end
        
        % By subtracting the secondlevel block onset from the run onset you get the firstlevel block onset 
        Firstlevel_block_onset = Secondlevel_block_onset - Secondlevel_run_onset;
         
        % Store additional timing file information
        Timing_File_Struct.Firstlevel_block_onset = Firstlevel_block_onset;
        Timing_File_Struct.Secondlevel_block_onset = Secondlevel_block_onset;
        Timing_File_Struct.TaskTime = AnalysedData.(ExperimentName).(BlockName).TaskTime;
        Timing_File_Struct.Include_Run = Include_Run;
        Timing_File_Struct.Include_Block = Include_Block;
        Timing_File_Struct.Include_Events = Include_Events;
        Timing_File_Struct.ExperimentName=ExperimentName;
        Timing_File_Struct.BlockName = BlockName;
        Timing_File_Struct.Motion_Exclude_Epoch = Motion_Exclude_Epoch;
        Timing_File_Struct.Functional_name = sprintf('functional%02d', Functional_Counter);
        
        % Update information about the timing count for the coming runs
        % depending on run and block inclusion
        if Include_Run==1
            
            % Store the timing file information more centrally
            % Are there any blocks stored so far and if so how many?
            if isfield(AnalysedData, 'Timing_File_Struct') && length(AnalysedData.Timing_File_Struct) >= Functional_Counter && isfield(AnalysedData.Timing_File_Struct(Functional_Counter), 'Block_1')
                stored_blocks = length(fieldnames(AnalysedData.Timing_File_Struct(Functional_Counter))) + 1;
            else
                stored_blocks = 1;
            end
            
            % Store the timing information as a list to be easily read from
            % in Run_Summary
            AnalysedData.Timing_File_Struct(Functional_Counter).(sprintf('Block_%d', stored_blocks)) = Timing_File_Struct;
            
            % What is the way to link this struct (that will be stored with
            % each block of participant data) to the list of structs to be
            % printed
            Timing_File_Struct.Struct_Block_field = sprintf('Block_%d', stored_blocks);
            
            % What blocks were included in this run?
            if Include_Block==1
                AnalysedData.Included_BlocksPerRun{Functional_Counter}(end+1,:)={Timing_File_Struct.Name, AnalysedData.block_onset_time, BlockName}; %Add this event to the timing file
            end
            
            AnalysedData.block_onset_time=AnalysedData.block_onset_time + AnalysedData.block_duration; %Increment this if the block is included
            
            % Add the TRs from this block (as well as any additional burn
            % in data)
            AnalysedData.FunctionalLength(Functional_Counter)=AnalysedData.FunctionalLength(Functional_Counter) + AnalysedData.block_duration + (AnalysedData.BurnIn_Surplus * AnalysedData.TR(Functional_Counter));
        end
        
        % Store the timing information for this block
        AnalysedData.(ExperimentName).(BlockName).Timing=Timing_File_Struct;
        
        %Store the summary to be printed
        PrintLog =[PrintLog,  sprintf('\n%d warm up, %d task, %d rest, %0.1f task time, %0.1f Elapsed time\n',length(AnalysedData.(ExperimentName).(BlockName).BurnInTRs), AnalysedData.(ExperimentName).(BlockName).TaskTRs, AnalysedData.(ExperimentName).(BlockName).RestTRs, AnalysedData.(ExperimentName).(BlockName).TaskTime, AnalysedData.block_duration)];
        
    end
    
    
    %Print the information for this block, including the experiment and
    %block name, the edits that have been made and any warnings
    
    fprintf('%s\n\n------------------------------------------------------------\n\n', PrintLog);
        
    %Store for the next iteration
    MostRecentExperiment=TempData;
    
    BlockCounter=BlockCounter+1; %Increment
    
    
end
fclose(block_fid); % Wrap up

%% Wrap up for the last block

% Explain what to do if the TR is not 2s
if TR~=default_TR
    warning('The TR is not 2s for this block but is instead %0.2f. Take the following steps:\n1. Change the TR value in analysis/firstlevel/Confounds/Epochs_design.fsf. If only one block has a different TR, this may require more surgical changes to both this fsf file and to FEAT_firstlevel.sh', TR);
end

% If there are no blocks from this run then exclude it
% after the fact
if length(AnalysedData.Included_BlocksPerRun{Functional_Counter}) == 0
    try
        % Move the file (only if it hasn't be moved
        % yet)
        if exist(sprintf('analysis/firstlevel/functional0%d_excluded_run.fsf',Functional_Counter)) == 0
            movefile(sprintf('analysis/firstlevel/functional0%d.fsf',Functional_Counter), sprintf('analysis/firstlevel/functional0%d_excluded_run.fsf',Functional_Counter));
        end
        
        % If the run is to be excluded then subtract
        % the run duration for this run from the count
        AnalysedData.block_onset_time = AnalysedData.block_onset_time - AnalysedData.FunctionalLength(Functional_Counter);
        
        % Delete the timing files for this run from
        % first level. This will leave intact the
        % timing files at second level but since
        % they are zeroed out by necessity they
        % shouldn't be used by FunctionalSplitter
        delete(sprintf('analysis/firstlevel/Timing/functional0%d_*', Functional_Counter));
        
        warning('Run %d will not be included!\nfsf file for this run has been changed to avoid running this.\nNo timing files were created at firstlevel (some timestamps may be added to second level but these should not interfere with further computation). The TRs from this run were deleted from the count, hence it will not contribute to the total time (affecting other run timing files).\n', Functional_Counter);
        
    catch
        warning('Run %d will not be included!\nfsf file was not renamed\nTiming files will not be created and this run will not contribute to the total time (affecting other run timing files).\n', Functional_Counter);
    end
    
    % Set this to zero if there are no included blocks
    Include_Run = 0;
    
else
    % fsf file labelled for removal but should be included
    if exist(sprintf('analysis/firstlevel/functional0%d_excluded_run.fsf',Functional_Counter)) > 0
        movefile(sprintf('analysis/firstlevel/functional0%d_excluded_run.fsf',Functional_Counter), sprintf('analysis/firstlevel/functional0%d.fsf',Functional_Counter));
        warning('Found analysis/firstlevel/functional0%d_excluded_run.fsf for removal, including it instead\n', Functional_Counter);
    end
end

% Store the run inclusion information
AnalysedData.Include_Run(Functional_Counter) = Include_Run;

% Divide run into a pseudo-run
if Include_Run == 1
    AnalysedData = pseudorun_divide(AnalysedData, Functional_Counter, pseudorun_criteria, Run_BurnIn_fid);
end

% Get the summary
[AnalysedData, FileIDs] = RunSummary(Func_Files, Functional_Counter, AnalysedData, AnalysedData.Run_BurnInTRNumber, FileIDs);

%Total time
AnalysedData.TotalTime=AnalysedData.block_onset_time;

%% Save data

%Save data
save('analysis/Behavioral/AnalysedData');

%Save the figure
saveas(gcf, 'analysis/Behavioral/TR_Timecourse.fig')
saveas(gcf, 'analysis/Behavioral/TR_Timecourse.png')

% Close the run burn in file
fclose(Run_BurnIn_fid);
 
% % Create the final version of the overall confounds file by 
%  fprintf('\nCombining the confound blocks with the OverallConfounds file')
%  
%  for functional_counter = 1:length(AnalysedData.FunctionalLength)
%  
%      command=sprintf('./scripts/convolve_confound_regressors.sh %02d %s', functional_counter, Confound_Dir)
%      unix(command);
%  end

fprintf('\n#############\nFINISHED\n#############');

diary off % Turn the diary function off
end

function [AnalysedData, FileIDs] = RunSummary(Func_Files, Functional_Counter, AnalysedData, BurnInTRNumber, FileIDs)
% Compare the number of TRs that were observed in a run versus how many
% were guessed


%Load in a nifti
fprintf('###########################\n*#*#*   RUN SUMMARY   *#*#*\n###########################\n\nChecking actual functional length, may take a minute ...\n')
if ismac==0
    %What is the output of fslinfo
    [~, text]=unix(['fslinfo data/nifti/', Func_Files(Functional_Counter).name]);
    
    %Pull out idxs of when this started and ended
    idx_start=min(strfind(text, 'dim4'));
    idx_end=min(strfind(text, 'datatype')) - 2;
    words=regexp(text(idx_start:idx_end),' ','split');
    
    %How many TRs are reported
    ActualTRs=str2double(words{end});
else
    
    NIFTI=load_untouch_nii(['data/nifti/',Func_Files(Functional_Counter).name]);
    
    %How many TRs in the nifti
    ActualTRs=size(NIFTI.img,4);
end

if isfield(AnalysedData, 'FunctionalLength_bkp') && length(AnalysedData.FunctionalLength_bkp) >= Functional_Counter
    Run_TRs = AnalysedData.FunctionalLength_bkp(Functional_Counter);
    pseudorun_total = (AnalysedData.FunctionalLength(Functional_Counter)/AnalysedData.TR(Functional_Counter))+BurnInTRNumber;
    fprintf('Using the TRs before pseudorun changed them. There are only %d TRs for this run that are passed on to secondlevel\n', pseudorun_total);
else
    Run_TRs = AnalysedData.FunctionalLength(Functional_Counter);
end

GuessedTRs=(Run_TRs/AnalysedData.TR(Functional_Counter))+BurnInTRNumber;

%Report the comparison
fprintf('Actual TR number: %d, guessed TR number: %d\n', ActualTRs, GuessedTRs)

if ActualTRs~=GuessedTRs
    warning('TRs do not match. If this run has already been manually excluded these numbers may be mismatched.')
end

TimecourseTRs=size(AnalysedData.Timecourse{Functional_Counter},2);

if TimecourseTRs~=GuessedTRs-BurnInTRNumber
    warning('TRs in timecourse don''t match other guessed TRs')
end

% Generate the timing information for this run
if isfield(AnalysedData, 'Timing_File_Struct') && length(AnalysedData.Timing_File_Struct) >= Functional_Counter && isfield(AnalysedData.Timing_File_Struct(Functional_Counter), 'Block_1')
    for block_counter = 1:length(fieldnames(AnalysedData.Timing_File_Struct(Functional_Counter)))

        % Pull out the timing file for this block and run it through the
        % analysis
        Timing_File_Struct = AnalysedData.Timing_File_Struct(Functional_Counter).(sprintf('Block_%d', block_counter));
        if ~isempty(Timing_File_Struct)
            [FileIDs, ~] = Timing_MakeTimingFile(Timing_File_Struct, FileIDs, AnalysedData.EyeData);
        end
    end
end

%Bracket off the event
fprintf('\n------------------------------------------------------------\n\n');


%Store actual TR number
AnalysedData.FunctionalLength_Actual(Functional_Counter)=ActualTRs;

% Store the burn in number for this 
AnalysedData.BurnInTRNumber(Functional_Counter)=BurnInTRNumber;

%Reduce memory demands
NIFTI=struct;

end
