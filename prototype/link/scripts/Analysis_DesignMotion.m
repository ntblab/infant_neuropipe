%%Correlate the design matrix and the motion
%
% Iterate through each functional folder, pulling out the design matrix and
% correlating the task related activity with the motion activity. Report
% the correlations of each kind.
%
% C Ellis 12/7/16
function Analysis_DesignMotion

%What are the file names
AnalysisFolder='analysis/firstlevel/Exploration';
Files=dir(sprintf('%s/functional*_univariate.feat', AnalysisFolder));

%Iterate through the files
for FileCounter=1:length(Files)

    %What are the names of the folders that are useful
    FeatDir=sprintf('%s/%s', AnalysisFolder, Files(FileCounter).name);
    
    %Print the name so it is easier to keep track of what was done
    fprintf('Analyzing %s\n\n', FeatDir);    

    func_run = FeatDir(strfind(FeatDir, 'functional') + 10 :strfind(FeatDir, '_univariate') - 1);
    
    %What files will be generated
    designFile=sprintf('%s/design', FeatDir); %What is the design matrix of the univariate file
    
    %Read in the design matrix (edit it to be an appropriate format)
    %This might not work, if not then do it on the cluster
    Success=unix(sprintf('Vest2Text %s %s', [designFile, '.mat'], [designFile, '.txt']));
    
    if Success~=0
        warning('Could not run unix command. Try running on cluster. Quitting');
        return
    end
    
    designMat=textread([designFile, '.txt']);
    
    %If the last column is just zeros then remove it
    if all(designMat(:,end)==0)
        designMat=designMat(:,1:end-1);
    end
    
    %Assume that the first column represents the task activation and
    % the rest are confounds represent 
    task=designMat(:,1);
    
    % Pull out the motion parameters from the file
    motionParameters = textread(sprintf('analysis/firstlevel/Confounds/MotionParameters_functional%s.par', func_run));
    
    %What are the correlations of the task and motion parameters
    correlations=corr(task, motionParameters);
    
    % What is the best correlation
    [best_corr, best_corr_idx]=nanmax((abs(correlations)));
    notbest=setdiff(1:size(motionParameters,2), best_corr_idx);
    
    %Plot the normalized responses (showing the best in blue and the rest
    %in grey
    h=figure;
    hold on
    plot(zscore(motionParameters(:,notbest)), 'Color', [.7, .7, .7], 'LineWidth',1)
    plot(zscore(motionParameters(:,best_corr_idx)), 'b', 'LineWidth',5)
    plot(zscore(task), 'r', 'LineWidth',5)
    
    ylabel('Normalized parameter estimates')
    xlabel('TRs')
    title(sprintf('Correlations: max: %0.2f; mean: %0.2f', best_corr, nanmean(abs(correlations))))
    legend({'Task', 'MotionParameters'}, 'Location', 'SouthEast')
    
    %Save
    saveas(h, sprintf('%s/Motion_TaskCorrelation', FeatDir), 'png');
    saveas(h, sprintf('%s/Motion_TaskCorrelation', FeatDir), 'fig');
end
