#!/bin/bash

#Get path to script
APP_PATH="$(readlink -f "$(dirname "$0")")"

ROOT_PATH=`cd "$APP_PATH"/../..; pwd`

cd "$ROOT_PATH"

DF_LOG_TO_STDOUT=true rails submission:portfolio_autogen_check
