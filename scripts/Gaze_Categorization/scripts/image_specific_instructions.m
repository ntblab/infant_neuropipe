% Specify experiment and frame specific information
%
% If you want to give instructions to the coders at a specific point during
% the epoch based on information in a line (such as a message) then you can
% do so here. This can be useful if you have periods of time where coding
% is either really important (you can encourage focus) or where different
% response options are unlikely (and you don't mind biasing coding for
% these epochs).
%
% This code takes in the experiment name, the line information and any
% information that has been accumulated about instructions on this epoch.
% The instructions are strings in a cell and the Instruction_Idx is a cell
% length of instructions within which the idxs that the instructions should
% be presented on are stored. Instruction_continuing specifies whether for
% this instruction type you should continue collecting idxs.
%
% It is possible to make the instructions change throughout the epoch. The 
% logic is that the Instructions variable is a cell with instructions and
% Instruction_Idx has an equal length cell that states the frames on which
% these instructions should be provided
%
function [Instructions, Instruction_Idx, Instruction_continuing] = image_specific_instructions(ExperimentName, Line, TabIdx, Instructions, Instruction_Idx, Instruction_continuing, Data, BlockName, TrialStartMessage)

if strcmp(ExperimentName, 'PosnerCuing')
    
    % Preset array
    if isempty(Instruction_Idx)
        Instruction_Idx{1}=[];
        Instruction_continuing{1}=1;
    end
    
    % Is it the end of the instruction period? If not then append this
    % number to the list
    if ~isempty(strfind(Line, 'Cue_Start_Time'))
        Instruction_continuing{1}=0;
    elseif Instruction_continuing{1} == 1
        
        Instructions{1}='Probably centre'; % Specify the instruction
        Instruction_Idx{1}(end+1)=str2double(Line(1:TabIdx-1));  % Append to the list this idx
        
    end

end
