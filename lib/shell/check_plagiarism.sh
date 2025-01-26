#!/bin/bash

#Get path to script
APP_PATH=`echo $0 | awk '{split($0,patharr,"/"); idx=1; while(patharr[idx+1] != "") { if (patharr[idx] != "/") {printf("%s/", patharr[idx]); idx++ }} }'`
APP_PATH=`cd "$APP_PATH"; pwd`

ROOT_PATH=`cd "$APP_PATH"/../..; pwd`

cd "$ROOT_PATH"

DF_LOG_TO_STDOUT=true rails submission:check_plagiarism
