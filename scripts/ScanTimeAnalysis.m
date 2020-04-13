%% Find and pull out the MatFiles for each subject that meet the specified criteria, and then analyze the amount of usable data.
%
%Iterate through each subject that meet the specified criteria and load in the AnalysisTiming.mat file that
% is created by Analysis_Timing.m, and then accrue the information you need from it.
% 
% Must have run analysis timing for this to work at a minimum, however it
% is recommended that the participant is fully analyzed to use it
% properly
%
% Hard code any runs where the participants were asleep but not in the resting
% state experiment. Add a row to the `sleeping_runs` variable such that it
% includes the participant name, the run number, and the run name that is
% to be excluded. If all blocks in a run are to be excluded because of
% sleep then say 'All'
%
% This code outputs various graphs and statistics from all the collected
% participants. The main output is a bar graph of the participants usable
% and unusable functional and anatomical data. It will also summarize the
% data collection rates and comparisons of data collection for participants
% first and second sessions. Furthermore, it runs analyses of the data
% retention rate if a stricter motion threshold was applied, akin to Deen
% et al 2017.
%
function ScanTimeAnalysis(participant_criteria, analysis_name)

if nargin == 0
    participant_criteria={'included_sessions', {'dev'}, 'Max_Age', 36}; % What is the criteria for including participants
    analysis_name = 'default'; % What is the folder name within which to put this plot
end

addpath scripts

plot_non_scanner_time = 0; % Do you want to plot non-scanning time?

% Hard code which blocks or runs should be categorized as sleeping
sleeping_runs = {};

% Hard code the session where no data was collected (these do not have a
% subject folder. First column is their id, the second column is their age, the third column is the not
% scanning time. If this is empty then you won't plot unscanned participants
no_data_participants = {};

% Get the project directory
addpath prototype/link/scripts
globals_struct=read_globals('prototype/link/'); % Load the content of the globals folder

proj_dir = globals_struct.PROJ_DIR;

[Choosen_Participants, Participant_Info] = Participant_Index(participant_criteria);

subjects_folder=[proj_dir, '/subjects/'];
output_dir = sprintf('%s/results/ScanTimeAnalysis/%s/', proj_dir, analysis_name);

% Make the folder if you can
if exist(output_dir) == 0
    mkdir(output_dir);
end

diary(sprintf('%s/ScanTime_Log', output_dir)); %Start a log file

Time_per_petra=188;
Time_per_mprage=186;
Time_per_space=107;
Time_per_scout=14;

% Exclude participants who don't have Analysis Timing
bkp_Choosen_Participants = Choosen_Participants;
Choosen_Participants = {};
for ppt = bkp_Choosen_Participants
	if exist(sprintf('%s/%s/analysis/Behavioral/AnalysedData.mat', subjects_folder, ppt{1}))~=0
		Choosen_Participants{end+1} = ppt{1};
    else
        fprintf('\nExcluding %s because it isn''t preprocessed', ppt{1});
	end
end

% How many participants are there? Including the no data participants
ppt_num = length(Choosen_Participants) + size(no_data_participants,1);

% Preset all of the durations to zero
Anatomical_duration=zeros(ppt_num, 1);
Exp_Menu_Duration=zeros(ppt_num, 1);
Total_functional_duration=zeros(ppt_num, 1);
Included_functional_duration=zeros(ppt_num, 1);
Motion_excluded_duration=zeros(ppt_num, 1);
Eye_excluded_duration=zeros(ppt_num, 1);
Ignored_run_duration=zeros(ppt_num, 1);
Ignored_block_duration=zeros(ppt_num, 1);
Asleep_duration=zeros(ppt_num, 1);
Scout_duration=zeros(ppt_num, 1);

Secondlevel_Experiments=zeros(ppt_num, 1);

for participant_counter=1:length(Choosen_Participants)
    
    ppt=Choosen_Participants{participant_counter};
    cd(sprintf('%s/%s/', subjects_folder, ppt));
    
    % Count the number of anatomicals
    petras=dir(sprintf('data/nifti/%s*petra0*original.nii.gz', ppt));
    mprages=dir(sprintf('data/nifti/%s*mprage0*original.nii.gz', ppt));
    spaces=dir(sprintf('data/nifti/%s*space0*original.nii.gz', ppt));
    scouts=dir(sprintf('data/nifti/%s*scout*11.nii.gz', ppt));
    
    % Load in the number of TRs collected
    functionals=dir('data/nifti/*functional*gz');
    
    run_functional_duration=[];
    run_functional_TR=[];
    for functional_counter=1:length(functionals)
        
        functional = sprintf('data/nifti/%s_functional%02d.nii.gz', ppt, functional_counter);
        if exist(functional) == 0
            fprintf('\n%s not detected, aborting\n', functional);
            return
        end
        
        % Edit the functional data
        command=sprintf('fslval %s dim4', functional);
        [~, TR_number]=unix(command);
        
        command=sprintf('fslval %s pixdim4', functional);
        [~, TR_duration]=unix(command);
        
        TR_duration = str2num(TR_duration);
        if TR_duration > 1000
            TR_duration=TR_duration/1000;
        end
        run_functional_duration(functional_counter) = (str2num(TR_number) * TR_duration);
        
        run_functional_TR(functional_counter)=TR_duration;
    end
    
    % Sum the duration of the functional data collected
    Total_functional_duration(participant_counter)=sum(run_functional_duration);
    
    % Count the number of anatomicals run
    Anatomical_duration(participant_counter) = length(petras) * Time_per_petra;
    Anatomical_duration(participant_counter) = Anatomical_duration(participant_counter) + length(mprages) * Time_per_mprage;
    Anatomical_duration(participant_counter) = Anatomical_duration(participant_counter) + length(spaces) * Time_per_space;
    
    Scout_duration(participant_counter) = length(scouts) * Time_per_scout;
    
    % Load in the behavioral data (If it exists) to estimate the total
    % experiment time
    idx=strcmp(Participant_Info(:, 1), ppt);
    data_file=sprintf('data/Behavioral/%s.mat', Participant_Info{idx, 2});
    
    if exist(data_file) > 0
        load(data_file);
        
        %Load in the experiment menu duration (sometimes the load time
        %will be appropriate, sometimes the start time)
        if isfield(Data.Global.Timing, 'Loaded')
            if Data.Global.Timing.Loaded(1)-Data.Global.Timing.Start > 20000
                Start = Data.Global.Timing.Loaded(1);
            else
                Start = Data.Global.Timing.Start;
            end
        else
            Start = Data.Global.Timing.Start;
        end
        try
            Finish = Data.Global.Timing.Finish;
        catch
            Finish = Data.Global.Timing.TR(end);
        end
        Exp_Menu_Duration(participant_counter) = (Finish - Start);
    else
        Exp_Menu_Duration(participant_counter) = Anatomical_duration(participant_counter) + Total_functional_duration(participant_counter);
    end
    
    % Figure out the exclusion criteria for motion
    
    if isdir('analysis/secondlevel/') && exist('analysis/Behavioral/AnalysedData.mat')~=0
        load analysis/Behavioral/AnalysedData.mat
        
        if isfield(AnalysedData, 'All_BlocksPerRun')
            
            for Run_Counter=1:length(AnalysedData.All_BlocksPerRun)
                
                % Pull out the number of blocks in this run that are included
                BlocksPerRun=AnalysedData.All_BlocksPerRun{Run_Counter};
                
                % What is the TR duration for this run
                TR_duration = AnalysedData.TR(Run_Counter);

                % Are there any blocks in this run?
                if ~isempty(AnalysedData.Included_BlocksPerRun{Run_Counter})
                    
                    for Block_Counter=1:size(BlocksPerRun,1)
                        
                        % Pull out block information
                        Experiment=BlocksPerRun{Block_Counter,1}(1:strfind(BlocksPerRun{Block_Counter,1}, '-')-1);
                        BlockData=AnalysedData.(sprintf('Experiment_%s', Experiment)).(BlocksPerRun{Block_Counter,3});
                        
                        % Is this block included or not (ignore if it is
                        % resting state
                        if BlockData.Include_Block==1 && ~strcmp(Experiment, 'RestingState')
                            
                            % Sum the duration of time that is excluded because of
                            % motion
                            Motion_excluded_temp = (length(BlockData.ExcludedTRs) * TR_duration);
                            Motion_excluded_duration(participant_counter) = Motion_excluded_duration(participant_counter) + Motion_excluded_temp;
                            
                            % Pull out the eye tracking data exclusions. Find all
                            % the TRs that aren't the same as the motion exclusion
                            % ones and then figure out how long those last
                            unique_eye_excluded = setdiff(AnalysedData.(sprintf('Experiment_%s', Experiment)).(BlocksPerRun{Block_Counter,3}).EyeTracking_Excluded_TRs, AnalysedData.(sprintf('Experiment_%s', Experiment)).(BlocksPerRun{Block_Counter,3}).ExcludedTRs);
                            Eye_excluded_temp = length(unique_eye_excluded) * TR_duration;
                            Eye_excluded_duration(participant_counter) = Eye_excluded_duration(participant_counter) + Eye_excluded_temp;
                            
                            % Figure out how much data is left over
                            block_duration = (length(BlockData.block_TRs) * TR_duration);
                            Included_functional_duration(participant_counter)=Included_functional_duration(participant_counter) + (block_duration - Motion_excluded_temp - Eye_excluded_temp);
                        elseif strcmp(Experiment, 'RestingState')
                            Asleep_duration(participant_counter)=Asleep_duration(participant_counter) + (length(BlockData.block_TRs) * TR_duration);
                        else
                            
                            % Store information as asleep if it is resting state or if the blocks
                            % were
                            ppt_idx = strcmp(sleeping_runs(:,1), ppt);
                            run_idx =  cell2mat(sleeping_runs(:,2)) == Run_Counter;
                            block_idx = strcmp(sleeping_runs(:,3), BlocksPerRun(Block_Counter,3));
                           
                            % If there are no matching block names because
                            % it says all then include it as sleeping
                            if all(block_idx == 0) && length(find(ppt_idx .* run_idx))>0 && strcmp(sleeping_runs(find(ppt_idx .* run_idx), 3), 'All')
                                
                                block_idx = (ppt_idx .* run_idx);
                                
                            end
                            
                            %Which indexes are common for both the participant and
                            % the run
                            match_idxs = find(ppt_idx .* run_idx .* block_idx, 1);
                            
                            % If the participant is listed in sleeping runs
                            % then exclude here
                            if length(match_idxs) == 1
                                Asleep_duration(participant_counter)=Asleep_duration(participant_counter) + (length(BlockData.block_TRs) * TR_duration);
                            else
                                Ignored_block_duration(participant_counter)=Ignored_block_duration(participant_counter) + (length(BlockData.block_TRs) * TR_duration);
                            end
                        end
                    end
                else
                    
                    
                    % Store information as asleep if it is resting state or if the blocks
                    % were
                    ppt_idx = strcmp(sleeping_runs(:,1), ppt);
                    run_idx = cell2mat(sleeping_runs(:,2))==Run_Counter;
                    
                    % Which indexes are common for both the participant and
                    % the run
                    match_idxs = find(ppt_idx .* run_idx, 1);
                    
                    % If this run was listed in sleeping_runs as 'All',
                    % then add it to the sleeping duration counter
                    if ~isempty(match_idxs) && length(sleeping_runs(match_idxs, 3)) == 1 && strcmp(sleeping_runs(match_idxs, 3), 'All')
                        Asleep_duration(participant_counter)=Asleep_duration(participant_counter) + run_functional_duration(Run_Counter);
                    else
                        % Add this run to the list of skipped ones
                        Ignored_run_duration(participant_counter)=Ignored_run_duration(participant_counter) + run_functional_duration(Run_Counter);
                    end
                end
            end
           
        end
    else
        % Store information as asleep if it is resting state or if the blocks
        % were
        ppt_idx = strcmp(sleeping_runs(:,1), ppt);
        run_idx = cell2mat(sleeping_runs(:,2))==Run_Counter;
        
        % Which indexes are common for both the participant and
        % the run
        match_idxs = find(ppt_idx .* run_idx, 1);
        
        % If this run was listed in sleeping_runs as 'All',
        % then add it to the sleeping duration counter
        if  ~isempty(match_idxs) && length(sleeping_runs(match_idxs, 3)) == 1 && strcmp(sleeping_runs(match_idxs, 3), 'All')
            Asleep_duration(participant_counter)=Asleep_duration(participant_counter) + run_functional_duration(Run_Counter);
        else
            % If the data hasn't been analyzed then ignore it
            Ignored_run_duration(participant_counter)=sum(run_functional_duration);
        end
    end
    
    % Pull out information from the bxh file or dicom file. In particular, get the
    % participant scan date, scan time and age
    if ~isempty(strfind(ppt, 'dev')) || ~isempty(strfind(ppt, 'FAS'))
        files = dir('data/nifti/*.bxh');
    else
        % If collected at BIC then look at the dicoms directly
        files=dir('data/raw/*/SCANS/*/DICOM/*dcm');
    end
    
    if length(files) > 0
        % Read the first file
        hdr_file = [files(1).folder, '/', files(1).name];
        
        % Is this the BIC sample, if so, rename the bxh file
        if isempty(strfind(ppt, 'dev')) && isempty(strfind(ppt, 'FAS'))
            error = unix(sprintf('dicom_hdr %s > ./temp_dicom.txt', hdr_file));
            
            % If there is an error then quit out
            if error == 1
                fprintf('Error running dicom_hdr, check that it is loaded into your environment\nAborting\n');
                return
            end
            
            hdr_file = './temp_dicom.txt';
        end
        
        fid = fopen(hdr_file);
        line = fgetl(fid);
        while line ~= -1
            
            % Check if this line is empty
            if ~isempty(strfind(line, '<scandate>')) || ~isempty(strfind(line, 'ID Study Date'))
                % Determine the date that the scan was performed. Do this by reading
                % the hdr file created
                
                % Pull out the string
                if ~isempty(strfind(line, '<scandate>'))
                    scan_date_str{participant_counter} = line(strfind(line, '<scandate>') + 10:strfind(line, '</scandate>') - 1);
                else
                    temp = line(strfind(line, 'ID Study Date') + 15:end);
                    % Add hyphens to make it of the same form
                    scan_date_str{participant_counter} = [temp(1:4), '-', temp(5:6), '-', temp(7:8)];
                end
                    
                % Convert to a number
                scan_date(participant_counter) = datenum(scan_date_str{participant_counter});
                
                % What day were they scanned?
                [day_num, day_name] = weekday(scan_date_str{participant_counter});
                scan_day_str{participant_counter} = day_name;
                scan_day(participant_counter) = day_num;
                
                
            elseif ~isempty(strfind(line, '<scantime>')) || ~isempty(strfind(line, 'ID Study Time'))
                
                % Pull out the string
                if ~isempty(strfind(line, '<scantime>'))
                    scan_time_str{participant_counter} = line(strfind(line, '<scantime>') + 10:strfind(line, '</scantime>') - 1);
                else
                    temp = line(strfind(line, 'ID Study Time') + 15:end);
                    % Add hyphens to make it of the same form
                    scan_time_str{participant_counter} = [temp(1:2), ':', temp(3:4), ':', temp(5:6)];
                end
                
                % Convert to a number
                scan_time(participant_counter) = datenum(scan_time_str{participant_counter});
                
            elseif ~isempty(strfind(line, '<sex>')) || ~isempty(strfind(line, 'PAT Patient Sex'))
                
                % Pull out the string
                if ~isempty(strfind(line, '<sex>'))
                    ppt_sex_str{participant_counter} = line(strfind(line, '<sex>') + 5:strfind(line, '</sex>') - 1);
                else
                    ppt_sex_str{participant_counter} = line(strfind(line, 'PAT Patient Sex') + 17:end -1);
                end
                
                ppt_sex(participant_counter) = strcmp(ppt_sex_str{participant_counter}, 'F');
                
            end
            
            line = fgetl(fid);
        end
    else
        if ~isempty(strfind(ppt, 'dev02')) || ~isempty(strfind(ppt, 'FAS'))
            warning('bxh file not found in data/nifti/ folder. Cannot get the background info');
        else
            fprintf('Error running dicom_hdr, check that it is loaded into your environment\nAborting\n');
        end
        scan_date(participant_counter) = nan;
        scan_date_str{participant_counter} = '';
        
        scan_time(participant_counter) = nan;
        scan_time_str{participant_counter} = '';
        
        ppt_sex{participant_counter} = nan;
        ppt_sex_str{participant_counter} = '';
        
        scan_day{participant_counter} = nan;
        scan_day_str{participant_counter} = '';
    end
    
%     % Exclude participants that were scanned with the old protocol
%     if all(run_functional_TR==1.5)
%         Included_participants(participant_counter)=0;
%     end
    
    % Convert to minutes
    Total_functional_duration(participant_counter)=Total_functional_duration(participant_counter)/60;
    Exp_Menu_Duration(participant_counter)=Exp_Menu_Duration(participant_counter)/60;
    Anatomical_duration(participant_counter) = Anatomical_duration(participant_counter)/60;
    Motion_excluded_duration(participant_counter) = Motion_excluded_duration(participant_counter) / 60;
    Eye_excluded_duration(participant_counter) = Eye_excluded_duration(participant_counter) / 60;
    Ignored_block_duration(participant_counter) = Ignored_block_duration(participant_counter)/60;
    Ignored_run_duration(participant_counter) = Ignored_run_duration(participant_counter)/60;
    Included_functional_duration(participant_counter) = Included_functional_duration(participant_counter)/60;
    Asleep_duration(participant_counter) = Asleep_duration(participant_counter) / 60;
    Scout_duration(participant_counter) = Scout_duration(participant_counter) / 60;
    
    %% Quantify the data at second level, specifically how much is available for analysis
    
    % Check if this participant contributed any experiments to secondlevel
    Secondlevel_Experiments(participant_counter)=length(dir('analysis/secondlevel_*'));
    
    functional = sprintf('analysis/secondlevel/default/func2highres.nii.gz', ppt);
    if exist(functional) > 0
        
        % Load the functional data information
        command=sprintf('fslval %s dim4', functional);
        [~, TR_number]=unix(command);
        
        command=sprintf('fslval %s pixdim4', functional);
        [~, TR_duration]=unix(command);
        
        TR_duration = str2num(TR_duration);
        if TR_duration > 1000
            TR_duration=TR_duration/1000;
        end
        
        % Store the duration of the data that made it to second level
        Secondlevel_duration(participant_counter) = (str2num(TR_number) * TR_duration);
        
    end
    
end

% Add the no data participants on to the end
if length(no_data_participants) > 0
    Exp_Menu_Duration(end-(size(no_data_participants, 1) - 1):end)=cell2mat(no_data_participants(:, 3));
end
%% Make the plots

% Figure out some more summary information
Not_scanning_duration=Exp_Menu_Duration-(Anatomical_duration+Total_functional_duration);

% Which participants are used
Included_participants=ones(ppt_num, 1);
Included_participants=logical(Included_participants);

% Sum up all of the functional data
Summed_total = Motion_excluded_duration + Eye_excluded_duration + Ignored_block_duration + Ignored_run_duration + Asleep_duration + Included_functional_duration;

% See how different the actual TR quantity is from the number you surmised
duration_difference = Total_functional_duration - Summed_total;
fprintf('Duration difference between reported and actual TR durations: %0.2f\nThis ought to be less than 0.5 minutes because of burn in and burn out\n\n', mean(abs(duration_difference)));

% Add the difference on to the included time
Included_functional_duration = duration_difference + Included_functional_duration;

% Identify the age of the participants
participants=Choosen_Participants(find(Included_participants(1:end-size(no_data_participants, 1)) == 1));
for participant_counter=1:length(participants)
    idx=find(strcmp(Participant_Info(:,1), participants{participant_counter}) == 1);
    age(participant_counter)=Participant_Info{idx,3};
end

%Add the age of the no data participants
if length(no_data_participants) > 0
    age(end+1:end+size(no_data_participants,1)) = cell2mat(no_data_participants(:, 2));
    
    % Add the no data participant names
    participant_names = [Choosen_Participants, no_data_participants(:,1)'];
else
    participant_names = Choosen_Participants;
end


%% Set up how to reorder participants
ppt_idxs=find(Included_participants==1);

% Order the participants by the specified variable
var_names = {'age', 'scan_date', 'scan_time', 'ppt_sex', 'scan_day'};
vars = {age, scan_date, scan_time, ppt_sex, scan_day};

% Plot the non-scanner time
if plot_non_scanner_time == 1
    y_max = 80;
else
    y_max = 50;
end

for var_counter = 1:length(vars)
    
    % Pull out variables
    var = vars{var_counter};
    var_name = var_names{var_counter};
    
    [~, ordered]=sort(var);
    ordered_idxs.(var_name)=ppt_idxs(ordered);
    
    % Stack all of the data in the order specified
    if plot_non_scanner_time == 1
        stacked_data.(var_name) = [Included_functional_duration(ordered_idxs.(var_name)), Asleep_duration(ordered_idxs.(var_name)), Anatomical_duration(ordered_idxs.(var_name)), Scout_duration(ordered_idxs.(var_name)), Motion_excluded_duration(ordered_idxs.(var_name)), Eye_excluded_duration(ordered_idxs.(var_name)), Ignored_block_duration(ordered_idxs.(var_name)), Ignored_run_duration(ordered_idxs.(var_name)), Not_scanning_duration(ordered_idxs.(var_name))];
    else
        stacked_data.(var_name) = [Included_functional_duration(ordered_idxs.(var_name)), Asleep_duration(ordered_idxs.(var_name)), Anatomical_duration(ordered_idxs.(var_name)), Scout_duration(ordered_idxs.(var_name)), Motion_excluded_duration(ordered_idxs.(var_name)), Eye_excluded_duration(ordered_idxs.(var_name)), Ignored_block_duration(ordered_idxs.(var_name)), Ignored_run_duration(ordered_idxs.(var_name))];
    end
end

stacked_labels={'Included TRs',  'Asleep functional', 'Anatomical', 'Scouts',  'Motion TRs', 'Eye movement TRs', 'Ignored block', 'Ignored run', 'Not scanning'};

% Cycle through the participants and store the stacked data along with the
% labels
for ppt_counter = 1:length(ordered_idxs.age)
    ppt_name = participant_names(ordered_idxs.age(ppt_counter));
    
    analysis_dir = sprintf('%s/subjects/%s/analysis/Behavioral/', proj_dir, ppt_name{1});
    
    % Pull out this participant's data and save it
    if isdir(analysis_dir)
        
        ppt_stacked_data = stacked_data.age(ppt_counter, :);
        save([analysis_dir, 'ppt_stacked_data'], 'ppt_stacked_data', 'stacked_labels');
    else
        fprintf('%s does not have analysis folder\n');
    end
end


% Find matching participant identities in the list of participant names
unique_ppt_counter=1;
ppt_roots={};
ppt_id=[];
for ppt_name = participant_names
    
    % Find the matching row number
    row=find(strcmp(Participant_Info(:,1), ppt_name));
    
    % If the name is not in the 1st column then assume that the name is
    % already the mat name
    if ~isempty(row)
        % Pull out the matlab root name
        mat_name=Participant_Info{row, 2};
    else
        mat_name=ppt_name{1};
    end
    
    underscore_idx = strfind(mat_name, '_');
    if ~isempty(underscore_idx)
        ppt_root = mat_name(1:underscore_idx-1);
    else
        ppt_root = mat_name;
    end

    % Is this root unique? If so, increment the counter, if not then
    % use the idx supplied
    match_idx = find(strcmp(ppt_roots, ppt_root));

    % Is it new? If so, increment the counter, if not then
    % use the idx supplied
    if isempty(match_idx)
        ppt_id(end+1) = unique_ppt_counter;
        unique_ppt_counter=unique_ppt_counter+1;
        ppt_roots{end+1} = ppt_root;
    else
        ppt_id(end+1) = match_idx;
    end
    
end

%Specify the color pallete. First do greens and then reds and then grey
bar_colors = [0, 90, 0; ...
	31, 150, 0; ...
	38, 200, 0; ...
	0, 255, 0; ...
	255, 211, 8; ...
	207, 113, 0; ...
    255, 40, 16; ...
	191, 30, 12; ...    
	200, 200, 200] ./ 255;

% Plot the stacked data
figure
h=bar(stacked_data.age, 'stacked');
for h_counter =1:length(h)
    set(h(h_counter), 'FaceColor', bar_colors(h_counter, :), 'EdgeColor', 'none');
end

legend(stacked_labels)
set(gca, 'XTick', [1:length(ordered_idxs.age)], 'XTickLabel', participant_names(ordered_idxs.age))
xtickangle(90);
ylim([0, y_max]);
ylabel('Minutes');
saveas(gcf, sprintf('%s/bar_stacked.eps', output_dir),'epsc');
saveas(gcf, sprintf('%s/bar_stacked.png', output_dir));
saveas(gcf, sprintf('%s/bar_stacked.fig', output_dir));

set(gca, 'XTick', [1:length(ordered_idxs.age)], 'XTickLabel', round(age(ordered_idxs.age)));
xtickangle(0);
saveas(gcf, sprintf('%s/bar_stacked_age.eps', output_dir),'epsc');
saveas(gcf, sprintf('%s/bar_stacked_age.png', output_dir));
saveas(gcf, sprintf('%s/bar_stacked_age.fig', output_dir));

% If there are fewer than 24 ppts then use this
if max(ppt_id) <= 24
    set(gca, 'XTick', [1:length(ordered_idxs.age)], 'XTickLabel', char(64 + ppt_id(ordered_idxs.age)));
else
    set(gca, 'XTick', [1:length(ordered_idxs.age)], 'XTickLabel', ppt_id(ordered_idxs.age));
end
xtickangle(0);
ylim([0, y_max]);
saveas(gcf, sprintf('%s/bar_stacked_matched.eps', output_dir),'epsc');
saveas(gcf, sprintf('%s/bar_stacked_matched.png', output_dir));
saveas(gcf, sprintf('%s/bar_stacked_matched.fig', output_dir));

% Plot the age correlation with included functional data
figure
scatter(age(ordered_idxs.age), stacked_data.age(:, 1)); 
xlabel('Age');
ylabel('Minutes of included functional');
saveas(gcf, sprintf('%s/scatter_included_functional_age.eps', output_dir),'epsc');
saveas(gcf, sprintf('%s/scatter_included_functional_age.png', output_dir));

% Plot the stacked data ordered by date of scan
figure
h=bar(stacked_data.scan_date, 'stacked');
for h_counter =1:length(h)
    set(h(h_counter), 'FaceColor', bar_colors(h_counter, :), 'EdgeColor', 'none');
end

legend(stacked_labels)
set(gca, 'XTick', [1:length(ordered_idxs.scan_date)], 'XTickLabel', scan_date_str(ordered_idxs.scan_date))
xtickangle(90);
ylim([0, y_max]);
ylabel('Minutes');
saveas(gcf, sprintf('%s/bar_stacked_date.eps', output_dir),'epsc');
saveas(gcf, sprintf('%s/bar_stacked_date.png', output_dir));
saveas(gcf, sprintf('%s/bar_stacked_date.fig', output_dir));

% Plot the stacked data ordered by time of scan
figure
h=bar(stacked_data.scan_time, 'stacked');
for h_counter =1:length(h)
    set(h(h_counter), 'FaceColor', bar_colors(h_counter, :), 'EdgeColor', 'none');
end

legend(stacked_labels)
set(gca, 'XTick', [1:length(ordered_idxs.scan_time)], 'XTickLabel', scan_time_str(ordered_idxs.scan_time))
xtickangle(90);
ylabel('Minutes');
ylim([0, y_max]);
saveas(gcf, sprintf('%s/bar_stacked_time.eps', output_dir),'epsc');
saveas(gcf, sprintf('%s/bar_stacked_time.png', output_dir));
saveas(gcf, sprintf('%s/bar_stacked_time.fig', output_dir));

% Plot the stacked data ordered by sex
figure
h=bar(stacked_data.ppt_sex, 'stacked');
for h_counter =1:length(h)
    set(h(h_counter), 'FaceColor', bar_colors(h_counter, :), 'EdgeColor', 'none');
end

legend(stacked_labels)
set(gca, 'XTick', [1:length(ordered_idxs.ppt_sex)], 'XTickLabel', ppt_sex_str(ordered_idxs.ppt_sex))
xtickangle(90);
ylim([0, y_max]);
ylabel('Minutes');
saveas(gcf, sprintf('%s/bar_stacked_sex.eps', output_dir),'epsc');
saveas(gcf, sprintf('%s/bar_stacked_sex.png', output_dir));
saveas(gcf, sprintf('%s/bar_stacked_sex.fig', output_dir));

% Report the mean, SD and N of each condition being considered
fprintf('ppt_sex useable functional data\n');
idx_data_all = {};
for idx_type = unique(ppt_sex_str)
    
    ppt_idxs = strcmp(ppt_sex_str(ordered_idxs.ppt_sex), idx_type);
    idx_data = stacked_data.ppt_sex(ppt_idxs, 1);
    
    fprintf('%s; M: %0.2f, SD: %0.2f, N: %0.2f\n', idx_type{1}, mean(idx_data), std(idx_data), length(idx_data));
    
    idx_data_all{end+1} = idx_data;
end
    

% Plot the stacked data ordered by day of scan
figure
h=bar(stacked_data.scan_day, 'stacked');
for h_counter =1:length(h)
    set(h(h_counter), 'FaceColor', bar_colors(h_counter, :), 'EdgeColor', 'none');
end

legend(stacked_labels)
set(gca, 'XTick', [1:length(ordered_idxs.scan_day)], 'XTickLabel', scan_day_str(ordered_idxs.scan_day))
xtickangle(90);
ylim([0, y_max]);
ylabel('Minutes');
saveas(gcf, sprintf('%s/bar_stacked_day.eps', output_dir),'epsc');
saveas(gcf, sprintf('%s/bar_stacked_day.png', output_dir));
saveas(gcf, sprintf('%s/bar_stacked_day.fig', output_dir));

% Report the mean, SD and N of each condition being considered
fprintf('Scan day useable functional data\n');
for idx_type = unique(scan_day_str)
    
    ppt_idxs = strcmp(scan_day_str(ordered_idxs.scan_day), idx_type);
    idx_data = stacked_data.scan_day(ppt_idxs, 1);
    
    fprintf('%s; M: %0.2f, SD: %0.2f, N: %0.2f\n', idx_type{1}, mean(idx_data), std(idx_data), length(idx_data));
    
end
    
%% Plot the data acquisition rate per quarter since 2016
dates = scan_date_str(ordered_idxs.scan_date);
start_date = 2016;

% What is the current quarter?
today = datestr(now, 'mm yyyy');
current_quarter = ((str2num(today(4:7)) - start_date) * 4) + (ceil(str2num(today(1:2)) / 3));

quarter_count = zeros(current_quarter,1);
for date_str = dates
    
    % Pull out the year and month as a number
    year=str2num(date_str{1}(1:4));
    month=str2num(date_str{1}(6:7));
    
    quarter = ((year-start_date) * 4) + ceil(month / 3);
    
    % Increment the current total
    quarter_count(quarter) = quarter_count(quarter) + 1;
    
end

% Create the quarter labels
for quarter = 1:current_quarter
    quarter_label{quarter} = sprintf('%d Q%d', floor((quarter - 0.1) / 4) + start_date - 2000, quarter - (floor((quarter - 0.1)/4) * 4));
end

% Plot the figure
figure
hold on
%plot(quarter_count) 
plot(cumsum(quarter_count));
xticklabels(quarter_label(2:2:current_quarter));
xticks(2:2:current_quarter);
ylabel('Total participants');
xlabel('Quarter');

% % Add a line for princeton and FAS
% plot([6,6], [0, max(quarter_count)], 'r');
% plot([12,12], [0, max(quarter_count)], 'r');
% hold off

saveas(gcf, sprintf('%s/ppts_per_quarter.eps', output_dir),'epsc');
saveas(gcf, sprintf('%s/ppts_per_quarter.png', output_dir));
saveas(gcf, sprintf('%s/ppts_per_quarter.fig', output_dir));

%% Calculate the change over different sessions

% What is the proportion included? Ignore the sleeping epochs since that
% could be avoided
plot_age = 1; % Do you want to plot the x axis as nth session or as age?
ordered_age = age(ordered_idxs.age);
for analysis_type = 1:2
    
    % Specify whether are using the proportion included or minutes included
    if analysis_type == 1
        dv = stacked_data.age(:, 1);
    elseif analysis_type ==2
        dv = stacked_data.age(:, 1) ./ sum(stacked_data.age(:, [1, 5:8]), 2);
    end
    
    % Pull out the unique ppt ids
    unique_ids = unique(ppt_id(ordered_idxs.age));
    
    % Cycle through each participant and then create labels for what session is
    % their nth
    figure
    hold on
    nth_session = zeros(length(ppt_id), 1);
    for id = unique_ids
        
        % What match indexes
        matched_idxs = find(ppt_id(ordered_idxs.age) == id);
        
        % Put the nth session
        for counter = 1:length(matched_idxs)
            nth_session(matched_idxs(counter)) = counter;
        end
        
        % Plot a line connecting these sessions
        if plot_age == 1
            plot(ordered_age(matched_idxs), dv(matched_idxs), 'k-');
        else
            plot(1:length(matched_idxs), dv(matched_idxs), 'k-');
        end
    end
    
    scatter(ordered_age, dv);
    hold off
    if plot_age == 1
        xlabel('Age');
    else
        xlabel('nth session');
    end
    ylabel('Functional data');
    
    if analysis_type == 1
        analysis_name = 'nth_session_minutes_functional';
    elseif analysis_type == 2
        analysis_name = 'nth_session_included_functional';
    end
        
    saveas(gcf, sprintf('%s/%s.eps', output_dir, analysis_name),'epsc');
    saveas(gcf, sprintf('%s/%s.png', output_dir, analysis_name));
    saveas(gcf, sprintf('%s/%s.fig', output_dir, analysis_name));
    
end

% Calculate the performance for each age bins, separated out for
% participants who have done multiple sessions. 
% This doesn't control for whether they have done multiple sessions

bin_size = 6; % How many months wide is the age gap
for age_counter = 1:3
    
    min_age = 3 + ((age_counter -1) * bin_size);
    max_age = 3 + (age_counter * bin_size);
    
    usable_idxs = ((ordered_age > min_age) .* (ordered_age < max_age)) == 1;
    
    figure
    scatter(nth_session(usable_idxs), stacked_data.age(usable_idxs, 1))
    xlim([1, 8]);
    xlabel('Session counter');
    ylabel('Minutes');
    
    age_r = corr(nth_session(usable_idxs), stacked_data.age(usable_idxs, 1));
    
    title(sprintf('%d to %d months. r=%0.2f', min_age, max_age, age_r));
    
    saveas(gcf, sprintf('%s/binned_retention_session.eps', output_dir),'epsc');
    saveas(gcf, sprintf('%s/binned_retention_session.png', output_dir));
    saveas(gcf, sprintf('%s/binned_retention_session.fig', output_dir));
end

% Find participants that have done both a first and a second session and
% then compare those groups for different age ranges
[session_count, ~] = hist(ppt_id(ordered_idxs.age), length(unique_ids));
first_sessions = [];
second_sessions = [];
early_session_num=1;
later_session_num=2;
for ppt_counter = 1:length(ordered_idxs.age)
    
    % What participant id is this idx
    ppt = ppt_id(ordered_idxs.age(ppt_counter));
    
    % Only continue if this ppt has at least two sessions
    if session_count(ppt) >= later_session_num
        
        % Is this the first session or second?
        if nth_session(ppt_counter) == early_session_num
            
            first_sessions(end+1) = ppt_counter;
        elseif nth_session(ppt_counter) == later_session_num
            
            second_sessions(end+1) = ppt_counter;
        end   
    end
    
end    

% Make the data for this (so that you can subsample later)
first_session_ages = ordered_age(first_sessions);
first_session_data = stacked_data.age(first_sessions, 1);

second_session_ages = ordered_age(second_sessions);
second_session_data = stacked_data.age(second_sessions, 1);

% Plot the first and second session
min_age_band = 5;
max_age_band = 8.9;
figure
hold on
scatter(first_session_ages, first_session_data);
scatter(second_session_ages, second_session_data);
plot([min_age_band,min_age_band], [0, max(second_session_data)], 'k');
plot([max_age_band,max_age_band], [0, max(second_session_data)], 'k');
legend({'First', 'Second'});
xlabel('Months');
ylabel('Minutes');
hold off  
title('Minutes included for first and second sessions');

saveas(gcf, sprintf('%s/first_second_session_minutes.eps', output_dir),'epsc');
saveas(gcf, sprintf('%s/first_second_session_minutes.png', output_dir));
saveas(gcf, sprintf('%s/first_second_session_minutes.fig', output_dir));

% In the 5-9 month age range there are many participants who had both a
% first and second session
first_age_band_idxs = ((first_session_ages > min_age_band) .* (first_session_ages < max_age_band)) == 1;
second_age_band_idxs = ((second_session_ages > min_age_band) .* (second_session_ages < max_age_band)) == 1;

[~, p_val, ~, stats] = ttest2(second_session_data(second_age_band_idxs), first_session_data(first_age_band_idxs));

fprintf('Age band: %0.1f to %0.1f. First session mean age: %0.2f (N=%d), second session mean age: %0.2f (N=%d)\n', min_age_band, max_age_band, mean(first_session_ages(first_age_band_idxs)), sum(first_age_band_idxs), mean(second_session_ages(second_age_band_idxs)), sum(second_age_band_idxs));
fprintf('Second session > first session. M: %0.2f, t=%0.2f, p=%0.3f\n', mean(second_session_data(second_age_band_idxs)) - mean(first_session_data(first_age_band_idxs)), stats.tstat, p_val);

%% Wrap up

% Save all of the data
save(sprintf('%s/summary.mat', output_dir));

%Report summary results

averaged_data = mean(stacked_data.age);

fprintf('Total number of unique participants: %d; number of sessions: %d; max per participant: %d\nMean age: %0.2f; std: %0.2f\n', length(ppt_roots), length(participant_names), sum(mode(ppt_id)==ppt_id), mean(age), std(age));

fprintf('\nSummary of results (in minutes)\n---------------------\n\nIncluded func: %0.2f\nResting state: %0.2f\nIncluded anat: %0.2f\nScouts: %0.2f\nMotion excl: %0.2f\nEye excl: %0.2f\nIgnored block: %0.2f\nIgnored run: %0.2f\nNot scanning: %0.3f\n\n\n', averaged_data);

fprintf('Proportion of usable data (awake + anatomical + scouts): %0.3f or %0.2f minutes\n\n', sum(averaged_data([1, 3, 4]))/sum(averaged_data), sum(averaged_data([1, 3, 4])));

fprintf('Proportion of functional data that is awake and usable: %0.3f\n\n', sum(averaged_data(1))/sum(averaged_data([1,2,5,6,7,8])));

fprintf('Number of participants with at least one experiment at second level: %d out of %d\n\n', sum(Secondlevel_Experiments > 0), length(Secondlevel_Experiments));


%Return to the root
cd ../../




