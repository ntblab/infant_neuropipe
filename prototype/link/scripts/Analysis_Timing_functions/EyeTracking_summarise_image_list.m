% Summarise the image list that has been created. Specifically, print out
% the proportion of trials/blocks that have eye tracking compared to the
% number that were run
% 
% First created 4/17/17 C Ellis

function EyeTracking_summarise_image_list(Indexes, ImageList, Data)

SamplingRate=60; % What is the Hz of the eye tracker

% Find the proportion for blocks you have collected at least some trials
% for
for EpochCounter=1:length(Indexes)
   
    % What are the details of this epoch
    Epoch_details=Indexes{EpochCounter};
    
    % Pull out the images 
    try
        Images=ImageList.(Epoch_details{1}){Epoch_details{2}, Epoch_details{3}, Epoch_details{4}};
        
        % How many images are there
        Frames=length(Images);
        
        %How long was this block
        Block_details=Data.(sprintf('Experiment_%s', Epoch_details{1})).(sprintf('Block_%d_%d', Epoch_details{2}, Epoch_details{3}));
    
        % For each experiment (or group of experiments) specify how long in seconds is this epoch
        if strcmp(Epoch_details{1}, 'PosnerCuing')
            Duration=Block_details.Timing.ITIOns(Epoch_details{4},2)-Block_details.Timing.trialstart(Epoch_details{4},1);
        elseif strcmp(Epoch_details{1}, 'MemEncode') || strcmp(Epoch_details{1}, 'NarrowingLocalizer')
            Duration=Block_details.Timing.ShrinkingOffs(Epoch_details{4})-Block_details.Timing.SmallImageOns(Epoch_details{4});
        elseif strcmp(Epoch_details{1}, 'MemTest')
            Duration=Block_details.VPC(Epoch_details{4}).Timing.ImageOffs(2)-Block_details.VPC(Epoch_details{4}).Timing.ImageOns(2);
        elseif strcmp(Epoch_details{1}, 'StatLearning') || strcmp(Epoch_details{1}, 'Retinotopy')
            Duration=Block_details.totalRunTime;
        elseif strcmp(Epoch_details{1}, 'EyeTrackerCalib')
            Duration=sum(Block_details.Timing.ITI(Epoch_details{4},:))-Block_details.Timing.TrialOns(Epoch_details{4});
        elseif strcmp(Epoch_details{1}, 'FPEncode')
            Duration=Block_details.Timing.ShrinkingOffs(Epoch_details{4})-Block_details.Timing.PlaceOns(Epoch_details{4});
        elseif strcmp(Epoch_details{1}, 'FPTest')
            Duration=Block_details.VPC(Epoch_details{4}).Timing.ImageOffs(2)-Block_details.VPC(Epoch_details{4}).Timing.SceneOns(2);
        elseif strcmp(Epoch_details{1}, 'PlayVideo')
            Duration=Block_details.Timing.Movie_1.movieEnd.Local-Block_details.Timing.Movie_1.movieStart.Local;
        elseif strcmp(Epoch_details{1}, 'MM')
            Duration=Block_details.Timing.Movie_1.movieEnd.Local-Block_details.Timing.Movie_1.movieStart.Local;
        elseif strcmp(Epoch_details{1}, 'RepetitionNarrowing')
            Duration=Block_details.Timing.ShrinkingOffs(Epoch_details{4})-Block_details.Timing.SmallImageOns(Epoch_details{4});
        elseif strcmp(Epoch_details{1}, 'Saccade_SL')
            Duration=Block_details.Timing.TestEnd-Block_details.Timing.TestStart;
        else
            warning('%s not detected. This code tries to total up the time for each condition and compare it to the amount of eye tracking data collected. To make this work you must specify when this epoch starts and ends.\n\nRefer to ''ExperimentDefinitions'' to see what names specify the start and end of an epoch.', Epoch_details{1})
            return
        end
        
        
        % What proportion of the epoch was covered?
        Proportion = Frames / (Duration*SamplingRate);
        
        % Store these
        Epoch_Duration.(Epoch_details{1})(Epoch_details{2}, Epoch_details{3}, Epoch_details{4})=Duration;
        Epoch_Frames.(Epoch_details{1})(Epoch_details{2}, Epoch_details{3}, Epoch_details{4})=Frames;
        Epoch_Proportion.(Epoch_details{1})(Epoch_details{2}, Epoch_details{3}, Epoch_details{4})=Proportion;
    catch
        fprintf('Couldn''t complete %s Block_%d_%d Trial %d', Epoch_details{1}, Epoch_details{2}, Epoch_details{3}, Epoch_details{4});
    end
end

%Find the number of blocks you have no eyetracking data for.
DataFields=fieldnames(Data);
for FieldCounter=1:length(DataFields)
    
    FieldName=DataFields{FieldCounter};
    % What field is open
    if ~isempty(strfind(FieldName, 'Experiment'))
        
        % How many blocks are there? If there are fewer blocks in the
        % epochs recorded then this will mean no eye tracking was done for
        % that block. If some eye tracking was done for some events in the
        % block then there will be an equal block number but some cells of
        % the block will be empty
        
        if isfield(Epoch_Proportion, FieldName(12:end))
            if  size(Epoch_Proportion.(FieldName(12:end)),1) ~= length(fieldnames(Data.(FieldName)))
                %How many more more blocks of did you run compared to the eye
                %data you have?
                Difference=length(fieldnames(Data.(FieldName)))-size(Epoch_Proportion.(FieldName(12:end)),1);
                if Difference>0
                    Epoch_Proportion.(FieldName(12:end))=[Epoch_Proportion.(FieldName(12:end)); zeros(Difference, size(Epoch_Proportion.(FieldName(12:end)),2), size(Epoch_Proportion.(FieldName(12:end)),3))];
                end
            end
            
        else
            %How many block types
            BlockNames=fieldnames(Data.(FieldName));
            BlockTypes=[];
            for BlockCounter=1:length(BlockNames)
                Idxs=strfind(BlockNames{BlockCounter}, '_');
                BlockTypes(end+1)=str2num(BlockNames{BlockCounter}(Idxs(1)+1:Idxs(2)-1));
            end
            
            % Make as many entries as rows
            Epoch_Proportion.(FieldName(12:end))=zeros(length(unique(BlockTypes)),1);
        end
    end
end

% Print out the results
Experiments=fieldnames(Epoch_Proportion);
fprintf('\n------------------\nProportion of eye tracking captured.\nOrdered by experiment and block\n\n')
for ExperimentCounter=1:length(Experiments)
    fprintf('%s: %s\n', Experiments{ExperimentCounter}, sprintf('%0.2f ', mean(mean(Epoch_Proportion.(Experiments{ExperimentCounter}),2),3))) 
end
fprintf('\n------------------\n');
