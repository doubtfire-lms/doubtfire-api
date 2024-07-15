#!/bin/bash

#Get path to script
APP_PATH=`echo $0 | awk '{split($0,patharr,"/"); idx=1; while(patharr[idx+1] != "") { if (patharr[idx] != "/") {printf("%s/", patharr[idx]); idx++ }} }'`
APP_PATH=`cd "$APP_PATH"; pwd`

ROOT_PATH=`cd "$APP_PATH"/../..; pwd`

cd "$ROOT_PATH"
DF_LOG_TO_STDOUT=true TERM=xterm-256color bundle exec rake submission:generate_pdfs
DF_LOG_TO_STDOUT=true bundle exec rake maintenance:cleanup

#Delete tmp files that may not be cleaned up by image magick and ghostscript
find /tmp -maxdepth 1 -name magick* -type f -delete
find /tmp -maxdepth 1 -name gs_* -type f -delete
