#!/bin/sh

# Ensure we are in the same folder as the code
APP_PATH=`echo $0 | awk '{split($0,patharr,"/"); idx=1; while(patharr[idx+1] != "") { if (patharr[idx] != "/") {printf("%s/", patharr[idx]); idx++ }} }'`
APP_PATH=`cd "$APP_PATH"; pwd`
cd "$APP_PATH"

# Add details to the output yaml file to provide details back to OnTrack
# Use the following keys:
# - build_message: This text is added to a comment in relation to the build
# - new_status: Provide the shortcut for the new status (i.e. 'fix' to note issue)
out_yaml=$1

# Sanity check that we have the path to the output yaml file
if [ -z $out_yaml ] ; then
  echo "Unable to output result of automated build - ensure build is passed output yaml path"
  exit 1
fi

# First build seems only to restore... but restore does not avoid this issues... so prime the build
dotnet build overseer.csproj >>/dev/null 2>>/dev/null

# Compile the project -- output will be shown alongside the build
dotnet build overseer.csproj

# Did the build succeed?
if [ ! $? -eq 0 ] ; then
  # Build had an error - give a message to the user and set the status to fix
  echo "build_message: Build failed. Please address the issues raised, fix, and resubmit." >> $out_yaml
  echo "new_status: fix" >> $out_yaml
  exit 1
else
  # Success - make a note of this for the tutor
  echo "build_message: The program built without error." >> $out_yaml
fi
