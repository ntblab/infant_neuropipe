% Identify blocks that can be included and excluded for Repetition
% Narrowing
%
% This script is used by Functional Splitter to choose which blocks will be placed in different
% second level folders. Passing a different SecondLevelAnalysisName to this function will result
% in different counterbalancing procedures
%
% By default, this script includes all useable blocks regardless of whether it is a completely
% counterbalanced set within a functional run (e.g., perhaps you have 6 blocks, 5 fulfilling a complete
% set and then one extra block of a specific condition/category)
%
% Other options are to make separate secondlevel folders for the main stimulus categories (sheep and human),
% insuring that there is a balance in novel and repeated conditions. (e.g., if you
% got three sheep blocks, two that were novel and one that was repeated,
% only one novel and one repeated would be passed along to the sheep_pairs folder)
%
% The final main counterbalancing condition would be to balance scenes and novel human faces
%
% TY 11/5/2019
% Update with other block balancing possibilities, just in case
% TY 05/26/2020

function Concat=RepetitionNarrowing_Block_Balancing(varargin)

AnalysedData = varargin{1}; % Output of Analysis_Timing
Concat = varargin{2}; % Structure containing block and timing information for all runs
functional_run = varargin{3}; % What run is this (full name, including pseudoruns)
SecondLevelAnalysisName = varargin{4}; % What subdirectory is this data going to be stored in

% How do you want to do counterbalancing? At the moment there are 4 conditions:
counterbalancing_types = {'Counterbalance for human (novel and repeated)', ...
    'Counterbalance for sheep (novel and repeated)', ...
    'Counterbalance for scene-face localizer (scene and novel human) ', ...
    'Counterbalance for 5 conditions', ...
    'Don''t counterbalance, take everything that is usable';

% Use the SecondLevelAnalysisName to determine the counterbalancing
% condition
if strcmp(SecondLevelAnalysisName, 'default')
    counterbalancing_condition = 5; % Default to 5 --> keep everything
elseif strcmp(SecondLevelAnalysisName, 'human_pairs')
    counterbalancing_condition = 1;
elseif strcmp(SecondLevelAnalysisName, 'sheep_pairs')
    counterbalancing_condition = 2;
elseif strcmp(SecondLevelAnalysisName, 'scene_face')
    counterbalancing_condition = 3;
elseif strcmp(SecondLevelAnalysisName, 'all_balance')
    counterbalancing_condition = 4;
else
    warning('\nFirstlevel name doesn''t match, using the default functional splitter procedure');
    counterbalancing_condition = 5;
end

fprintf('\nCounterbalancing condition:\n%s\n\n', counterbalancing_types{counterbalancing_condition});

% Make this directory if it doesn't exist
if exist(['analysis/secondlevel_RepetitionNarrowing/', SecondLevelAnalysisName]) == 0
    mkdir('analysis/secondlevel_RepetitionNarrowing/');
    mkdir(['analysis/secondlevel_RepetitionNarrowing/', SecondLevelAnalysisName]);
end

experiment = 'RepetitionNarrowing';
expected_block_duration=28; % How long should a block take in seconds (this includes the star and VPC, and an extra TR following the VPC before the 6 second delay between blocks)

block_order_file = sprintf('analysis/secondlevel_RepetitionNarrowing/%s/block_order.txt', SecondLevelAnalysisName);

% Find all timing files in this run that match this experiment
Idxs_RepetitionNarrowing=strcmp(Concat.(functional_run).Block.Name, experiment);


%% Were there any RepetitionNarrowing blocks found?
if ~isempty(Idxs_RepetitionNarrowing)
    
    fprintf('Finding pairs of blocks for Repetition Narrowing:\n')
    
    % Cycle through the blocks of this run and check that the paired
    % block is also run
    Included_idxs=[]; %Which idxs are included?
    Remaining_blocks=1:25; % Preset to max number of blocks, this will be changed
    Block_numbers = [];
    BlockNames = {};
    ConditionNames = {};
    File_idx = [];
    Onset_idx = [];
    Onsets = [];
    is_novel = [];
    
    % Open a text file for keeping track of what blocks are included
    fid = fopen(block_order_file, 'a');
    for Idx_Counter=1:length(Idxs_RepetitionNarrowing)
        
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
                ConditionNames{end+1} = extractAfter(ConditionName,'-');
                is_novel(end+1) = ~isempty(strfind(ConditionName, 'NoReps'));
                File_idx(end+1) = Idx_Counter;
                Onset_idx(end+1) = onset_counter;
                Onsets(end+1) = onset;
                
            end
        end
    end
    
    %% Here is where you are going to balance for the subfolders
    
    %Check remaining block names when creating pairs
    Remaining_block_names=ConditionNames;
    
    % Cycle through the block numbers that were identified
    for block_counter = 1:length(Block_numbers)
        
        % What is the block number?
        Block_number = Block_numbers(block_counter);
        
        % What is the block name?
        CategoryCondition=ConditionNames(block_counter);
        CategoryCondition=CategoryCondition{1};
        
        %Preset
        Paired_Idx=[];
        Possible_Pairs=[];
        
        % Needed function
        cellfind = @(string)(@(cell_contents)(strcmp(string,cell_contents)));
        
        % Is it novel? Only novel blocks are treated as the reference
        if is_novel(block_counter)==1 || counterbalancing_condition == 5
            
            % counterbalance for human
            if counterbalancing_condition == 1 && ~isempty(strfind(CategoryCondition,'Human'))==1
                
                % Find the next block that is a repeated human
                Possible_Pairs=cellfun(cellfind('Human_Adult_Reps'),ConditionNames);
                
            % counterbalance for sheep
            elseif counterbalancing_condition == 2 && ~isempty(strfind(CategoryCondition,'Sheep'))==1
                
                % Find the next block that is a repeated sheep
                Possible_Pairs=cellfun(cellfind('Sheep_Reps'),ConditionNames);
                
            % counterbalance for scenes --- just choose the same number of human face blocks
            elseif counterbalancing_condition == 3 && ~isempty(strfind(CategoryCondition,'Scene'))==1
                
                %check which ones have the correct names in them
                Possible_Pairs=cellfun(cellfind('Human_Adult_NoReps'),ConditionNames);
                
            end
            
            if counterbalancing_condition ~= 5
                %Now we know which blocks are in the right counterbalancing
                %which blocks were these?
                Possible_Block_Nums=Block_numbers(Possible_Pairs);
                
                %And are they still remaining?
                Possible_Block=intersect(Possible_Block_Nums,Remaining_blocks);
                
                %Just choose the first one if there are more than one
                if size(Possible_Block,2) > 1
                    Possible_Block=Possible_Block(1);
                end
                
                %And if you found it, get its index!
                if ~isempty(Possible_Block)
                    Paired_Idx=find(Block_numbers==Possible_Block);
                else
                    Paired_Idx=[];
                end
            end
            
	    % Depending on the counterbalancing condition, you'll need to get the appropriate block pair 
	    % (Not necessary for the default counterbalancing, or when you are balancing more than 2 conditions)
            if counterbalancing_condition ~= 5 && counterbalancing_condition ~= 4 && ~isempty(Paired_Idx)
                
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
                    fprintf(fid, '%s %s %s: %d\n', functional_run, BlockNames{block_counter}, ConditionNames{block_counter}, Onsets(block_counter));
                    fprintf(fid, '%s %s %s: %d\n', functional_run, BlockNames{Paired_Idx}, ConditionNames{Paired_Idx}, Onsets(Paired_Idx));
                    
                    
                end
                
            % Easy if you are just using the default
            elseif counterbalancing_condition == 5
                
                % If this is the all blocks condition then just append each block at a time
                Included_idxs(end+1)=block_counter;
                Remaining_blocks=setdiff(Remaining_blocks, Block_number);
                
                fprintf('Using %s (%s).\n', BlockNames{block_counter}, ConditionNames{block_counter});
                
                % Print the summary of block info to a block order file
                % that can be used
                fprintf(fid, '%s %s %s: %d\n', functional_run, BlockNames{block_counter}, ConditionNames{block_counter}, Onsets(block_counter));
                
                
            end
        end
    end
    
    % Perhaps you want to counterbalance for all 5 block types
    if counterbalancing_condition ==4
        
        % Identify which event file is which
        condition_types = {'Human_Adult_NoReps', 'Human_Adult_Reps', 'Sheep_NoReps', 'Sheep_Reps','Scenes_NoReps'};
        condition_idxs = [];
        for file = Concat.(functional_run).Block.Files
            
            condition = file{1};
            condition = condition(strfind(condition, 'RepetitionNarrowing') + 20: strfind(condition, '.txt')-1);
            
            % if you have the earlier version when i didn't name the scene
            % blocks correctly, fix
            if contains(condition,'Scenes_Reps')
                condition='Scenes_NoReps';
            end
            
            condition_idxs(end+1) = find(strcmp(condition_types, condition));
            
        end
        
        % Find the indices
        hum_N_idx = find(condition_idxs == 1);
        hum_R_idx = find(condition_idxs == 2);
        sheep_N_idx = find(condition_idxs == 3);
        sheep_R_idx = find(condition_idxs == 4);
        scene_idx = find(condition_idxs==5);
        
        % First check that none of these indices are empty
        if ~isempty(hum_N_idx) && ~isempty(hum_R_idx) && ~isempty(sheep_N_idx) && ~isempty(sheep_R_idx) && ~isempty(scene_idx)
            
            % Get the mat file
            hum_N_mat = Concat.(functional_run).Block.Mat{hum_N_idx};
            hum_R_mat = Concat.(functional_run).Block.Mat{hum_R_idx};
            sheep_N_mat = Concat.(functional_run).Block.Mat{sheep_N_idx};
            sheep_R_mat = Concat.(functional_run).Block.Mat{sheep_R_idx};
            scene_mat = Concat.(functional_run).Block.Mat{scene_idx};
            
            % If there are equal numbers in each condition then YAY, otherwise
            % match them
            
            if sum(hum_N_mat(:, 3)) == sum(hum_R_mat(:, 3)) && sum(hum_N_mat(:,3)) == sum(sheep_N_mat(:,3)) && sum(hum_N_mat(:,3))== sum(sheep_R_mat(:,3)) && sum(hum_N_mat(:,3))== sum(scene_mat(:,3))
                fprintf('conditions are balanced \n');
            else
                
                fprintf('conditions are not balanced, balancing\n');
                
                % If there are inconsistent numbers then find the pairs of times
                % that have the minimum difference in time (meaning you match
                % within block if possible)
                usable_1 = ones(size(hum_N_mat,1),1);
                usable_2 = ones(size(hum_R_mat,1),1);
                usable_3 = ones(size(sheep_R_mat,1),1);
                usable_4 = ones(size(sheep_R_mat,1),1);
                usable_5 = ones(size(scene_mat,1),1);
                
                % Get all combos of the blocks
                [m,n,o,p,q] = ndgrid(1:size(hum_N_mat,1), 1:size(hum_R_mat,1), 1:size(sheep_N_mat,1),1:size(sheep_R_mat,1),1:size(scene_mat,1));
                combs = [m(:), n(:), o(:), p(:), q(:)];
                
                % Find which of these difference indexes is usable
                usable_pair = [];
                for order_idx = 1:size(combs,1)
                    
                    % Check these are still usable
                    if usable_1(combs(order_idx, 1)) == 1 &&  usable_2(combs(order_idx, 2)) == 1 &&  usable_3(combs(order_idx, 3)) == 1 &&  usable_4(combs(order_idx, 4)) == 1 && usable_5(combs(order_idx,5)) == 1
                        
                        usable_pair(end+1) = order_idx;
                        
                        % Update which ones can be used
                        usable_1(combs(order_idx, 1)) = 0;
                        usable_2(combs(order_idx, 2)) = 0;
                        usable_3(combs(order_idx, 3)) = 0;
                        usable_4(combs(order_idx, 4)) = 0;
                        usable_5(combs(order_idx, 5)) = 0;
                        
                    end
                end
                
                % Now only store the concat data for the events that are included
                Concat.(functional_run).Block.Mat{hum_N_idx} = Concat.(functional_run).Block.Mat{hum_N_idx}(combs(usable_pair, 1), :);
                Concat.(functional_run).Block.Mat{hum_R_idx} = Concat.(functional_run).Block.Mat{hum_R_idx}(combs(usable_pair, 2), :);
                Concat.(functional_run).Block.Mat{sheep_N_idx} = Concat.(functional_run).Block.Mat{sheep_N_idx}(combs(usable_pair, 3), :);
                Concat.(functional_run).Block.Mat{sheep_R_idx} = Concat.(functional_run).Block.Mat{sheep_R_idx}(combs(usable_pair, 4), :);
                Concat.(functional_run).Block.Mat{scene_idx} = Concat.(functional_run).Block.Mat{scene_idx}(combs(usable_pair, 5), :);
            end
            
        % Set to empty though if not all of the conditions were useable    
        else
             fprintf('Not enough blocks in run %s\n',functional_run);
            Concat.(functional_run).Block.Mat = {};

        end
        
    end
    
    if counterbalancing_condition~=4
    
        % Go through the mat data and keep only the rows that are included
        for Idx_Counter=1:length(Idxs_RepetitionNarrowing)
            
            % What entries in the list of included indexes are both included
            % and part of this timing file
            useable_idxs = intersect(find(File_idx == Idx_Counter), Included_idxs);
            
            % Take the onsets that are useable and resave them
            Concat.(functional_run).Block.Mat{Idx_Counter} = Concat.(functional_run).Block.Mat{Idx_Counter}(Onset_idx(useable_idxs), :);
        end
    end
    % Close file
    fclose(fid);

end

end
