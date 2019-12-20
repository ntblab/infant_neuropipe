function Aggregate_FIR(Masktype, experiment, min_blocks, varargin)
%Aggregate the FIR analyses for runs/sessions that meet certain criteria
%
% To specify the mask, use the suffix of the FIR files
% (FIR_data_Masktype_${MaskName})
%
% experiment takes in either an experiment name (which the timing files at
% first level must match) or a number that specifies the number of
% evs that are being modelled
% 
% min_blocks specifies the minimum number of blocks required per session
% for a participant to be included in the average
%
% The different mask types are: 
% 0: use the univariate results as a mask, 
% 1: Make a pseudo occipital mask by taking the first 20 voxels of the y
% dim in functional space.
% 2: Exclude voxels below a variance threshold hold and then use
% the back of the brain, 
% 3: take the highest pe values
% $PATHNAME: If the variable is a name then this will be the mask loaded in
% for selection
%
% varagrin is input in to Participant_Index so you can use it for
% exclusion.
%
% C Ellis 7/25/18

if nargin==0
    Masktype='2';
    experiment='';
    min_blocks='0';
end

% Convert this to a number if it is one
if isstr(experiment)
    if all(isstrprop(experiment, 'digit'))
        experiment=str2num(experiment);
    end
end

% addpath scripts
% globals_struct=read_globals; % Load the content of the globals folder
% addpath([globals_struct.PACKAGES_DIR, '/NiFTI_Tools/'])

%Identify the participants
[participants, ParticipantList]=Participant_Index(varargin);

% Make the output name
output_name='';
for argcounter=1:length(varargin)
    if iscell(varargin{argcounter})
        for cellcounter=1:length(varargin{argcounter})
            output_name=[output_name, '_', varargin{argcounter}{cellcounter}];
        end
    else
        output_name=[output_name, '_', num2str(varargin{argcounter})];
    end
end

fprintf('Output name will be: %s\n', output_name);

exploration_dir='analysis/firstlevel/Exploration/';

% Find all of the participant runs that have the specific number of
% regressors specified
pe_z_all=struct;
ppts={};
for participant_counter = 1:length(participants)
    
    % Get this participant that matches
    participant = participants{participant_counter};
    
    % Iterate through the functionals
    if length(dir(sprintf('subjects/%s/%s/functional*_fir.feat/', participant, exploration_dir))) > 0
        try
            functionals = strsplit(ls(sprintf('subjects/%s/%s/functional*_fir.feat/FIR_data_Masktype_%s.mat', participant, exploration_dir, Masktype)));
            functional_num = sum(cellfun(@length, strsplit(ls(sprintf('subjects/%s/%s/functional*_fir.feat/FIR_data_Masktype_%s.mat', participant, exploration_dir, Masktype)))) > 0);
            functionals = functionals(1:functional_num);
        catch
            functionals=[];
        end
    else
        functionals = [];
    end
    
    for functional_counter=1:length(functionals)
        
        % Pull out the func run number
        start_idx=strfind(functionals{functional_counter}, 'functional') + 10;
        end_idx = strfind(functionals{functional_counter}, '_fir') - 1;
        func_run=functionals{functional_counter}(start_idx:end_idx);
        
        % Pul out the FIR data
        load(functionals{functional_counter}, 'pe_z');
        load(functionals{functional_counter}, 'masked_pe');
        load(functionals{functional_counter}, 'masked_averaged');
        load(functionals{functional_counter}, 'masked_psc_pe');
        load(functionals{functional_counter}, 'design');
        
        %fprintf('%s, length %d\n\n', functionals{functional_counter}, length(pe_z));
        
        % Determine if you out to use this run
        use_run = 0;
        if all(isstrprop(experiment, 'digit'))
            % Does the number of regressors in this folder match the desired
            % number for this aggregation
            if str2num(experiment) == length(pe_z)
                use_run = 1;
            end
        else
           % Does this come from the experiment specified
           
           if length(dir(sprintf('subjects/%s/analysis/firstlevel/Timing/functional%s_%s*', participant, func_run, experiment))) > 0
               use_run = 1;
           end
        end
        
        if use_run == 1
            
            % Store the run
            ppts{end+1}=sprintf('%s_functional%s', participant, func_run);
            
            % Pull out the number of blocks from this timing file
            timing_file=textread(sprintf('subjects/%s/%s/functional%s.txt', participant, exploration_dir, func_run));
            
            % Store the values for that data
            if ~isfield(pe_z_all, ['ppt_', participant])
                pe_num = length(pe_z);
                pe_z_all.(['ppt_', participant])=pe_z;
                pe_all.(['ppt_', participant])=mean(masked_pe);
                averaged_all.(['ppt_', participant])=mean(masked_averaged);
                psc_pe_all.(['ppt_', participant])=mean(masked_psc_pe);
                design_all.(['ppt_', participant])=design;
                blocks_per_run.(['ppt_', participant])=sum(timing_file(:,3));
            else
                pe_z_all.(['ppt_', participant])(end+1, :)=pe_z(1:pe_num);
                pe_all.(['ppt_', participant])(end+1, :)=mean(masked_pe(:, 1:pe_num));
                averaged_all.(['ppt_', participant])(end+1, :)=mean(masked_averaged(:, 1:pe_num + 1));
                psc_pe_all.(['ppt_', participant])(end+1, :)=mean(masked_psc_pe(:, 1:pe_num));
                design_all.(['ppt_', participant])(end+1, :)=design(1:pe_num+1);
                blocks_per_run.(['ppt_', participant])(end+1)=sum(timing_file(:,3));
            end
        end
    end
end


% % Find matching participant identities in the list of participant names
% unique_ppt_counter=1;
% ppt_roots={};
% ppt_names={};
% ppt_id=[];
% for ppt_run_name = ppts
%     
%     % Pull out the ppt
%     ppt_name = ppt_run_name{1}(1:strfind(ppt_run_name{1}, '_functional')-1);
%     
%     % Store all of the unique fMRI names
%     match_idx = find(strcmp(ppt_names, ppt_name));
%     if isempty(match_idx)
%         ppt_names{end + 1} = ppt_name;
%     end
%     
%     % Find the matching row number
%     row=find(strcmp(ParticipantList(:,1), ppt_name));
%     
%     % If the name is not in the 1st column then assume that the name is
%     % already the mat name
%     if ~isempty(row)
%         % Pull out the matlab root name
%         mat_name=ParticipantList{row, 2};
%     else
%         mat_name=ppt_name;
%     end
%     
%     underscore_idx = strfind(mat_name, '_');
%     if ~isempty(underscore_idx)
%         ppt_root = mat_name(1:underscore_idx-1);
%     else
%         ppt_root = mat_name;
%     end
% 
%     % Is this root unique? If so, increment the counter, if not then
%     % use the idx supplied
%     match_idx = find(strcmp(ppt_roots, ppt_root));
% 
%     % Is it new? If so, increment the counter, if not then
%     % use the idx supplied
%     if isempty(match_idx)
%         ppt_id(end+1) = unique_ppt_counter;
%         unique_ppt_counter=unique_ppt_counter+1;
%         ppt_roots{end+1} = ppt_root;
%     else
%         ppt_id(end+1) = match_idx;
%     end
%     
% end
% 
% % Summarise the counts
% fprintf('Unique participants:\n');
% fprintf('%s\n', ppt_roots{:});
% fprintf('Unique sessions:\n');
% fprintf('%s\n', ppt_names{:});
% fprintf('Runs per session:\n');
% fprintf('%d\n', hist(ppt_id, length(ppt_roots)));

% Save data
savename=sprintf('results/Aggregate_FIR/FIR_average_%s_blocks_%s_%s%s', experiment, min_blocks, Masktype, output_name);
save(savename)


% Average the timecourses
if length(fieldnames(psc_pe_all)) > 0
    
    % Cycle through the variables
    for DV_counter =1:3
        
        if DV_counter==1
            DV=psc_pe_all;
            DV_name='_psc_pe';
            range=[-2, 2];
        elseif DV_counter==2
            DV=pe_all;
            DV_name='_pe';
            range=[-8, 8];
        elseif DV_counter==3
            DV=averaged_all;
            DV_name='_av';
            range=[600, 800];    
        end
        
        % Get all of the participant data and weight it in proportion to the
        % number of blocks
        fprintf('Total blocks per session:\n');
        pe_mean_ppt=[];
        for ppt = fieldnames(DV)'
            
            total_blocks=sum(blocks_per_run.(ppt{1}));
            
            if total_blocks >= str2num(min_blocks) && logical(isempty(pe_mean_ppt) || length(DV.(ppt{1})) >= size(pe_mean_ppt,2))
                
                % Pull out the useable values
                if ~isempty(pe_mean_ppt)
                    temp_DV = DV.(ppt{1})(:, 1:size(pe_mean_ppt,2));
                else
                    temp_DV = DV.(ppt{1});
                end
                    
                % Multiply the FIR data by the weight
                weights = repmat(blocks_per_run.(ppt{1}), size(temp_DV, 2), 1)' ./ total_blocks;
                pe_mean_ppt(end+1, :)=sum(temp_DV .* weights, 1);
                
                fprintf('Including %s with %d blocks across %d runs\n', ppt{1}, total_blocks, length(blocks_per_run.(ppt{1})));
                
            else
                fprintf('Not including %s because insufficient blocks: %d\n', ppt{1}, total_blocks);
            end
        end
        
        % Average across participants
        pe_mean=nanmean(pe_mean_ppt, 1);
        
        % Plot the different timecourses
        h=figure;
        hold on
        
        % Make error bars on the plots
        pe_error=nanstd(pe_mean_ppt)/sqrt(size(pe_mean_ppt,1));
        errorbar(1:length(pe_mean), pe_mean, pe_error, 'r', 'LineWidth',4)
        plot(pe_mean_ppt', 'k')
        
        % Create the design
        design_mean = mean(design_all.(ppt{1}), 1);
        design_mean = design_mean + (0-design_mean(1));
        design_mean = (design_mean/max(design_mean)) * max(pe_mean);
        plot(design_mean, 'g');
        
        title(sprintf('Averaged PE, MaskType=%s N=%d', Masktype, size(pe_mean_ppt, 1)));
        ylim(range);
        ylabel('Evoked response')
        xlabel('TRs from block onset')
        
        %Save
        saveas(h, [savename, DV_name], 'eps');
    end
else
    fprintf('No files found with the name: %s/functional*_fir.feat/FIR_data_Masktype_%s.mat\n\n', exploration_dir, Masktype)
end
