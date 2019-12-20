%Summarise the results of the gaze coding for this coder

function Analyse_Coder_Results(ParticipantName)

%Load the data, delete everything except what is necessary
load(['../Mat_Data/', ParticipantName, '.mat'], 'Data', 'GenerateTrials')

% Add the path to the analysis code
current_dir=pwd;
addpath([current_dir, '/../../../prototype/link/scripts/Analysis_Timing_functions/']);
addpath([current_dir, '/../../../prototype/link/scripts/']);

% Change directory to simplify things
cd  ../../../prototype/link/

%Aggregate all of the timing information across coders
EyeData=EyeTracking_Aggregate(GenerateTrials, ParticipantName, [current_dir, '/../Coder_Files/']);

%Summarise how many frames from each block were collected.
EyeTracking_summarise_image_list(EyeData.Indexes, EyeData.ImageList, Data);

%Extract the responses from the eye tracking data
EyeData=EyeTracking_Reliability(EyeData, Data);

%Extract the responses from the eye tracking data
EyeData=EyeTracking_Responses(EyeData);

% Change directory
cd(current_dir)

%Save the data
SaveName=sprintf('../Analysed_Data/EyeData_%s', ParticipantName);
save(SaveName, 'EyeData')

% Ask if they want to run the replay
fprintf('If you want to review this session run:\nGaze_Categorization_Replay(''%s'', ''%s'')\n\n', SaveName,  ParticipantName)



