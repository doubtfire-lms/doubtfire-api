#!/bin/sh

# Ensure we are in the same folder as the code
APP_PATH=`echo $0 | awk '{split($0,patharr,"/"); idx=1; while(patharr[idx+1] != "") { if (patharr[idx] != "/") {printf("%s/", patharr[idx]); idx++ }} }'`
APP_PATH=`cd "$APP_PATH"; pwd`
cd "$APP_PATH"

# Add details to the output yaml file to provide details back to OnTrack
# Use the following keys:
# - run_message: This text is added to a comment in relation to the build
# - new_status: Provide the shortcut for the new status (i.e. 'fix' to note issue)
out_yaml=$1

# Sanity check that we have the path to the output yaml file
if [ -z $out_yaml ] ; then
  echo "Unable to output result of automated run - ensure run is passed output yaml path"
  exit 1
fi

# Run the project -- pipe in input to test various use cases. Execution is time boxed so ensure scripts should execute with this timeframe.
dotnet run overseer.csproj

if [ $? -eq 0 ] ; then
  # It run ok...
  # Add your own tests to check if the task ran successfully - use run_message and new_status to provide details
  echo "run_message: Run succeeded!" >> $out_yaml
  # echo "new_status: fix" >> $out_yaml
fi

