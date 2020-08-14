% Counterbalance the statistical learning trials based on what was seen
% (rather than what order we designed).
% This creates new timing files with a suffix of -seen

function generate_seen_counterbalancing_timing_files(input, output)
    
    addpath scripts

    fprintf('Input: %s\nOutput: %s\n', input, output);

    % What is the secondlevel directory directory
    secondlevelname=input(strfind(input, 'secondlevel_StatLearning/') + 25:strfind(input, '/Timing/') - 1);
    secondlevelname=secondlevelname(secondlevelname ~= '/');

    % What is the directory
    sl_dir = sprintf('analysis/secondlevel_StatLearning/%s/', secondlevelname);
    
    % Load the block order file
    block_order_name=[sl_dir, 'block_order.txt'];
    fprintf('Using %s\n', block_order_name);
    fid = fopen(block_order_name, 'r');
    line = fgetl(fid);
    
    % Sometimes the block order file will be out of order because the
    % balancing was only fixed on the last cycle
    block_order = {};
    while line ~= -1
        block_order(end + 1, :) = strsplit(line);
        line = fgetl(fid);
    end
    fclose(fid);
    
    % Sometimes the block order file will be out of order because the
    % balancing was only fixed on the last cycle. Fix here
    run_order_code = [];
    for block = block_order'
        run_num = str2num(block{1}(11:12));
        if length(block{1}) > 12
            pseudorun_num = 1;
        else
            pseudorun_num = 0;
        end
        
        % What time does this block occur?
        time_stamp = str2num(block{5});
        
        run_order_code(end+1) = (run_num * 100000) + (pseudorun_num * 10000) + time_stamp;
    end
    
    % Reorder the runs based on these time codes
    [~, reorder] = sort(run_order_code);
    block_order = block_order(reorder, :);
    
    % Is this the structured or random condition
    is_structured = ~isempty(strfind(input, 'StatLearning-Structured'));
    
    % Find the blocks that match the condition
    if is_structured == 1
        block_idxs = strcmp('StatLearning-Structured', block_order(:,3));
    elseif is_structured == 0
        block_idxs = strcmp('StatLearning-Random', block_order(:,3));
    end
    
    % Get the condition blocks
    condition_blocks = block_order(block_idxs, :);
    
    % Pull out the nth seen for each block
    nth_seen = [];
    for block = condition_blocks(:, 4)'
        nth_seen(end+1) = str2num(block{1}(2));
    end
    
    % Based on the analysis you are doing, do different things with the
    % timing files. Assumes -seen is in the name
    analysis_type = output(max(strfind(output, '_')) + 1:max(strfind(output, '-')) - 1);
    
    % Specify the value for each column
    if strcmp(analysis_type, 'Slope')
       
        column = 3;
        
        % z score the values
        value = zscore(nth_seen);
    elseif strcmp(analysis_type, 'FIR')
        % This is the same
        column=2;
        value=1;
        
    elseif strcmp(analysis_type, 'half1')
        
        % Take the first half of seen blocks, ignoring the fact that some
        % may not have gotten to the second half
        column = 3;
        
        value =  nth_seen < 4;
    elseif strcmp(analysis_type, 'half2')
        
        % Take the second half of seen blocks, ignoring the fact that some
        % may not have gotten to the second half
        column = 3;
        
        value =  nth_seen > 3;    
    elseif strcmp(analysis_type, 'Intercept-exclude')     
        
        % Ignore the first seen block
        column = 3;
        
        value =  nth_seen > 1; 
    elseif isempty(strfind(analysis_type, 'regressor'))
        fprintf('Did not find a matching analysis type, quiting\n');
        return;
    end
        
    % Make the timing file
    if isempty(strfind(analysis_type, 'regressor'))
        change_timing_file_columns(input, output, value, column);
    else
        
        % If it is the block regressor analysis type then make a new timing
        % file for each of the 12 possible blocks. If this participant
        % didn't see a block then it will be all blank
        
        column = 3; % Fixed
        for seen_counter = 1:6
            
            % What is the name you will save this file as (assumes that it
            % is only the -seen you are creating), although that files
            % doesn't necessarily exist
            temp_output = [output(1:end - 9), sprintf('_%d.txt', seen_counter)];
           
            % Which block matches the nth seen
            value = nth_seen == seen_counter;
            
            % Create the timing file
            change_timing_file_columns(input, temp_output, value, column);
            
        end
    end
end
