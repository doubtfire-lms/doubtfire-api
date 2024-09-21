#!/bin/sh
# This script is copied into tmp/rails-latex/$WORK_DIR/ and executed by rails-latex

WORK_DIR=$(basename "$PWD")
docker exec -t $LATEX_CONTAINER_NAME $LATEX_BUILD_PATH $WORK_DIR
