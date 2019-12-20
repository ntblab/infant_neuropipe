# Scripts for generating timing files for experiments

When collecting data from infants, each session is unpredictable. This means the
same consistency we expect from adult scans cannot be expected with infants. To
accommodate the unpredictability the 'Analysis_Timing.m' script has the *very*
hard job of searching through all of the timing data stored in the matlab file
output by Experiment Menu (including block onset times and TR trigger times), as
well as the eye tracking timing. It then uses all this information to determine
when blocks start and stop, which blocks to exclude and how to use any condition
or behavioral data to generate timing files.

## WHAT DOES THIS SCRIPT DO

This script reads through all the experiments that have been done and evaluates
the timing. It outputs timing files for experiments as blocks (e.g. an
experiment block starts and stops at what time) and if possible, also for
events/trials in the block. Will produce timing files in functional run time (0s
is the start of the run) and experiment time (0s is the start of the first TR,
time only passes while scanner is running). These files are saved in firstlevel and
secondlevel, respectively. This code divides experimental epochs into three
kinds: run (the time from when the scanner starts to when it next stops), block
(an experiment/video starts and ends), event/trial (time period within a block
of interest).

This script automatically reads in the participant name. This is used to open a
variety of files, including: experiment data stored in the matlab file, motion
confounds stored in $SUBJ_DIR/analysis/firstlevel/Confounds/, and eye tracking
coder data stored in $SUBJ_DIR/data/Behavioral/

Eye tracking data is referenced to do two main things: identify trials in which
the eyes are judged as closed/undetected and produce weights for the timing
files according to looking time. For instance, you might have a visual paired
comparison experiment and code each event based on how long they spent looking
at one stimulus versus the other. Be aware of the values you choose for this
given that this will be used by the GLM so all of the relevant concerns about
parametric regressors comes in.

Note: if you add a response type to the Gaze_Categorization_Responses.m script
that you want to be recorded, make sure you add it to EyeTracking_Aggregate.m
script then read the instructions therein. For instance, let's say you want
coders to identify upward visual saccades, you will need to specify this as a
response option in EyeTracking_Aggregate.m

This script will output a useful figure for you to determine what each TR is
being labelled as (e.g., burn-in, experiment, or burn-out) and what experiments
TRs are assigned to in order to make the timing files work.

If necessary, this will create pseudoruns by splitting up the data into
different runs of single experiment types.

The outputs of this function are saved in analysis/Behavioral/

ALWAYS check the timing files---this script may not go as planned. Check by
reading the text output and ensuring that the times in
AnalysedData.FunctionalLength are equal to the TR numbers expected

To run through all participants, do a command like (on the cluster is faster): 
addpath('../../prototype/link/scripts/'); FailedParticipants={}; subjects=dir('..');
for i= 5:length(subjects); 
    try
        cd(sprintf('../%s', subjects(i).name)); 
        fprintf('\n\n\n\n %s', subjects(i).name); 
        Analysis_Timing; 
    catch
        FailedParticipants{end+1}=subjects(i).name; 
    end
end

## WHEN CAN THIS BE RUN

In the infant_neuropipe pipeline this script can be run at multiple stages. It 
is common to have to run this script multiple times on a participant, especially 
as you are developing code for a new experiment. Hence the script has been 
designed to wipe the slate clean upon every execution and thus allow you to
churn through many calls.

Because the main output of this function is timing files, you can run this script
out of order in the pipeline, often without consequence. Note, if you extend the 
code by adding additional functionality (e.g. you make analyses of eye tracking 
that determine how to conduct first level analyses) then this won't be true.
Nevertheless, the default outputs of this script are such that it could be run at
any point before 'FunctionalSplitter' is run (since that script needs timing
files in order to know when blocks start and end). If you have run 'FunctionalSplitter'
but need to re-run 'Analysis_Timing', that's fine; run 'Analysis_Timing' and then
re-run 'FunctionalSplitter'.


## WHAT TO DO IF YOU ADD AN EXPERIMENT

1. Create a function to be read in by EyeTracking_Experiment.m. Read the
comments at the top of the script to see how to add an experiment.

2. Sometimes the experiment code lacks important information and it needs to be
updated. This is done using Timing_UpdateInformation. Here you can create
experiment specific code if an experiment doesn't have variables, like
`TestStart`

3. Make sure that there exists a file in the Analysis/Timing folder titled
"Timing_$ExperimentName". This function will specify timing file names and event
times. The block or event names you want to group are unique since events will
be written in whatever ID name is supplied. To make this work, the following
output variables are necessary:
    
    AnalysedData: A collection of data about the block you want to store
    
    Timing: Information for the timing file. If empty then no timing files
    will be created. If there is no event file then to be made then it won't
    make the variable 'Events'
    
          -Name: What is the savename for the timing file
    
          -Name_Events: What is the savename for the event timing file
          -Events: How many Events are there?
          -Task_Event: How long is each trial relevant event
          -InitialWait: What is the time delay between TestStart and the first event
          -TimeElapsed_Events: How long is it between the events (event duration + inter event interval)?
          

4. If you want to create condition timing files (events aggregated across
blocks) then read Timing_MakeTimingFiles and make a function called
Timing_Condition_$Experiment to specify how conditions are partitioned. For
instance every event in a memory experiment could be Remembered or Forgotten and
indicated as such in the EyeData.Weights.Condition.$EXPERIMENT structure. These
events woul then be saved to different timing files depending on the condition.


