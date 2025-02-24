%% What time points need to be excluded
%
% Take in the timing information and identify the epochs (blocks or events)
% which warrant exclusion. This uses the timecourse aggregated from the
% coded responses across participants. It also uses the
% EyeData.Exclude structure to identify what specifies
% exclusion based on what timecourse. Exclude is established in
% EyeTracking_Experiment
%
% Exclude is a field of EyeData which contains an experiment
% structure (some experiments will be missing) which themselves potentially
% contain the following three fields (where each element is an idx as
% specified in Idx_Names):
%       InvalidCodes: What are the coding responses that are deemed invalid
%           and will count towards invalid (defaults to 0). This can be an
%           array of cells containing vectors in order to exclude different
%           things at different time points within an epoch.
%       Criterion: What proportion of valid responses are necessary for
%           inclusion (defaults to 0.5, more means stricter)
%       CriticalWindow: What idxs of the timecourse are relevant (defaults
%           to all)
%
% The output will be TrialsIncluded which states which events twill not
% create events made for them in the event file
%
% Established as a stand alone function, C Ellis 9/8/16 Substantially
% updated to be more flexible with inputs and use the timecourse, C Ellis
% 3/23/17

function EyeData=EyeTracking_Exclude(EyeData)

Experiments=fieldnames(EyeData.Timing);

Default_InvalidResponses=0; % How many frames have already been excluded (default to zero)
Default_InvalidCodes={0}; % Default to eyes closed. If 6 is added then this means that undetected is also excluded
Default_Criterion=0.5; % Default inclusion rate (high means stricter)

%Iterate through the experiment counter
for ExperimentCounter=1:length(Experiments)
    
    %Iterate through each trial
    for IdxCounter=1:length(EyeData.Timecourse.(Experiments{ExperimentCounter}))
        
        %Extract the timecourse of looking behaviour for this trial
        Timecourse=EyeData.Timecourse.(Experiments{ExperimentCounter}){IdxCounter}; %Simplify
        
        % What responses for this experiment are invalid?
        InvalidCodes=Default_InvalidCodes; % reinstate
        if isfield(EyeData.Exclude, (Experiments{ExperimentCounter})) && isfield(EyeData.Exclude.(Experiments{ExperimentCounter}), 'InvalidCodes')
            InvalidCodes=EyeData.Exclude.(Experiments{ExperimentCounter}).InvalidCodes{IdxCounter};
        end
        
        % Pull out the subset of timecourse that is relevant for exclusion, if not
        % assume the whole duration
        if isfield(EyeData.Exclude, (Experiments{ExperimentCounter})) && isfield(EyeData.Exclude.(Experiments{ExperimentCounter}), 'CriticalWindow') && length(EyeData.Exclude.(Experiments{ExperimentCounter}).CriticalWindow) >= IdxCounter
            
            window_idxs = EyeData.Exclude.(Experiments{ExperimentCounter}).CriticalWindow{IdxCounter};
            Timecourse=Timecourse(window_idxs);
            
            critical_window = 1;
            Idx_Names = EyeData.Idx_Names.(Experiments{ExperimentCounter})(IdxCounter,:); % What is the block, repetition and trial of this index?
            fprintf('A critical window is being used for %s Block_%d_%d trial %d. Using %d frames out of %d\n', Experiments{ExperimentCounter}, Idx_Names(1), Idx_Names(2), Idx_Names(3), length(EyeData.Exclude.(Experiments{ExperimentCounter}).CriticalWindow{IdxCounter}), length(EyeData.Timecourse.(Experiments{ExperimentCounter}){IdxCounter})); 
            
            % If there are invalid codes for each trial then clip them to
            % only be this window.
            for InvalidCode_Counter=1:length(InvalidCodes)
                if length(InvalidCodes{InvalidCode_Counter}) > 1
                    InvalidCodes{InvalidCode_Counter} = InvalidCodes{InvalidCode_Counter}(window_idxs);
                end
            end
        else
            critical_window = 0;
        end
        
        % If the experiment needs a special criteria (e.g. fixations at
        % centre, different threshold) then pull this out here.
        Criterion=Default_Criterion; % reinstate
        if isfield(EyeData.Exclude, (Experiments{ExperimentCounter})) && isfield(EyeData.Exclude.(Experiments{ExperimentCounter}), 'Criterion')
            Criterion=EyeData.Exclude.(Experiments{ExperimentCounter}).Criterion(IdxCounter);
        end
        
        % Sum the total number of invalid responses
        InvalidResponses=Default_InvalidResponses;
        for InvalidCode_Counter=1:length(InvalidCodes)
            
            % Are the invalid responses critical over the duration of the
            % epoch? If not then cycle through each element of the invalid
            % responses
            if length(InvalidCodes{InvalidCode_Counter}) == 1
                InvalidResponses=InvalidResponses+sum(Timecourse==InvalidCodes{InvalidCode_Counter});
            else
                
                % Add to the sum of matches
                for Timecourse_counter = 1:length(Timecourse)
                    InvalidResponses=InvalidResponses+sum(Timecourse(Timecourse_counter)==InvalidCodes{InvalidCode_Counter}(Timecourse_counter));
                end
            end
        end
        
        %Pull out the index names
        Idx_Name=EyeData.Idx_Names.(Experiments{ExperimentCounter})(IdxCounter,:);
        
        % What is the proportion of valid responses? If there are no valid
        % responses then throw a warning but otherwise include it
        if length(Timecourse) > 0
            Proportion_Eyetracking_Included=1-(InvalidResponses/length(Timecourse));
        else
            Proportion_Eyetracking_Included=1;
            warning('No frames were collected for %s Block_%d_%d Trial %d', Experiments{ExperimentCounter}, Idx_Name(1), Idx_Name(2), Idx_Name(3));
        end
            
        %Should this event be included
        IncludeEvent=Proportion_Eyetracking_Included>Criterion;
        
        %Does the number of frames that are undetected exceed the threshold
        %and thus warrant the trials for exclusion?
        TrialsIncluded.(Experiments{ExperimentCounter}).(sprintf('Block_%d_%d', Idx_Name(1), Idx_Name(2)))(Idx_Name(3),:)=[IncludeEvent, Proportion_Eyetracking_Included];
        
        if critical_window == 1
            fprintf('Proportion included: %0.2f\n', Proportion_Eyetracking_Included);
        end
        
    end
    
    
end

%Store the data
EyeData.TrialsIncluded=TrialsIncluded;


end