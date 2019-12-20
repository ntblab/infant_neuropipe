
% Quantify the amount of usable information from a block that does not
% produce functional data (presumably).
% Takes the number of trials from MemTest and reports that

function ExperimentList = EyeTrackerCalib_quantify_blocks(AnalysedData, ExperimentList)

ExperimentList(end+1,:)={'EyeTrackerCalib', length(fieldnames(AnalysedData.Experiment_EyeTrackerCalib))};