%% Splits data into experiment specific 'runs'
%
% Takes the first level functionals aligned to the anatomical/each other
% and organizes them into experiments for second level experiment specific
% analyses.
%
% For each experiment, this creates a folder as such:
% $SUBJ_DIR/analysis/secondlevel_$EXPERIMENT/$SECONDLEVEL_NAME/
%
% where the $EXPERIMENT is the experiment name and $SECONDLEVEL_NAME is the
% suffix for this analysis you want to run (by default it is 'default')
%
% This script first sets up all the names of the files and opens up the
% confound files. It then deletes all of the contents of the folders that
% you will be adding data to: 'default/NIFTI', 'default/Timing', and
% 'default/Confounds'. Hence, DO NOT make permanent changes in these
% folders. That said, you can make other folders, such as feat folders in
% those experiment directories and they won't be affected.
%
% It then iterates through all of the block start times, as specified by
% the timing files, pulls out TRs corresponding to those blocks and their
% burn outs and then stores each block. It then concatenates these blocks
% to make a single file for an experiment. For each TR, it pulls out the
% associated line in the confound file and store these for this subject. If
% there are event files or condition files for the experiment, then it will
% also make the new timing files for these. Once all blocks have been run,
% it then will run the motion decorrelator on the OverallConfound file for
% each experiment.
%
% It can take in two inputs:
%
% 1. FirstLevelAnalysisName: What is the folder suffix in firstlevel for
% this analysis? For every type of analysis you perform at firstlevel you
% should provide a suffix to the feat folder (e.g.
% functional${XX}_${suffix}.feat). If none is provided then this will be
% thought of as default. This will then make a folder in the secondlevel
% directory for each type of analysis that has been conducted, with the
% default as 'default'. This script then looks for NIFTIs and Feats in this
% in the folder with the name that matches this variable.
%
% 2. SecondLevelAnalysisName: Defaults to the same analysis name as above
% but can be different. A different name can be used when you have
% different splitting regimes for the same data (e.g., how it is used in
% Stat Learning to balance blocks differently) so you don't need to
% duplicate the folder at secondlevel. That said, it is wasteful
% memory-wise because all other experiments will also have duplicate
% folders that may not be appropriate.
%
% You can run multiple jobs for FunctionalSplitter on the same participant
% simultaneously when the SecondLevelAnalysisName is different, otherwise
% don't.
%
% Rewritten in matlab C Ellis 2/23/17
% Substantially updated to enable block balancing Ellis 4/4/17
% Removed the NIFTI_Suffix functionality and improved defaults 08/07/17
% Updated to run on the firstlevel data instead of secondlevel 03/03/19

function FunctionalSplitter(FirstLevelAnalysisName, SecondLevelAnalysisName)

%What is the analysis name (assume none if there is none) at first level
%and for the folder in analysis/secondlevel/ 
if nargin==0
    FirstLevelAnalysisName='default';
end

% Determine what the second level analysis name is. Usually assume that it
% will be the same as the first but can be different
if nargin < 2
    SecondLevelAnalysisName = FirstLevelAnalysisName;
end

% Output analysis types
fprintf('\nUsing data from %s, putting data in %s\n\n', FirstLevelAnalysisName, SecondLevelAnalysisName);

delete(sprintf('analysis/secondlevel/FunctionalSplitter_%s_Log', SecondLevelAnalysisName)); % Delete file
diary(sprintf('analysis/secondlevel/FunctionalSplitter_%s_Log', SecondLevelAnalysisName)); %Start a log file
addpath('scripts/FunctionalSplitter_functions');

% Load the analyzed data
load('analysis/Behavioral/AnalysedData.mat', 'AnalysedData');

%Hard code some parameters
RestTRs=3; %How many TRs are typical of rest
order_chronologically=1; %Order the merged blocks in the sequence they were made
InputDir='analysis/firstlevel/'; %Where is the firstlevel data
secondlevel_dir='analysis/secondlevel/'; %Where is the secondlevel data
OutputPrefix='analysis/secondlevel_'; %Where are you storing the data
fsf_template='fsf/secondlevel.fsf.template';
Confound_file_types = {'OverallConfounds', 'MotionParameters', 'MotionConfounds'};

TimingFiles=dir([InputDir, 'Timing/*-*.txt']);

% Delete any files that might describe block order, such as is created for
% StatLearning
unix(sprintf('rm -f analysis/secondlevel*/%s/block_order.txt', SecondLevelAnalysisName));

%Load the concat files
functional_runs = {};
Concat = struct;
for TimingFileCounter=1:length(TimingFiles)
    
    %What timing file is it on this trial
    iTimingFile=TimingFiles(TimingFileCounter).name;
    
    % Pull out the run this belongs to
    functional_run = iTimingFile(1:min(strfind(iTimingFile, '_')) - 1);
    if any(strcmp(functional_runs, functional_run)) == 0
        functional_runs{end + 1} = functional_run;
        
        % Preset
        for Type = {'Block', 'Events', 'Condition'}
            for info = {'Files', 'Mat', 'Name'}
                Concat.(functional_run).(Type{1}).(info{1})={};
            end
        end
    end
    
    %Store the timing file
    if ~isempty(strfind(iTimingFile, 'Events'))
        Type='Events'; %This is a timing file for the event
    elseif ~isempty(strfind(iTimingFile, 'Condition'))
        Type='Condition'; %This is a timing file for the conditions
    else
        Type='Block'; %If it is neither then assume this is block timing
    end

    try
        temp=textread([InputDir, 'Timing/', iTimingFile]);
    catch
        fprintf('\n ERROR with timing file. Not including %s. Please check this is okay.\n',iTimingFile)
        continue
    end
    
    %Store the relevant information
    Concat.(functional_run).(Type).Files{end+1}=iTimingFile;
    Concat.(functional_run).(Type).Name{end+1}=iTimingFile(min(strfind(iTimingFile, '_')) + 1:strfind(iTimingFile, '-')-1);
    Concat.(functional_run).(Type).Mat{end+1}=textread([InputDir, 'Timing/', iTimingFile]);
end

%% Identify which blocks belong to which runs.

% Iterate through the runs, check if they are balanced
for functional_run = functional_runs
    
    functional_run = functional_run{1}; % Cleaner
    
    % What blocks are you excluding
    Excluded_Blocks=[];
    
    % Check what FunctionalSplitter functions you have. Looking for a
    % template of $EXPERIMENT_Block_Balancing.m, and will run this code on
    % any runs that have a match
    Balancing_funcs = dir('scripts/FunctionalSplitter_functions/*_Block_Balancing.m');
    
    for func_counter = 1:length(Balancing_funcs)
        
        % Pull out the func
        Balancing_func = str2func(Balancing_funcs(func_counter).name(1:end-2));
        
        % Get the expt name
        experiment = Balancing_funcs(func_counter).name(1:strfind(Balancing_funcs(func_counter).name, '_Block_Balancing.m') - 1);
        
        % Does this run contain any blocks of this experiment
        if any(strcmp(Concat.(functional_run).Block.Name, experiment))
            Concat=Balancing_func(AnalysedData, Concat, functional_run, SecondLevelAnalysisName);
        end
    end
        
    % Quantify the block number for this run
    total_blocks = 0;
    for file_counter = 1:length(Concat.(functional_run).Block.Mat)
        total_blocks = total_blocks + size(Concat.(functional_run).Block.Mat{file_counter}, 1);
    end
    
    % If there are no blocks left after this then skip the run
    if total_blocks == 0
        fprintf('\nIgnoring %s because there are no blocks\n\n', functional_run);
        
        % Remove the trace of this run
        Concat = rmfield(Concat, functional_run);
        functional_runs = setdiff(functional_runs, functional_run);
    end
end



%% Summarise which experiments are usable and how many blocks there are

% Count the number of blocks that have been stored in the concatenated list
ExperimentList={};
for functional_run = functional_runs
    for block_type_counter = 1:length(Concat.(functional_run{1}).Block.Mat)
        
        % Pull out the experiment name
        ExperimentName = Concat.(functional_run{1}).Block.Name{block_type_counter};
        
        % How many blocks are included?
        number_included_blocks = sum(Concat.(functional_run{1}).Block.Mat{block_type_counter}(:,3));
        
        %Is this name in the list, if so add it to the list otherwise count
        %this block
        if isempty(ExperimentList)
            idx=[];
        else
            idx=find(not(cellfun('isempty', strfind(ExperimentList(:,1), ExperimentName))));
        end
        
        %Either create this cell or add to it
        if isempty(idx)
            ExperimentList(end+1,:)={ExperimentName, number_included_blocks};
        else
            ExperimentList{idx,2}=ExperimentList{idx,2}+number_included_blocks;
        end
    end
end
ExperimentList_bkp = ExperimentList; % Make a copy before you add extras

% Add experiment list items that aren't run during functionals but nonetheless you
% care about.
% To do this make a function called $EXPERIMENT_quantify_blocks.m

quantify_funcs = dir('scripts/FunctionalSplitter_functions/*_quantify_blocks.m');
for func_counter = 1:length(quantify_funcs)
    
    % Pull out the func
    quantify_func = str2func(quantify_funcs(func_counter).name(1:end-2));
    
    % What is the experiment name
    experiment = quantify_funcs(func_counter).name(1:strfind(quantify_funcs(func_counter).name, '_quantify_blocks.m') - 1);
    
    if isfield(AnalysedData, sprintf('Experiment_%s', experiment))
        ExperimentList = quantify_func(AnalysedData, ExperimentList);
    end
end

%If an experiment has been run but gets excluded then add this to the list
%too.
fields=fieldnames(AnalysedData);

for fieldcounter=1:length(fields)
    
    % Is this an Experiment field (ignore PlayVideo)
    if ~isempty(strfind(fields{fieldcounter}, 'Experiment_')) && ~strcmp(fields{fieldcounter}, 'Experiment_PlayVideo')
        
        ExperimentName=fields{fieldcounter}(length('Experiment_')+1:end);
        
        NotIncluded=0;
        for ExperimentCounter=1:size(ExperimentList,1)
            
            %If this experiment isn't in the list then add it here
            if strcmp(ExperimentList{ExperimentCounter,1}, ExperimentName)
                NotIncluded=1;
            end
        end
        
        %If you couldn't find a match then add it to the list
        if NotIncluded==0
            ExperimentList(end+1,:)={ExperimentName, 0};
        end
        
    end
end

% Find the total number of blocks that make it through and print the
% results
fprintf('\n#################\nBlocks used / Blocks started:\n\n');
for ExperimentCounter=1:size(ExperimentList,1)
    
    TotalBlocks=length(fieldnames((AnalysedData.(['Experiment_', ExperimentList{ExperimentCounter,1}]))));
    
    %Is it an integer or a proportion?
    if mod(ExperimentList{ExperimentCounter,2},1)==0
        fprintf('%s: %d / %d\n', ExperimentList{ExperimentCounter,1}, ExperimentList{ExperimentCounter,2}, TotalBlocks);
    else
        fprintf('%s: %0.2f / %d\n', ExperimentList{ExperimentCounter,1}, ExperimentList{ExperimentCounter,2}, TotalBlocks);
    end
end
fprintf('#################\n');


%Report the inputs
fprintf('\n########################################\n\nLooking for the files in %s of the secondlevel folder\n\n', SecondLevelAnalysisName);

% First, check if this secondlevel analysis folder exists, or if maybe this wasn't created for some reason; exit if so
secondlevel_analysis_folder=[secondlevel_dir,FirstLevelAnalysisName];

if ~exist(secondlevel_analysis_folder)
	fprintf('WARNING: The secondlevel analysis folder %s does not exist. Check that you gave the right inputs to this script and/or that Post-Prestats.sh has been run properly. Aborting.\n\n',FirstLevelAnalysisName)
	return
end



%Remove all the files in the folders you have created with these parameters
try
    Directory=dir([OutputPrefix,'*']);
    for DirectoryCounter=1:length(Directory)
        
        %Where are the files stored
        Folder=['analysis/', Directory(DirectoryCounter).name, '/', SecondLevelAnalysisName];
        
        %Remove the nifti files
        Files=dir([Folder, '/NIFTI/']);
        for FileCounter=3:length(Files);
            delete([Folder, '/NIFTI/', Files(FileCounter).name]);
        end
        
        %Remove the timing files
        Files=dir([Folder, '/Timing']);
        for FileCounter=3:length(Files);
            delete([Folder, '/Timing/', Files(FileCounter).name]);
        end
        
        %Remove the timing files
        Files=dir([Folder, '/Confounds']);
        for FileCounter=3:length(Files);
            delete([Folder, '/Confounds/', Files(FileCounter).name]);
        end
        
    end
catch
end

% Make the file structure for the experiments run here
for Experiment = ExperimentList_bkp(:, 1)'
    
    %Make the necessary directories (and ignore warnings)
    warning_state=warning; %Take the default warning set up
    warning('off','all'); %disable warnings
    mkdir([OutputPrefix, Experiment{1}])
    Experiment_Dir=[OutputPrefix, Experiment{1}, '/', SecondLevelAnalysisName];
    mkdir(Experiment_Dir);
    mkdir([Experiment_Dir, '/NIFTI/']);
    mkdir([Experiment_Dir, '/Timing/']);
    mkdir([Experiment_Dir, '/Confounds/']);
    warning(warning_state); %Set back to default
    
    %If the fsf file doesn't exist then make it here.
    try
        copyfile(fsf_template, [Experiment_Dir, '/design.fsf']);
    catch
    end
end

%% Iterate through the runs (or pseudoruns) that have timing files associated to them
%Preset
TR_Counter_Only=struct;
TR_Counter_Event=struct;
TR_Counter_Condition=struct;
FileIDs=struct;
Experiment_Dirs={}; %What are the directories that have been created

for functional_run = functional_runs
    
    % Clean up 
    functional_run = functional_run{1};
    
    fprintf('\n########################################\n\nPulling out blocks from %s\n\n########################################\n\n', functional_run);
    
    % What is the path to the aligned data
    if strcmp(FirstLevelAnalysisName, 'default')
        aligned_folder = sprintf('%s/%s.feat/aligned_highres/', InputDir, functional_run);
    else
        aligned_folder = sprintf('%s/%s_%s.feat/aligned_highres/', InputDir, functional_run, FirstLevelAnalysisName);
    end

    
    Functional_Name=sprintf('%s/func2highres_unmasked.nii.gz', aligned_folder);
    
    %What is the TR for the Functional you have selected?
    [~, text]=unix(sprintf('fslval %s pixdim4', Functional_Name));
    TR=str2double(text);

    % if the TR is in milliseconds (greater than 1000) make sure to change
    % it to seconds
    if TR > 1000
        TR =TR/1000;
    end
    
    % How many TRs are there for this run
    [~, text]=unix(sprintf('fslval %s dim4', Functional_Name));
    TR_num=str2double(text);
    
    %Read in the confound data
    Confounds = struct;
    for file_type = Confound_file_types
        if strcmp(file_type{1}, 'MotionParameters')
            confound_file = sprintf('%s/Confounds/%s_%s.par', InputDir, file_type{1}, functional_run);
        else
            confound_file = sprintf('%s/Confounds/%s_%s.txt', InputDir, file_type{1}, functional_run);
        end
        
        % Either dummy code or pull out the data
        if exist(confound_file) == 0
            Confounds.(file_type{1})=[];
        else
            Confounds.(file_type{1})=textread(confound_file);
        end
        
    end
    
    %% Take the timing information from each run and put it in to a single ordered list so that you don't disrupt the real order
    
    %Order all of the blocks chronologically (events within the blocks),
    %allowing you to then rearrange how the blocks are merged.

    %Make a list of the onset times of all events for the block
    onsets=[];
    run_concat = Concat.(functional_run);
    for TimingFileCounter=1:length(run_concat.Block.Mat)
        temp=run_concat.Block.Mat{TimingFileCounter}(:,1);
        onsets(end+1:end+length(temp),:)=[temp, repmat(TimingFileCounter, [length(temp),1]), (1:length(temp))'];
    end

    % Do you want the data to be merged chronologically or to be ordered
    % blockwise
    if order_chronologically==1
        [~, order]=sort(onsets(:,1)); %What is the order of the onsets
        onsets=onsets(order,:); %Reorder the onsets
    end

    %Pull out just the indexes identifying the timing file and the event in the
    %timing file.
    OrderedBlocks=onsets(:,2:3);
    RunTRs = struct;
    for OrderedBlocksCounter=1:size(OrderedBlocks,1)
        
        %What is the timing file and the event in the timing file of this block
        %to be pulled out.
        TimingFileCounter=OrderedBlocks(OrderedBlocksCounter,1);
        RowCounter=OrderedBlocks(OrderedBlocksCounter,2);
        
        %Pull out the information
        Filename=run_concat.Block.Files{TimingFileCounter};
        Experiment= run_concat.Block.Name{TimingFileCounter};
        firstlevel_timing=run_concat.Block.Mat{TimingFileCounter}(RowCounter,:); %What are the onset, duration and weights
        
        Experiment_Dir=[OutputPrefix, Experiment, '/', SecondLevelAnalysisName];
        
        % Determine if the block is included
        if firstlevel_timing(3) ~= 0
            
            %What is the filename?
            fprintf('\n-------------------------\nLoading %s\n', Filename);
            
            %What is the name of the block
            BlockName=Filename(strfind(Filename, '-')+1:end-4);
            
            %What would the event file name be?
            Filename_Events=[Filename(1:end-4), '_Events.txt'];
            
            %Check if there are any event files by this name
            Event_Idxs=find(strcmp(run_concat.Events.Files, Filename_Events)>0);
            isEvents=~isempty(Event_Idxs);
            
            %What would the condition file name be?
            Filename_Condition=[Filename(1:strfind(Filename, '-')), 'Condition'];
            
            %Check if there are any condition files by this name
            Condition_Idxs=find(~cellfun(@isempty, strfind(run_concat.Condition.Files, Filename_Condition))>0);
            isCondition=~isempty(Condition_Idxs);
            
            %If this field doesn't exist yet then create it
            if ~isfield(TR_Counter_Event, Experiment)
                TR_Counter_Event.(Experiment)=0;
            end
            
            %If this field doesn't exist yet then create it
            if ~isfield(TR_Counter_Condition, Experiment)
                TR_Counter_Condition.(Experiment)=0;
            end
            
            %What are the TRs of this block?
            FirstTR=firstlevel_timing(1)/TR;
            LastTR=FirstTR + (firstlevel_timing(2)/TR) + RestTRs;
            
            if mod(FirstTR,1)>0
                warning('FirstTR idx is not an integer, rounding');
                FirstTR=round(FirstTR);
            end
            
            % Bound the last TR so that it cannot be past the start of another
            % block (because there is no burn out) or after the max run
            % duration
            if size(OrderedBlocks, 1) > OrderedBlocksCounter % Are there blocks left
                
                % Cycle through the files and check for any onsets that are within
                % the onset and offset of this block (including for blocks that
                % aren't included).
                for temp_file_counter = 1:length(run_concat.Block.Mat)
                    idxs = find((run_concat.Block.Mat{temp_file_counter}(:,1) / TR) < LastTR & (run_concat.Block.Mat{temp_file_counter}(:,1) / TR) > FirstTR);
                    
                    % Are there any matches of this bounding?
                    if length(idxs) > 0
                        fprintf('Expected Last TR bleeds in to %s block %d, probably because there was less than %d TRs of burn out\n\n', run_concat.Block.Files{temp_file_counter}, idxs(1), RestTRs);
                        LastTR = (run_concat.Block.Mat{temp_file_counter}(idxs(1), 1) / TR);
                    end
                end
                
            else
                
                if LastTR > TR_num
                    fprintf('Expected Last TR exceeds total TRs, probably because there was less than %d TRs of burn out\n\n', RestTRs);
                    LastTR = TR_num;
                end
            end
            
            if mod(LastTR,1)>0
                warning('LastTR idx is not an integer, rounding');
                LastTR=round(LastTR);
            end
            
            
            %Set if it hasn't been yet
            if ~isfield(RunTRs, Experiment)
                RunTRs.(Experiment)=[];
            end
            
            %Add this block to the list
            RunTRs.(Experiment)(end+1:end+length(FirstTR+1:LastTR)) = FirstTR+1:LastTR;
            
            %Print TRs used
            fprintf('Analyzing TR %d to %d\n', FirstTR, LastTR);
            
            % Check if there are any extra TRs that are being ignored (assume
            % that it wouldn't be more than 6s between block onsets (longer
            % might mean there was a block in between that was quit out of))
            if size(OrderedBlocks, 1) > OrderedBlocksCounter
                
                %Pull out the information for the next block
                next_onset=run_concat.Block.Mat{OrderedBlocks(OrderedBlocksCounter + 1,1)}(OrderedBlocks(OrderedBlocksCounter + 1,2),1) / TR;
                
                % When the last TR is not the same as the next blocks onset,
                % but is within the next 6s, assume this is because of slop in
                % the timing between blocks
                if next_onset ~= LastTR && next_onset < LastTR + 6
                    warning('There is %0.1f extra TRs between this block and the next', next_onset - LastTR)
                end
                
            end
            fprintf('-------------------------\n\n');
            
            %% Create the motion parameter files for each block
            % Read through the feat folders and take out the confounds for
            % a given TR then store it to be passed on to the experiment specific
            % analyses
            
            for Confound_file = Confound_file_types
                
                
                block_file_name=sprintf('%s/Confounds/%s_%s_block_%d.txt', Experiment_Dir, Confound_file{1}, functional_run, OrderedBlocksCounter);
                all_filename=sprintf('%s/Confounds/%s.txt', Experiment_Dir, Confound_file{1});
                
                %Set up the files
                fid=fopen(block_file_name, 'a');
                
                %Print one line at a time
                for TRIdx = FirstTR+1:LastTR
                    
                    fprintf(fid, sprintf('%s\n', sprintf('%0.6f ', Confounds.(Confound_file{1})(TRIdx, :)')));
                end
                
                % Now append this new block file to the ones already created
                % (but don't do it for OverallConfounds, since you can neither
                % extend nor append)
                if strcmp(Confound_file{1}, 'MotionParameters')
                    % Append to the preexisting columns
                    append_regressor_file(block_file_name, all_filename, '0');
                elseif strcmp(Confound_file{1}, 'MotionConfounds')
                    % Extend the preexisting columns
                    append_regressor_file(block_file_name, all_filename, '1');
                end
                
            end
            
            %% Create the volumes
            
            %Where will these volumes be stored
            SaveName_Block=sprintf('%s/NIFTI/func2highres_%s-%s_%s_block_%d.nii.gz', Experiment_Dir, Experiment, BlockName, functional_run, OrderedBlocksCounter);
            SaveName_Experiment=sprintf('%s/NIFTI/func2highres_%s_unmasked.nii.gz', Experiment_Dir, Experiment);
            SaveName_run=sprintf('%s/NIFTI/func2highres_%s_%s.nii.gz', Experiment_Dir, Experiment, functional_run);
            SaveName_Z_run=sprintf('%s/NIFTI/func2highres_%s_%s_Z.nii.gz', Experiment_Dir, Experiment, functional_run);
            SaveName_Z=sprintf('%s/NIFTI/func2highres_%s_Z.nii.gz', Experiment_Dir, Experiment);
            
            %Use fslroi to parse the voxels into blocks
            unix(sprintf('fslroi %s %s %d %d', Functional_Name, SaveName_Block, FirstTR, LastTR - FirstTR));
            
            % If this is the first block of this Experiment then use this file just
            % made as a base
            if ~isfield(TR_Counter_Only, Experiment)
                copyfile(SaveName_Block, SaveName_Experiment);
                
                %When did this experiment start? Set counter to zero
                StartTime.(Experiment)=firstlevel_timing(1);
                TR_Counter_Only.(Experiment)=0;
                Experiment_Dirs{end+1}=Experiment_Dir;
            else
                %If it is not the first of the experiment then simply
                %merge it
                unix(sprintf('fslmerge -t  %s %s %s', SaveName_Experiment, SaveName_Experiment, SaveName_Block));
            end
            
            % If this is the first block of the run then just duplicate the
            % files, otherwise append
            if exist(SaveName_run) == 0
                copyfile(SaveName_Block, SaveName_run);
            else
                unix(sprintf('fslmerge -t  %s %s %s', SaveName_run, SaveName_run, SaveName_Block));
            end
           
        else
            fprintf('Block %d of %s is being skipped because the weight is zero\n\n', OrderedBlocksCounter, functional_run);
        end
        
        
        % If this is the last block of the run (and there are some blocks that are included) then z score it
        if OrderedBlocksCounter == size(OrderedBlocks,1)  && length(fieldnames(RunTRs)) > 0
            
            fprintf('Z scoring for %s\n\n', functional_run);
            
            % Z score over the concatenated blocks for this run
            Excluded_TRs=find(sum(Confounds.MotionConfounds(RunTRs.(Experiment), :),2)==1);
            
            z_score_exclude(SaveName_run, SaveName_Z_run, Excluded_TRs);
            
            % Concatenate this z scored volume with the one that
            % exists (if it exists)
            
            if exist(SaveName_Z)~=0
                unix(sprintf('fslmerge -t %s %s %s', SaveName_Z, SaveName_Z, SaveName_Z_run));
                fprintf('\nAdding z scored run to %s\n\n', SaveName_Z);
            else
                copyfile(SaveName_Z_run, SaveName_Z);
                fprintf('\nCreating z scored run %s\n\n', SaveName_Z);
            end
        end
        
        % Create the timing file (if this block is included
        if firstlevel_timing(3) ~= 0
            
            %% Create timing file
            
            %What is the timing file name
            TimingFile_Only=sprintf('%s/Timing/%s-%s_Only.txt',Experiment_Dir, Experiment, BlockName);
            
            %What is the information for the timing file
            secondlevel_onset=TR_Counter_Only.(Experiment)*TR;
            Duration=firstlevel_timing(2);
            Weight=firstlevel_timing(3);
            
            FileID=[Experiment, '_', BlockName];
            
            %Has the file been created
            if isempty(strcmp(fieldnames(FileIDs),FileID)) || all(strcmp(fieldnames(FileIDs), FileID)==0)
                FileIDs.(FileID)=fopen(TimingFile_Only, 'w');
            end
            
            %Write these values to the file
            fprintf(FileIDs.(FileID), '%0.3f\t%0.3f\t%0.3f\n', secondlevel_onset, Duration, Weight);
            
            %Add the duration of this block
            TR_Counter_Only.(Experiment)= TR_Counter_Only.(Experiment) + LastTR - FirstTR;
            
            % Make event timing files
            if isEvents
                
                %Go through the files with the appropriate event names
                for EventTypeCounter=1:length(Event_Idxs)
                    
                    %Pull out the timing file
                    Mat_Events=run_concat.Events.Mat{Event_Idxs(EventTypeCounter)};
                    
                    %What is the save name (remove the 'functional' prefix
                    temp_Filename_Events = Filename_Events(min(strfind(Filename_Events, '_') + 1):end);
                    TimingFile_Events=sprintf('%s/Timing/%s',Experiment_Dir, temp_Filename_Events);
                    
                    %Identify which events are done in this block
                    BlockEvents=intersect(find(Mat_Events(:,1)>=(FirstTR*TR)), find(Mat_Events(:,1)<(LastTR*TR)));
                    
                    %Iterate through the events
                    EventCounter=1;
                    while EventCounter<=length(BlockEvents)
                        
                        %When did this event start in experiment time? Find it by
                        %taking the event time since the start of block and adding
                        %it to the block start time in experiment time
                        OnsetTime_Event=(Mat_Events(BlockEvents(EventCounter),1) - firstlevel_timing(1)) + secondlevel_onset;
                        
                        Duration=Mat_Events(BlockEvents(EventCounter),2);
                        Weight=Mat_Events(BlockEvents(EventCounter),3);
                        
                        %Write the data
                        FileID=[Experiment, '_', BlockName, '_Events'];
                        
                        %Has the file been created
                        if isempty(strcmp(fieldnames(FileIDs),FileID)) || all(strcmp(fieldnames(FileIDs), FileID)==0)
                            FileIDs.(FileID)=fopen(TimingFile_Events, 'w');
                        end
                        
                        %Write these values to the file
                        fprintf(FileIDs.(FileID), '%0.3f\t%0.3f\t%0.3f\n', OnsetTime_Event, Duration, Weight);
                        
                        EventCounter=EventCounter+1;
                    end
                end
            end
            
            
            % Like above, make Condition timing files
            if isCondition
                
                %Go through the files with the appropriate event names
                for ConditionCounter=1:length(Condition_Idxs)
                    
                    %Pull out the timing file
                    Mat_Condition=run_concat.Condition.Mat{Condition_Idxs(ConditionCounter)};
                    
                    %What is the save name (remove the functional prefix)
                    Filename_Condition = run_concat.Condition.Files{Condition_Idxs(ConditionCounter)};
                    temp_Filename_Condition = Filename_Condition(min(strfind(Filename_Condition, '_') + 1):end);
                    TimingFile_Condition=sprintf('%s/Timing/%s',Experiment_Dir, temp_Filename_Condition);
                    
                    %Identify which events are done in this block
                    BlockEvents=intersect(find(Mat_Condition(:,1)>=(FirstTR*TR)), find(Mat_Condition(:,1)<(LastTR*TR)));
                    
                    %Iterate through the events (only those for this block, or
                    %else your timing files will be disrupted
                    EventCounter=1;
                    while EventCounter<=length(BlockEvents)
                        
                        %When did this event start in experiment time? Find it by
                        %taking the event time since the start of block and adding
                        %it to the block start time in experiment time
                        OnsetTime_Event=(Mat_Condition(BlockEvents(EventCounter),1) - firstlevel_timing(1)) + secondlevel_onset;
                        
                        Duration=Mat_Condition(BlockEvents(EventCounter),2);
                        Weight=Mat_Condition(BlockEvents(EventCounter),3);
                        
                        %Write the data
                        %FileID=[Experiment, '_Condition_', num2str(ConditionCounter)];
                        
                        %Use the condition name rather than the counter in case the files get out
                        %of order in separate runs 
                        Condition_Name=temp_Filename_Condition(max(strfind(temp_Filename_Condition,'Condition')+10):end-4);
                        FileID=[Experiment, '_Condition_', Condition_Name];
                        
                        %Has the file been created
                        if isempty(strcmp(fieldnames(FileIDs),FileID)) || all(strcmp(fieldnames(FileIDs), FileID)==0)
                            FileIDs.(FileID)=fopen(TimingFile_Condition, 'w');
                        end
                        
                        %Write these values to the file
                        fprintf(FileIDs.(FileID), '%0.3f\t%0.3f\t%0.3f\n', OnsetTime_Event, Duration, Weight);
                        
                        EventCounter=EventCounter+1;
                    end
                end
            end
        end    
    end
    
end

% Perform analyses on each experiment
for Experiment_Counter=1:length(Experiment_Dirs)
    
    % Find the experiment name
    start_idx=strfind(Experiment_Dirs{Experiment_Counter}, 'secondlevel') + 12;
    end_idx=strfind(Experiment_Dirs{Experiment_Counter}(start_idx:end), '/') + start_idx - 2;
    
    if isempty(end_idx)
        end_idx=length(Experiment_Dirs{Experiment_Counter});
    end
    
    ExperimentName=Experiment_Dirs{Experiment_Counter}(start_idx:end_idx);
    
    % Mask the functionals with experiment specific masks
    Mask=sprintf('%s/%s/mask_%s.nii.gz', secondlevel_dir, FirstLevelAnalysisName, ExperimentName);
    
    InputName=sprintf('%s/NIFTI/func2highres_%s_unmasked.nii.gz', Experiment_Dirs{Experiment_Counter}, ExperimentName);
    OutputName=sprintf('%s/NIFTI/func2highres_%s_Only.nii.gz', Experiment_Dirs{Experiment_Counter}, ExperimentName);
    unix(sprintf('fslmaths %s -mas %s %s', InputName, Mask, OutputName));
    fprintf('Making %s\n', OutputName);
    
    OutputName=sprintf('%s/NIFTI/func2highres_%s_Z.nii.gz', Experiment_Dirs{Experiment_Counter}, ExperimentName);
    unix(sprintf('fslmaths %s -mas %s %s', OutputName, Mask, OutputName));
    fprintf('Making %s\n', OutputName);
    
    % Load in the motion parameters and confounds 
    MotionParameters=dlmread(sprintf('%s/Confounds/MotionParameters.txt', Experiment_Dirs{Experiment_Counter}));
    MotionConfounds=dlmread(sprintf('%s/Confounds/MotionConfounds.txt', Experiment_Dirs{Experiment_Counter}));
    
    % Get the file names you want to create
    InputName=sprintf('%s/Confounds/OverallConfounds_original.txt', Experiment_Dirs{Experiment_Counter});
    OutputName=sprintf('%s/Confounds/OverallConfounds.txt', Experiment_Dirs{Experiment_Counter});
    
    % Combine the columns of the motion parameters and confounds and save
    OverallConfounds=[MotionParameters, MotionConfounds];
    dlmwrite(InputName, OverallConfounds);
    
    %Decorrelate the files
    motion_decorrelator(InputName, OutputName);
end

%Close the file to prevent accessing issues
fclose('all');

%delete Temp/
diary off % Turn the diary function off

fprintf('\nFinished\n');
