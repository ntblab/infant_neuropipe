#!/bin/bash
#
# Update all reports that have been made by ./scripts/generate_report.sh in case new files were made
#
# Automatically updates all of the reports (by finding the command use to make it)
#
# Run this from $PROJ_DIR
#
# Created by C Ellis 5/30/17

source globals.sh

# Make sure you are in the root
root=$PROJ_DIR

files=`ls ${root}/analysis/report/report_*`

# What text identifies the start of this 
phrase="name:"
for file in $files
do
	
	# Pull out all the words from this file
	CorrectLine=0
	reportFile=`cat $file` 
	for word in $reportFile
	do
	
		if [[ $CorrectLine == 1 ]]; then
			command=$word
			
			# Run the command
			./scripts/generate_report.sh $command
			break
		fi
	
		# Find the phrase in this report
		if [[ $word == $phrase ]]; then
			CorrectLine=1
		fi
	done
	
	
	
done
