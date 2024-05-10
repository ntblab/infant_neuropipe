% Partition events into conditions for SubMem_Categories
%
% This is how Timing_Condition_$Experiment works. For this experiment find
% the condition filenames. These names are stored in the following format.
% For each element of the Name_Condition structure outlines a different way
% of organizing the events (e.g. Left vs right, or valid vs invalid vs
% neutral). The subfields of this structure refer to each level (first or
% second) that these timing files will be made for. Finally for each level
% there are indexes of cells referring to the different possible names for
% this condition. Usually this will only be one element long but if an
% event belongs to multiple conditions simultaneously (if the conditions
% aren't mutually exclusive, like if the conditions were features of a
% stimulus) then this corresponds to different elements of this field. To
% ignore an event, supply nans.
%
%
% Conditions in this experiment are only made for Encoding events
% Encoding Events are further broken down by looking times as specified via
% weights
%
% TSY 12/12/2019
% 01/06/2020
% 03/02/2020
% 10/07/2021 now make timing files for retrieval / test events 

function [Name_Condition, Weights]=Timing_Condition_SubMem_Categories(varargin)

%Pull out the input information
EyeData=varargin{1};
Timing=varargin{2};
EventCounter=varargin{3};
Functional_name=varargin{4};
BlockName=varargin{5};

%If it's an encoding event, and we have eyetracking coding, then we are going to
%further make timing files based on looking behavior (determine remembered
%vs forgotten)

NumConditions=12; % defined in the eyetracking experiment script

%Iterate different specifities of looking time
Weights = {};
for ConditionCounter = 1:NumConditions
    
    %If there is no field for this then report NaNs
    if isfield(EyeData, 'Weights') &&  isfield(EyeData.Weights, 'SubMem_Categories') && Timing.isVPC(EventCounter)==0
        
        %Specify the  timing file names. Make sure these don't
        %have the name of an experiment or else they will be used in
        %FunctionalSplitter
        if ConditionCounter==1
            
            %What condition is it
            ConditionIdx=EyeData.Weights.SubMem_Categories.Condition.(BlockName)(ConditionCounter, EventCounter);
            PossibleNames={'SubMem_Categories-Condition_NovelPref', 'SubMem_Categories-Condition_FamiliarPref'};
            Weights{ConditionCounter} = 1;
            
        elseif ConditionCounter==2
            
            %What condition is it
            ConditionIdx=EyeData.Weights.SubMem_Categories.Condition.(BlockName)(ConditionCounter, EventCounter);
            PossibleNames={'SubMem_Categories-Condition_StrongNovel', 'SubMem_Categories-Condition_WeakNovel', 'SubMem_Categories-Condition_WeakFamiliar', 'SubMem_Categories-Condition_StrongFamiliar'};
            Weights{ConditionCounter} = 1;
            
        elseif ConditionCounter==3
            
            ConditionIdx=1;
            PossibleNames={'SubMem_Categories-Condition_Familiar_Z'};
            Weights{ConditionCounter} = EyeData.Weights.SubMem_Categories.Condition.(BlockName)(ConditionCounter, EventCounter);
            
        elseif ConditionCounter==4
            
            ConditionIdx=1;
            PossibleNames={'SubMem_Categories-Condition_Novel_Z'};
            Weights{ConditionCounter} = EyeData.Weights.SubMem_Categories.Condition.(BlockName)(ConditionCounter, EventCounter);
            
        elseif ConditionCounter==5
            
            
            ConditionIdx=EyeData.Weights.SubMem_Categories.Condition.(BlockName)(ConditionCounter, EventCounter)+1;
            PossibleNames={'SubMem_Categories-Condition_FirstLook_Novel', 'SubMem_Categories-Condition_FirstLook_Familiar'};
            Weights{ConditionCounter} = 1;
            
        elseif ConditionCounter==6
            
            ConditionIdx=1;
            PossibleNames={'SubMem_Categories-Condition_Duration_old'};
            Weights{ConditionCounter} = EyeData.Weights.SubMem_Categories.Condition.(BlockName)(ConditionCounter, EventCounter);
            
        elseif ConditionCounter==7
            
            ConditionIdx=1;
            PossibleNames={'SubMem_Categories-Condition_Duration_new'};
            Weights{ConditionCounter} = EyeData.Weights.SubMem_Categories.Condition.(BlockName)(ConditionCounter, EventCounter);
            
            
        elseif ConditionCounter==8
            
            %What condition is it
            ConditionIdx=EyeData.Weights.SubMem_Categories.Condition.(BlockName)(ConditionCounter, EventCounter);
            PossibleNames={'SubMem_Categories-Condition_Q1', 'SubMem_Categories-Condition_Q2', 'SubMem_Categories-Condition_Q3', 'SubMem_Categories-Condition_Q4'};
            Weights{ConditionCounter} = 1;  
        
        elseif ConditionCounter==9
            
            %What condition is it
            ConditionIdx=1;
            PossibleNames={'SubMem_Categories-Condition_ShortDelay'};
            Weights{ConditionCounter} = EyeData.Weights.SubMem_Categories.Condition.(BlockName)(ConditionCounter, EventCounter);
                
        elseif ConditionCounter==10
            
            %What condition is it
            ConditionIdx=1;
            PossibleNames={'SubMem_Categories-Condition_LongDelay'};
            Weights{ConditionCounter} = EyeData.Weights.SubMem_Categories.Condition.(BlockName)(ConditionCounter, EventCounter);
                          
        elseif ConditionCounter==11
            
            %What condition is it
            ConditionIdx=1;
            PossibleNames={'SubMem_Categories-Condition_DelayLength'};
            Weights{ConditionCounter} = EyeData.Weights.SubMem_Categories.Condition.(BlockName)(ConditionCounter, EventCounter);
        
        elseif ConditionCounter==12
            
            %What condition is it
            ConditionIdx=EyeData.Weights.SubMem_Categories.Condition.(BlockName)(ConditionCounter, EventCounter);
            PossibleNames={'SubMem_Categories-Condition_Binary_DelayLength', 'SubMem_Categories-Condition_Binary_DelayLength'};
            Weights{ConditionCounter} = 1;              
        end
        
        %Store the first and second level names
        if ConditionIdx~=0
            Name_Condition(ConditionCounter).Second{1}=PossibleNames{ConditionIdx};
            Name_Condition(ConditionCounter).First{1}=[Functional_name, '_', Name_Condition(ConditionCounter).Second{1}];
        else
            Name_Condition(ConditionCounter).Second{1}=NaN;
            Name_Condition(ConditionCounter).First{1}=NaN;
        end
        
    % If this is a test trial, we can figure out the timing appropriately!     
    elseif isfield(EyeData, 'Weights') &&  isfield(EyeData.Weights, 'SubMem_Categories') && Timing.isVPC(EventCounter)==1
        
        ConditionIdx=0;
        
        %Specify the  timing file names. Make sure these don't
        %have the name of an experiment or else they will be used in
        %FunctionalSplitter

        % First we care about whether they showed a novelty or familiarty
        % preference at test 
        if ConditionCounter==1
            
            % What eye index does this correspond to ? 
            eye_idx=EyeData.SubMem_Test.Test2EyeTest.(BlockName)(EventCounter);
            
            %What condition is it
            ConditionIdx=EyeData.Weights.SubMem_Test.Condition(ConditionCounter, eye_idx);
            PossibleNames={'SubMem_Categories-Condition_Test_NovelPref', 'SubMem_Categories-Condition_Test_FamiliarPref'};
            Weights{ConditionCounter} = 1;
        
        % it will also be informative to look at a parametric analysis
        % version
        elseif ConditionCounter==3
            
            % What eye index does this correspond to ? 
            eye_idx=EyeData.SubMem_Test.Test2EyeTest.(BlockName)(EventCounter);
            
            ConditionIdx=1;
            PossibleNames={'SubMem_Categories-Condition_Test_Familiar_Z'};
            Weights{ConditionCounter} = EyeData.Weights.SubMem_Test.Condition(ConditionCounter, eye_idx);
         
        % finally, let's look at how delay length impacts retrieval 
        elseif ConditionCounter==11
            
            eye_idx=EyeData.SubMem_Test.Test2EyeTest.(BlockName)(EventCounter);
            
            %What condition is it
            ConditionIdx=1;
            PossibleNames={'SubMem_Categories-Condition_Test_DelayLength'};
            Weights{ConditionCounter} = EyeData.Weights.SubMem_Test.Condition(ConditionCounter, eye_idx);
                         
        end     
        
         
        %Store the first and second level names
        if ConditionIdx~=0
            Name_Condition(ConditionCounter).Second{1}=PossibleNames{ConditionIdx};
            Name_Condition(ConditionCounter).First{1}=[Functional_name, '_', Name_Condition(ConditionCounter).Second{1}];
        else
            Name_Condition(ConditionCounter).Second{1}=NaN;
            Name_Condition(ConditionCounter).First{1}=NaN;
        end
        
    % if there is no field, just put NaNs
    else
        Name_Condition(ConditionCounter).First{1}=NaN;
        Name_Condition(ConditionCounter).Second{1}=NaN;
    end
        
    
end

%No matter what though, we want to make sure that we distinguish between
%VPC and encoding events
%What condition is it

%Check that we have this information and that this was a trial that was run
%during this block (e.g., Timing.isVPC should be NaN'd in
%Timing_SubMem_Categories if it was from a previous session)
if isfield(EyeData, 'Weights') &&  isfield(EyeData.Weights, 'SubMem_Categories') && ~isnan(Timing.isVPC(EventCounter))
    
    % If it's included for eye tracking and also motion, figure out if it is a VPC or
    % encoding trial
    if EyeData.TrialsIncluded.SubMem_Categories.(BlockName)(EventCounter,1)>0.5 && EyeData.TrialsIncluded.SubMem_Categories.(BlockName)(EventCounter,2)>0.5
        
        ConditionIdx=Timing.isVPC(EventCounter)+1;
        PossibleNames={'SubMem_Categories-Condition_Encode', 'SubMem_Categories-Condition_VPC'};
        
        Name_Condition(NumConditions+1).Second{1}=PossibleNames{ConditionIdx};
        Name_Condition(NumConditions+1).First{1}=[Functional_name, '_', Name_Condition(NumConditions+1).Second{1}];
        
        Weights{NumConditions+1}=1;
        
        %And we should also know what category it is
        %We did not save this as an index but instead as a name, so that's what we
        %will add on
        Category=Timing.Category{EventCounter};
        PossibleNames=strcat('SubMem_Categories-Condition_',Category); %'PossibleNames', though there is only one option here ;)
        
        Name_Condition(NumConditions+2).Second{1}=char(PossibleNames);
        Name_Condition(NumConditions+2).First{1}=char(strcat(Functional_name, '_', Name_Condition(NumConditions+2).Second{1}));
        
        Weights{NumConditions+2}=1;
        
    else
        % Otherwise, NANs for everything
        Weights{NumConditions+1} = NaN;
        
        Name_Condition(NumConditions+1).First{1}=NaN;
        Name_Condition(NumConditions+1).Second{1}=NaN;
  
        Weights{NumConditions+2} = NaN;
        
        Name_Condition(NumConditions+2).First{1}=NaN;
        Name_Condition(NumConditions+2).Second{1}=NaN;
    end
    
else %NaNs for both if this wasn't done in this block
    Name_Condition(NumConditions+1).First{1}=NaN;
    Name_Condition(NumConditions+1).Second{1}=NaN;

    Name_Condition(NumConditions+2).First{1}=NaN;
    Name_Condition(NumConditions+2).Second{1}=NaN;
    
end

end