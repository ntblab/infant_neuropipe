# Version history of infant_neuropipe repository

## V_1.0
Initial public release containing functioning code for analyzing PosnerCuing and StatLearning

## V_1.1
Bug fixes for Analysis_Timing and Pseudorun splitting that affect edge cases like when the first pseudorun of a run has a non-standard TR. Other quality of life changes also made

## V_1.2
Fixed an error in the registration fsf template that was making unnecessarily smooth data. Also add some quality of life improvements for FunctionalSplitter. Also added a script for converting pial surfaces (from FreeSurfer) into stl files which is useful for 3d printing

## V_1.3
Added support for iBEAT and added the citation for the methods paper

## V_1.4
Added support for nonlinear alignment via ANTS and updated the tutorial

## V_1.5
Fixed an error in pseudorun divide that did not check for irregular burn ins. Made flexible edits to preprocessing pipeline for motion parameter exploration
