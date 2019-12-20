%% ICA_Motion_Detector
%
% Looks inside the feat directories to find the Independent Component
% Analysis folder and pulls out the time course of each IC, comparing it to
% the motion.
%
% SubmitJobs is a boolean about whether to submit the jobs for running
%
% The correlation threshold for exclusion of an IC can be be specified as
% an input
%
% The FeatFolder input specifies just one Featfolder to have this analysis
% run on, if specified. Provide the full path
%
% The motion is specified by either the MotionMetric.txt or the
% MotionParameters.par.
%
% First created by C Ellis 2/23/17

function ICA_Motion_Detector(SubmitJobs, Correlation_Threshold, CurrentDir)


% Set the threshold for excluding the component
if nargin==0
    SubmitJobs=0;
    Correlation_Threshold=0.5;
    CurrentDir=0;
end

% Convert inputs
if isstr(SubmitJobs)
    SubmitJobs=str2num(SubmitJobs);
end

if isstr(Correlation_Threshold)
    Correlation_Threshold=str2num(Correlation_Threshold);
end

if isstr(CurrentDir)
    CurrentDir=str2num(CurrentDir);
end

fprintf('Using a threshold of %0.3f', Correlation_Threshold)

%What do you want to use as your motion parameter? MotionMetric (1) or the
%MotionParameters (0)
MotionMetric=0;

% Specify where the files are

if CurrentDir==0
    confound_dir='analysis/firstlevel/Confounds';
    analysis_dir='analysis/firstlevel/';
    Feat_Dir=dir([analysis_dir, 'functional*.feat']);
else
    
    % Assume that the files are in the confound folder of this participant
    Feat_Dir(1).name=pwd;
    confound_dir=[Feat_Dir(1).name(1:strfind(Feat_Dir(1).name,'analysis/')+8), 'firstlevel/Confounds/'];
end


% Iterate through each of the functional feats (or only the one that was
% supplied)
for Feat_Counter=1:length(Feat_Dir)
    
    % Check there is an ICA folder
    if exist([Feat_Dir(Feat_Counter).name, '/filtered_func_data.ica/'])~=0
        
        %What is the confound value for this functional run
        FuncName=Feat_Dir(Feat_Counter).name(strfind(Feat_Dir(Feat_Counter).name, 'functional')+10:strfind(Feat_Dir(Feat_Counter).name, 'functional')+11);
        
        if MotionMetric==1
            Motion_Timecourse=dlmread([confound_dir, sprintf('/MotionMetric_%s.txt', FuncName)]);
        else
            Motion_Timecourse=dlmread([confound_dir, sprintf('/MotionParameters_functional%s.par', FuncName)]);
        end
        
        %What is the folder containing the ICA
        IC_folder=[Feat_Dir(Feat_Counter).name, '/filtered_func_data.ica/report/'];
        
        %What are the names of the IC timecourses
        IC_Timecourse_names=dir([IC_folder, 't*.txt']);
        
        % Iterate through all of the ICs
        ExcludedICs=[];
        Timecourse_Correlations=[];
        for IC_Counter=1:length(IC_Timecourse_names)
            
            %Pull out what IC this is you are considering
            IC_Name=IC_Timecourse_names(IC_Counter).name;
            IC_Number=str2num(IC_Name(2:strfind(IC_Name, '.')));
            
            %Read in the IC
            IC_Timecourse=dlmread([IC_folder, IC_Name]);
            
            %What is the correlation between these confounds
            Timecourse_Correlation=corr(IC_Timecourse, Motion_Timecourse);
            
            %Store these correlations
            Timecourse_Correlations(IC_Counter,:)=Timecourse_Correlation;
            
            %If (any of) the correlation exceeds the threshold then exclude this IC
            if any(abs(Timecourse_Correlation) > Correlation_Threshold)
                ExcludedICs(end+1)=IC_Number;
            end
        end
        
        %Create a plot of the distribution of correlations
        hist(Timecourse_Correlations(:));
        xlabel('Correlation');
        title('Distribution of correlations between motion and IC timecourse');
        saveas(gcf, [IC_folder, 'Distribution_of_motion_correlations.fig']);
        
        %Re order the ICs
        ExcludedICs=sort(unique(ExcludedICs));
        
        %Report which ICs to exclude
        if length(ExcludedICs)>0
            Components=sprintf('%d,', ExcludedICs); Components=Components(1:end-1);
            fprintf('\nTimepoints recommended for exclusion for %s:\nComponents=%s\n', Feat_Dir(Feat_Counter).name, Components);
            
            Command=sprintf('fsl_regfilt -i %s/filtered_func_data -o %s/filtered_func_data_ica_auto -d %s/filtered_func_data.ica/melodic_mix -f "%s"\n', [Feat_Dir(Feat_Counter).name], [Feat_Dir(Feat_Counter).name], [Feat_Dir(Feat_Counter).name], Components);
            if SubmitJobs==0
                fprintf('\nRecommended command:\n%s\n', Command);
            else
                fprintf('\nRunning:\n%s\n', Command);
                unix(Command);
                
                % Rename functionals
                fprintf('\nRenaming filtered_funcs_replacing original with ICA version\n');
                if exist([Feat_Dir(Feat_Counter).name, '/filtered_func_data_original.nii.gz'])==0
                    unix(sprintf('yes | cp %s %s', [Feat_Dir(Feat_Counter).name, '/filtered_func_data.nii.gz'], [Feat_Dir(Feat_Counter).name, '/filtered_func_data_original.nii.gz']));
                end
                unix(sprintf('yes | cp %s %s', [Feat_Dir(Feat_Counter).name, '/filtered_func_data_ica_auto.nii.gz'], [Feat_Dir(Feat_Counter).name, '/filtered_func_data.nii.gz']));
            end
        else
            fprintf('\nNo timepoints recommended for exclusion in %s\n', Feat_Dir(Feat_Counter).name);
        end
        
    end
end


