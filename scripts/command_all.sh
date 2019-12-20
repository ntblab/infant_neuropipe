#!/bin/bash

# Apply a given command to all the participants it can be run on. 
# This takes in a text string and converts it into a command to be run by jumping into 
# all subject directories and trying to run it. 
# Be aware this might do crazy things you don't anticipate. 
# It is recommended that you DO NOT use wild cards in order to avoid this.
# This SHOULD NOT be used to delete things either
# It may also make a bunch of dead jobs if the paths don't work
# You are strong encouraged to make all commands this is used for quit when there is an error (set -ue)

source globals.sh

# Loop through the inputs to recreate the command from its words
command=''
wait_time=0
first=1 # Is this the first character (if not then don't search for wait time)
for input in "$@"
do  
	
	if [ "${input:0:1}" == "-" ] && [ $first -eq 1 ] 
	then
		wait_time=${input:1}
	else 	
		command=`echo ${command} ${input}`
	fi
	first=0
done

# What are the participants
participants=`ls subjects/`

for participant in $participants
do

echo "Running $participant"

# Move to the folder
cd $PROJ_DIR/subjects/$participant

# Run the command
eval $command

# Wait if appropriate
if [ ${wait_time} -ne 0 ]
then
echo "Waiting ${wait_time} minutes before the next participant" 
sleep ${wait_time}m
fi

done