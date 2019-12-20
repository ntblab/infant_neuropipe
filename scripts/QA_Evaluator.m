function [SNR, SFNR] = QA_Evaluator(varargin)
%
%Reads through the subject directory and pulls out all the SFNR and SNR information
%
%Created by C Ellis 0616

addpath scripts
Subject_Dir='subjects/';
savelocation='analysis/QA/';

SNR=NaN;
SFNR=NaN;

% What are the subjects to be used
[SubjectNames, ParticipantList]=Participant_Index(varargin);

% Make the output name
output_name='';
for argcounter=1:nargin
    output_name=[output_name, '_', num2str(varargin{argcounter})];
end

Motion_average=zeros(length(SubjectNames),1);
SFNR_Difference=zeros(length(SubjectNames),1);
for SubjectCounter=1:length(SubjectNames)
    
    BaseExt=[Subject_Dir, SubjectNames{SubjectCounter}, '/data/'];
    
    RunNumber=length(dir([BaseExt, 'nifti/' SubjectNames{SubjectCounter}, '_functional*.nii.gz']));
    
    % Find the participant age
    idx=find(not(cellfun('isempty', strfind(ParticipantList(:,1), SubjectNames{SubjectCounter})))); %What is this participant's age
    
    if isempty(idx)
        fprintf('Participant %s age is not specified. Aborting!', SubjectNames{SubjectCounter});
        return
    end
    
    %Store the participant age
    AgeList(SubjectCounter)=ParticipantList{idx,3};
    
    %Iterate through the runs
    for RunCounter = 1:length(ParticipantList{idx,5})
        
        SNR(SubjectCounter, RunCounter)=ParticipantList{idx,5}(RunCounter);
        SFNR(SubjectCounter, RunCounter)=ParticipantList{idx,6}(RunCounter);
        
        %Get the motion data for this run
        if RunCounter<9
            RunName=['0', num2str(RunCounter)];
        else
            RunName=num2str(RunCounter);
        end
        
        filename=[Subject_Dir, SubjectNames{SubjectCounter}, '/analysis/firstlevel/Confounds/MotionMetric_fslmotion_6_functional', RunName, '.txt'];
        
        % Try pull out and save the motion parameters and store them in a
        % cell
        try
            Motion_run=textread(filename);
            Motion_all{SubjectCounter, RunCounter}=Motion_run(:,1);
            Motion_average(SubjectCounter, RunCounter)=mean(Motion_run(:,1));
            
        catch
            fprintf('%s does not exist\n', filename)
        end
        
        % If it exists, find the sfnr volume generated in QA. Then use the
        % corresponding mask in the feat folder to identify whether
        % activity differs in frontal regions
        
        sfnr_name=sprintf('%s/qa/sfnr_%s_functional%s.nii.gz', BaseExt, SubjectNames{SubjectCounter}, RunName);
        mask_name=sprintf('%s/analysis/firstlevel/functional%s.feat/mask.nii.gz', SubjectNames{SubjectCounter}, RunName);
        
        
        %         % Load the volumes
        %         try
        %             sfnr_nii=load_untouch_nii(sfnr_name);
        %             mask_nii=load_untouch_nii(mask_name);
        %
        %             % Mask the sfnr image with the mask
        %             sfnr_masked=sfnr_nii.img.*double(mask_nii.img);
        %
        %             %Identify the min and max idxs of the volume (assuming the
        %             %brain is centre aligned
        %             min_idx=min(find(nansum(nansum(sfnr_masked,3),1)>0));
        %             max_idx=max(find(nansum(nansum(sfnr_masked,3),1)>0));
        %
        %             %Halfway index
        %             half_idx=((max_idx-min_idx)/2)+min_idx;
        %
        %             % Pull out the back half of the brain
        %             back=sfnr_masked(:, min_idx:half_idx, :);
        %             front=sfnr_masked(:, half_idx:max_idx, :);
        %
        %             % Average the back and the front half to find the difference in
        %             % SNR
        %             SFNR_Difference(SubjectCounter, RunCounter)=mean(front(front>0))-mean(back(back>0));
        %
        %         catch
        %             fprintf('Failed to create SFNR masks for %s\n', sfnr_name);
        %         end
        
    end
    
end

%% Summarise the results

% Make plots of the analyses
for DVCounter=1:3
    if DVCounter==1
        DV=SNR;
        Name='SNR';
    elseif DVCounter==2
        DV=SFNR;
        Name='SFNR';
    elseif DVCounter==3
        DV=Motion_average;
        Name='Motion';
    elseif DVCounter==4
        DV=SFNR_Difference;
        Name='SFNR-Difference';
    end
    
    hist(DV(DV>0))
    title([Name, output_name]);
    saveas(gcf, [savelocation, Name, output_name, '.eps']);
    
    % scatter age and DV
    DV(DV==0)=NaN; % Zero out values
    scatter(AgeList, nanmean(DV,2))
    title([Name output_name]);
    saveas(gcf, [savelocation, Name, output_name, '_correlation.eps']);
end

end

