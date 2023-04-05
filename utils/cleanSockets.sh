#!/bin/bash

# Script to clean up any lingering sockets after a frozen / killed program
# in the Communication Game experiment.
# Calls ss, greps for known socket numbers and kills corresponding processes.
#

# HARDCODED socket numbers
SOCKETLIST=(9997 9998 9999 19008 19009 19010)

echo -e "\nUtility cleanSocket has been summoned!\nWill clean up any process corresponding to sockets "${SOCKETLIST[@]}

# loop through socket numbers
for SOCKET in ${SOCKETLIST[@]}; do

  # grep for the output of ss that contains the current socket number
  SSOUTPUT=$(ss -u0p | grep ${SOCKET})
  if [[ -z $SSOUTPUT ]]; then
    echo -e "\nSocket "$SOCKET" is not bound"
  else
    echo -e "\nSocket "$SOCKET" is bound: "$SSOUTPUT

    # parse the output, find the process id
    PROCESSID=$(echo $SSOUTPUT | grep -oP '(?<=pid=)[0-9]+')
    echo -e "pid "$PROCESSID"\n"
    
    # kill the process
    echo -e "Killing the process with SIGTERM..."
    if kill $PROCESSID; then
      echo -e "Process "$PROCESSID" killed successfully.\n"
    else
      echo "Kill failed, resorting to SIGKILL..."
      if kill -9 $PROCESSID; then
        echo -e "Process "$PROCESSID" killed successfully.\n"
      else
        echo -e "Could not kill process "$PROCESSID", giving up.\n"
        exit 1
      fi
    fi
  fi  # if [-z $SSOUTPUT]...
  
done  # for SOCKET...

exit 0

