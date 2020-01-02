% This function searches through the participant data and finds the delay
% between all block transitions. It then quantifies the amount of motion in
% that block in order to determine the extent to which a 'bad start' hurts
% the block.
% 
% This is done both between blocks while the scanner is running and also
% between PlayVideo and when a block begins.
%
% Also quantify the duration of each run based on the transition to
% starting that run

function Lag_data = quantify_transition_lag(output_dir, varargin)

% Preset the parameters
participant_parameters=varargin{1};

% Make it if it doesn't exist
mkdir(output_dir);

addpath scripts

% Get the participants
[Chosen_Participants, Participant_Info] = Participant_Index(participant_parameters);

% Assume TR
TR = 2;

% Cycle through the participants
Lag_data = struct;
for ppt_counter = 1:length(Chosen_Participants)
    
    ppt = Chosen_Participants{ppt_counter};
    
    % Load in the run data
    load(sprintf('subjects/%s/analysis/Behavioral/AnalysedData.mat', ppt))
    
    % When did each block start and end
    block_onsets = cell2mat(Data.Global.RunOrder(:, 4));
    block_offsets = cell2mat(Data.Global.RunOrder(:, 6));
    
    % Preset
    inter_run_lag = [];
    intra_run_lag = {};
    last_block_Experiment_name = {};
    run_mean_motion = [];
    run_init_mean_motion = [];
    run_max_motion = [];
    run_std_motion = [];
    run_length = [];
    
    for functional_counter = 1:length(AnalysedData.FunctionalLength)
        
        motion_file=sprintf('subjects/%s/analysis/firstlevel/Confounds/MotionMetric_fslmotion_3_functional%02d.txt', ppt, functional_counter);
        
        % Load in the motion data
        motion_metric = textread(motion_file);
        
        % Get stats on motion for this run
        run_mean_motion(functional_counter) = mean(motion_metric(:, 1));
        run_init_mean_motion(functional_counter) = mean(motion_metric(1:3, 1));
        run_std_motion(functional_counter) = std(motion_metric(:, 1));
        run_max_motion(functional_counter) = max(motion_metric(:, 1));
        run_length(functional_counter) = length(motion_metric(:, 1));
        
        % Figure out how long it took to transition in to this run
        run_blocks = AnalysedData.All_BlocksPerRun{functional_counter};
        
        % When did each block start
        block_start = [];
        block_end = [];
        block_mean_motion = [];
        block_init_mean_motion = [];
        block_std_motion = [];
        block_max_motion = [];
        for block_counter = 1:size(run_blocks, 1)
            
            % What experiment condition was run
            Experiment_condition = run_blocks{block_counter, 1};
            Experiment_name = Experiment_condition(1:max(strfind(Experiment_condition, '-')) - 1);
            
            % When did this block start
            block_start(block_counter) = Data.(sprintf('Experiment_%s', Experiment_name)).(run_blocks{block_counter,3}).Timing.TestStart;
            block_end(block_counter) = Data.(sprintf('Experiment_%s', Experiment_name)).(run_blocks{block_counter,3}).Timing.TestEnd;
            
            % Get motion info for this block
            TR_start = ceil((block_start(block_counter) - block_start(1)) / TR) + 1;
            TR_end = ceil((block_end(block_counter) - block_start(1)) / TR) + 1;
            
            % Bound if necessary
            TR_start(TR_start<1)= 1;
            if TR_start < length(motion_metric)
                TR_end(TR_end>length(motion_metric)) = length(motion_metric);
                
                block_mean_motion(block_counter) = mean(motion_metric(TR_start:TR_end, 1));
                if TR_end > TR_start+3
                    block_init_mean_motion(block_counter) = mean(motion_metric(TR_start:TR_start+3, 1));
                else
                    block_init_mean_motion(block_counter) = block_mean_motion(block_counter);
                end
                block_std_motion(block_counter) = std(motion_metric(TR_start:TR_end, 1));
                block_max_motion(block_counter) = max(motion_metric(TR_start:TR_end, 1));
            end
        end
        
        % What was the last block before this one with functional data
        last_block_idx = max(find((block_start(1) - block_onsets) > 0)) - 1;
        if last_block_idx > 0
            last_block_Experiment_name{functional_counter} = Data.Global.RunOrder{last_block_idx, 1};
            last_block_Block_name = Data.Global.RunOrder{last_block_idx, 2};
            
            % How long did it take to start the first block
            inter_run_lag(functional_counter) = block_start(1) - Data.(last_block_Experiment_name{functional_counter}).(last_block_Block_name).Timing.TestEnd;
            
            % If the lag is less than zero that might be because the data
            % was editted but not fully
            if inter_run_lag(functional_counter) < 0
                inter_run_lag(functional_counter) = NaN;
            end
            
            % Assume a lag of more than 45s represents an error. For
            % instance we might not have had play video on before the
            % experiments start
            if inter_run_lag(functional_counter) > 45
                inter_run_lag(functional_counter) = NaN;
            end
        else
            inter_run_lag(functional_counter) = NaN;
        end
        
        % Quantify the intra block lags
        if length(block_start) > 1
            intra_run_lag{functional_counter} = block_start(2:end) - block_end(1:end-1);
            
        else
            intra_run_lag{functional_counter} = NaN;
        end
        
        % Store interim information
        Lag_data.(['ppt_', ppt]).block_mean_motion{functional_counter} = block_mean_motion;
        Lag_data.(['ppt_', ppt]).block_init_mean_motion{functional_counter} = block_init_mean_motion;
        Lag_data.(['ppt_', ppt]).block_max_motion{functional_counter} = block_max_motion;
        Lag_data.(['ppt_', ppt]).block_std_motion{functional_counter} = block_std_motion;
        
    end
    
    % Store information
    Lag_data.(['ppt_', ppt]).inter_run_lag = inter_run_lag;
    Lag_data.(['ppt_', ppt]).intra_run_lag = intra_run_lag;
    Lag_data.(['ppt_', ppt]).last_block_Experiment_name = last_block_Experiment_name;
    
    Lag_data.(['ppt_', ppt]).run_mean_motion = run_mean_motion;
    Lag_data.(['ppt_', ppt]).run_init_mean_motion = run_init_mean_motion;
    Lag_data.(['ppt_', ppt]).run_max_motion = run_max_motion;
    Lag_data.(['ppt_', ppt]).run_std_motion = run_std_motion;
    Lag_data.(['ppt_', ppt]).run_length = run_length;
end

% Compare the intra_run_lag for the all vs last transition within a run
% (sometimes will be the same). Is it more likely that the last block of a
% run will have a big lag?

ppts = fieldnames(Lag_data);
all_lags = [];
last_lags = [];
for ppt = ppts'
    
    intra_run_lag = Lag_data.(ppt{1}).intra_run_lag;
    
    % Cycle through the functionals
    for functional_counter = 1:length(intra_run_lag)
        
        if length(intra_run_lag{functional_counter}) > 1
            all_lags(end + 1:end+length(intra_run_lag{functional_counter})-1) = intra_run_lag{functional_counter}(1:end-1);
            last_lags(end + 1) = intra_run_lag{functional_counter}(end);
        elseif length(intra_run_lag{functional_counter}) == 1
            last_lags(end + 1) = intra_run_lag{functional_counter};
        end
    end
    
end

% Remove nans
all_lags = all_lags(isnan(all_lags) == 0);
last_lags = last_lags(isnan(last_lags) == 0);

% Make histograms of the two lag sets and plot them
figure
hold on
[counts, bins] = hist(all_lags, 25);
plot(bins,counts, 'r');
[counts, bins] = hist(last_lags, 25);
plot(bins,counts, 'b');
hold off
legend({'all lags', 'last lags'});
ylabel('Count')
xlabel('Inter-block lag (s)');
saveas(gcf, [output_dir, '/last_lag_duration.png']);

% Does the inter-run correlate with the motion for the run
inter_run_lag_all = [];
run_mean_motion_all = [];
run_init_mean_motion_all = [];
run_std_motion_all = [];
run_max_motion_all = [];
run_length_all = [];
for ppt = ppts'
    
    % Pull out data and append to list
    inter_run_lag = Lag_data.(ppt{1}).inter_run_lag;
    run_mean_motion = Lag_data.(ppt{1}).run_mean_motion;
    run_init_mean_motion = Lag_data.(ppt{1}).run_init_mean_motion;
    run_std_motion = Lag_data.(ppt{1}).run_std_motion;
    run_max_motion = Lag_data.(ppt{1}).run_max_motion;
    run_length = Lag_data.(ppt{1}).run_length;
    
    inter_run_lag_all(end+1:end+length(inter_run_lag)) = inter_run_lag;
    run_mean_motion_all(end+1:end+length(run_mean_motion)) = run_mean_motion;
    run_init_mean_motion_all(end+1:end+length(run_init_mean_motion)) = run_init_mean_motion;
    run_std_motion_all(end+1:end+length(run_std_motion)) = run_std_motion;
    run_max_motion_all(end+1:end+length(run_max_motion)) = run_max_motion;
    run_length_all(end+1:end+length(run_length)) = run_length;
end

included_runs = isnan(inter_run_lag_all) == 0;

% Make the plots
figure
scatter(inter_run_lag_all(included_runs), run_mean_motion_all(included_runs))
title(sprintf('Mean motion and run lag. r: %0.3f', corr(inter_run_lag_all(included_runs)', run_mean_motion_all(included_runs)')));
xlabel('Inter run lag (s)')
ylabel('Mean run motion')
saveas(gcf, [output_dir, '/mean_motion_lag_run.png']);

figure
scatter(inter_run_lag_all(included_runs), run_init_mean_motion_all(included_runs))
title(sprintf('Initial mean motion and run lag. r: %0.3f', corr(inter_run_lag_all(included_runs)', run_init_mean_motion_all(included_runs)')));
xlabel('Inter run lag (s)')
ylabel('Initial mean run motion')
saveas(gcf, [output_dir, '/init_mean_motion_lag_run.png']);

figure
scatter(inter_run_lag_all(included_runs), run_std_motion_all(included_runs))
title(sprintf('Std motion and run lag. r: %0.3f', corr(inter_run_lag_all(included_runs)', run_std_motion_all(included_runs)')));
xlabel('Inter run lag (s)')
ylabel('Std run motion')
saveas(gcf, [output_dir, '/std_motion_lag_run.png']);
    
figure
scatter(inter_run_lag_all(included_runs), run_max_motion_all(included_runs))
title(sprintf('Max motion and run lag. r: %0.3f', corr(inter_run_lag_all(included_runs)', run_max_motion_all(included_runs)')));
xlabel('Inter run lag (s)')
ylabel('Max run motion')
saveas(gcf, [output_dir, '/max_motion_lag_run.png']);

figure
scatter(inter_run_lag_all(included_runs), run_length_all(included_runs))
title(sprintf('Run length and run lag. r: %0.3f', corr(inter_run_lag_all(included_runs)', run_length_all(included_runs)')));
xlabel('Inter run lag (s)')
ylabel('Run length (TRs)')
saveas(gcf, [output_dir, '/length_motion_lag_run.png']);

% Look at the motion per block as it relates to intra run lags

intra_run_lag_all = [];
block_mean_motion_all = [];
block_init_mean_motion_all = [];
block_std_motion_all = [];
block_max_motion_all = [];

for ppt = ppts'
    
    % Pull out data and append to list
    for functional_counter = 1:length(Lag_data.(ppt{1}).intra_run_lag)
        
        if all(isnan(Lag_data.(ppt{1}).intra_run_lag{functional_counter}) == 0)
            intra_run_lag = Lag_data.(ppt{1}).intra_run_lag{functional_counter};
            
            % Since the intra_run lag is between block N and N+1, you need
            % to shift for the motion metrics in order to refer to the
            % effect of the lag
            block_mean_motion = Lag_data.(ppt{1}).block_mean_motion{functional_counter}(2:end);
            block_init_mean_motion = Lag_data.(ppt{1}).block_init_mean_motion{functional_counter}(2:end);
            block_std_motion = Lag_data.(ppt{1}).block_std_motion{functional_counter}(2:end);
            block_max_motion = Lag_data.(ppt{1}).block_max_motion{functional_counter}(2:end);
            
            % Shorten if necessary (because no TRs were collected
            if length(intra_run_lag) ~= length(block_max_motion)
                intra_run_lag = intra_run_lag(1:length(block_max_motion));
            end
            
            intra_run_lag_all(end+1:end+length(intra_run_lag)) = intra_run_lag;
            block_mean_motion_all(end+1:end+length(block_mean_motion)) = block_mean_motion;
            block_init_mean_motion_all(end+1:end+length(block_init_mean_motion)) = block_init_mean_motion;
            block_std_motion_all(end+1:end+length(block_std_motion)) = block_std_motion;
            block_max_motion_all(end+1:end+length(block_max_motion)) = block_max_motion;
        end
    end
end

% Make the plots

figure
scatter(intra_run_lag_all, block_mean_motion_all)
title(sprintf('Mean motion and block lag. r: %0.3f', corr(intra_run_lag_all', block_mean_motion_all')));
xlabel('Inter block lag (s)')
ylabel('Mean block motion')
saveas(gcf, [output_dir, '/mean_motion_lag_block.png']);

figure
scatter(intra_run_lag_all, block_init_mean_motion_all)
title(sprintf('Initial mean motion and block lag. r: %0.3f', corr(intra_run_lag_all', block_init_mean_motion_all')));
xlabel('Inter block lag (s)')
ylabel('Initial mean block motion')
saveas(gcf, [output_dir, '/init_mean_motion_lag_block.png']);

figure
scatter(intra_run_lag_all, block_std_motion_all)
title(sprintf('Std motion and block lag. r: %0.3f', corr(intra_run_lag_all', block_std_motion_all')));
xlabel('Inter block lag (s)')
ylabel('std block motion')
saveas(gcf, [output_dir, '/std_motion_lag_block.png']);

figure
scatter(intra_run_lag_all, block_max_motion_all)
title(sprintf('Max motion and block lag. r: %0.3f', corr(intra_run_lag_all', block_max_motion_all')));
xlabel('Inter block lag (s)')
ylabel('Max block motion')
saveas(gcf, [output_dir, '/max_motion_lag_block.png']);
