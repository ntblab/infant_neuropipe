% Identify blocks to be excluded in order to balance StatLearning
%
%Exclude blocks as pairs. So if the first block of one condition is
%excluded then exclude the first block of the other. This will mean
%that design is always counterbalanced. However, this doesn't necessarily
%mean that the nth block for one condition is the nth for the other. The
%switch `is_seen_counterbalanced` deals with this
%
% Critically StatLearning should have been run sequentially in order to preserve
% condition exposure. For instance, if we abort before a pair is completed,
% we shouldnt re run the first item of that pair since that will mean that
% there are more exposures to that block. In this case you would start with
% the second item of the pair, even though it can't be used.
%
function Concat=StatLearning_Block_Balancing(varargin)

AnalysedData = varargin{1}; % Output of Analysis_Timing
Concat = varargin{2}; % Structure containing block and timing information for all runs
functional_run = varargin{3}; % What run is this (full name, including pseudoruns)
SecondLevelAnalysisName = varargin{4}; % What subdirectory is this data stored in

% How do you want to do counterbalancing? There are 4 conditions:
counterbalancing_types = {'Counterbalance by pairing the chronological blocks', ...
    'Counterbalance by pairing the seen blocks (so that they have seen each condition equivalent numbers of times)', ...
    'Counterbalance within run and use pairs that minimize the difference in seen conditions', ...
    'Don''t counterbalance, take everything that is usable'};

% Use the FirstLevelAnalysisName to determine the counterbalancing
% condition
if strcmp(SecondLevelAnalysisName, 'default')
    counterbalancing_condition = 3; % Default to 3
elseif strcmp(SecondLevelAnalysisName, 'adjacent_pairs')
    counterbalancing_condition = 1;
elseif strcmp(SecondLevelAnalysisName, 'seen_pairs')
    counterbalancing_condition = 2;
elseif strcmp(SecondLevelAnalysisName, 'seen_count')
    counterbalancing_condition = 3;
    elseif strcmp(SecondLevelAnalysisName, 'all_blocks')
    counterbalancing_condition = 4;
else
    warning('Firstlevel name doesn''t match, using the default counterbalaning procedure');
    counterbalancing_condition = 3;
end    
   
fprintf('Counterbalancing condition:\n%s\n\n', counterbalancing_types{counterbalancing_condition});

% Make this directory if it doesn't exist
if exist(['analysis/secondlevel_StatLearning/', SecondLevelAnalysisName]) == 0
    mkdir('analysis/secondlevel_StatLearning/');
    mkdir(['analysis/secondlevel_StatLearning/', SecondLevelAnalysisName]);
end

experiment = 'StatLearning';
expected_block_duration=36; % How long should a block take in seconds

block_order_file = sprintf('analysis/secondlevel_StatLearning/%s/block_order.txt', SecondLevelAnalysisName);

% Find all timing files in this run that match this experiment
Idxs_StatLearning=strcmp(Concat.(functional_run).Block.Name, experiment);

% Were there any StatLearning blocks found?
if ~isempty(Idxs_StatLearning)
    
    fprintf('Finding pairs of blocks for StatLearning:\n')
    
    % Cycle through the blocks of this run and check that the paired
    % block is also run
    Included_idxs=[]; %Which idxs are included?
    Remaining_blocks=1:12; % Preset, this will be changed
    Block_numbers = [];
    BlockNames = {};
    ConditionNames = {};
    File_idx = [];
    Onset_idx = [];
    Onsets = [];
    is_structured = [];
    nth_seen_all = [];
    
    % Open a text file for keeping track of what blocks are included
    fid = fopen(block_order_file, 'a');
    for Idx_Counter=1:length(Idxs_StatLearning)
        
        for onset_counter = 1:size(Concat.(functional_run).Block.Mat{Idx_Counter}, 1)
            % Pull out the onset of this event
            onset = Concat.(functional_run).Block.Mat{Idx_Counter}(onset_counter, 1);
            included = Concat.(functional_run).Block.Mat{Idx_Counter}(onset_counter, 3);
            
            % Find the corresponding onset in the timing struct to learn what
            % the block is (hacky, but seems like the easiest way)
            
            for run_counter = 1:length(AnalysedData.Timing_File_Struct)
                blocks = fieldnames(AnalysedData.Timing_File_Struct(run_counter));
                for block = blocks'
                    % Check that this block has a timing file made
                    if ~isempty(AnalysedData.Timing_File_Struct(run_counter).(block{1}))
                        
                        % Was it this run
                        if strcmp(AnalysedData.Timing_File_Struct(run_counter).(block{1}).Functional_name, functional_run)
                            % Was it this experiment
                            if ~isempty(strfind(AnalysedData.Timing_File_Struct(run_counter).(block{1}).ExperimentName, experiment))
                                % Was it this onset time
                                if AnalysedData.Timing_File_Struct(run_counter).(block{1}).Firstlevel_block_onset == onset
                                    BlockName = AnalysedData.Timing_File_Struct(run_counter).(block{1}).BlockName;
                                    ConditionName = AnalysedData.Timing_File_Struct(run_counter).(block{1}).Name;
                                end
                            end
                        end
                    end
                end
            end
            
            % Only append if this block is to be included
            if included == 1
                % What block number is this?
                Block_number=str2num(BlockName(min(strfind(BlockName, '_'))+1:max(strfind(BlockName, '_'))-1));
                
                % Append to the list
                Block_numbers(end+1) = Block_number;
                BlockNames{end+1} = BlockName;
                ConditionNames{end+1} = ConditionName;
                is_structured(end+1) = ~isempty(strfind(ConditionName, 'Structured'));
                File_idx(end+1) = Idx_Counter;
                Onset_idx(end+1) = onset_counter;
                Onsets(end+1) = onset;
                
                % Figure out what block number this in terms of what they
                % have seen for each condition
                block_start = AnalysedData.Experiment_StatLearning.(BlockName).TRs(1);
                condition = AnalysedData.Experiment_StatLearning.(BlockName).Timing.Name;
                nth_seen = 1; % Initialize at 1
                for temp_BlockName = fieldnames(AnalysedData.Experiment_StatLearning)'
                    
                    % If it is less than this block start then consider it
                    if isfield(AnalysedData.Experiment_StatLearning.(temp_BlockName{1}), 'TRs') && AnalysedData.Experiment_StatLearning.(temp_BlockName{1}).TRs(1) < block_start
                        
                        % What condition is it
                        temp_condition = AnalysedData.Experiment_StatLearning.(temp_BlockName{1}).Timing.Name;
                        
                        %  Was this block seen for the majority of the
                        %  time? Was it the same condition? Take account of quit blocks too
                        Prop_excluded = AnalysedData.Experiment_StatLearning.(temp_BlockName{1}).Proportion_EyeTracking_Excluded;
                        block_duration = AnalysedData.Experiment_StatLearning.(temp_BlockName{1}).Duration;
                        if Prop_excluded < 0.5 && strcmp(condition, temp_condition) && ((1 - Prop_excluded) * block_duration) > (expected_block_duration / 2)
                            nth_seen = nth_seen + 1;
                        end
                    end
                    
                end
                
                nth_seen_all(end+1) = nth_seen;
            end
        end
    end
    
    % Cycle through the block numbers that were identified
    for block_counter = 1:length(Block_numbers)
        
        % What is the block number
        Block_number = Block_numbers(block_counter);
        
        %Is it odd? Only odd numbers are treated as the reference
        if mod(Block_number,2)==1 || counterbalancing_condition == 4
            
            if counterbalancing_condition == 1
                % Counterbalance based on chronological block number
                
                % Simply check that the next block is here
                Paired_Idx=max(find(Block_numbers==Block_number + 1));
                
            elseif counterbalancing_condition == 2
                % Counterbalance based on what blocks participants saw
                
                % What seen block number is this?
                ref_nth_seen = nth_seen_all(block_counter);
                ref_condition = is_structured(block_counter);
                
                % Find the pair if it exists (same one seen but different
                % condition
                Paired_Idx = find((nth_seen_all == ref_nth_seen) .* (is_structured ~= ref_condition));
                
            elseif counterbalancing_condition == 3
                % Take a balanced set within run and when possible pair the
                % participants
                 
                % What seen block number is this?
                ref_nth_seen = nth_seen_all(block_counter);
                ref_condition = is_structured(block_counter);
                
                % Make all the items from this condition the infinte nth seen so they won't be picked
                nth_seen_temp = nth_seen_all;
                nth_seen_temp(is_structured == ref_condition) = inf; 
                
                % Find the blocks for the other condition that are closest
                % in terms of a seen match
                if any(nth_seen_temp ~= inf)
                    [~, Paired_Idx] = min(abs(nth_seen_temp - ref_nth_seen)); 
                else
                    Paired_Idx = [];
                end
                
            end
            
            if counterbalancing_condition ~= 4 && ~isempty(Paired_Idx)
                
                % What block are you using as the reference
                Paired_block = Block_numbers(Paired_Idx);
                
                %Have these numbers been used
                if ~isempty(find(Remaining_blocks==Block_number)) && ~isempty(find(Remaining_blocks==Paired_block))
                    
                    % Store the idxs
                    Included_idxs(end+1:end+2)=[block_counter, Paired_Idx];
                    Remaining_blocks=setdiff(Remaining_blocks, [Block_number, Paired_block]);
                    
                    fprintf('Using %s (%s) and %s (%s) as a block pair.\n', BlockNames{block_counter}, ConditionNames{block_counter}, BlockNames{Paired_Idx}, ConditionNames{Paired_Idx});
                    
                    % Print the summary of block info to a block order file
                    % that can be used
                    fprintf(fid, '%s %s %s (%d): %d\n', functional_run, BlockNames{block_counter}, ConditionNames{block_counter}, nth_seen_all(block_counter), Onsets(block_counter)); 
                    fprintf(fid, '%s %s %s (%d): %d\n', functional_run, BlockNames{Paired_Idx}, ConditionNames{Paired_Idx}, nth_seen_all(Paired_Idx), Onsets(Paired_Idx)); 
                    
                    if counterbalancing_condition == 3
                        nth_seen_all(Paired_Idx) = inf; % So that this block won't be used again as a reference
                    end
                end
            elseif counterbalancing_condition == 4
                
                % If this is the all blocks condition then just append each participant at a time
                Included_idxs(end+1)=block_counter;
                Remaining_blocks=setdiff(Remaining_blocks, Block_number);
                
                fprintf('Using %s (%s).\n', BlockNames{block_counter}, ConditionNames{block_counter});
                
                % Print the summary of block info to a block order file
                % that can be used
                fprintf(fid, '%s %s %s (%d): %d\n', functional_run, BlockNames{block_counter}, ConditionNames{block_counter}, nth_seen_all(block_counter), Onsets(block_counter));
                
                
            end
        end
    end
    
    % Go through the mat data and keep only the rows that are included
    for Idx_Counter=1:length(Idxs_StatLearning)
        
        % What entries in the list of included indexes are both included
        % and part of this timing file
        useable_idxs = intersect(find(File_idx == Idx_Counter), Included_idxs);
        
        % Take the onsets that are useable and resave them
        Concat.(functional_run).Block.Mat{Idx_Counter} = Concat.(functional_run).Block.Mat{Idx_Counter}(Onset_idx(useable_idxs), :);
    end
    
    % Close file
    fclose(fid); 
    
    
end
end
