#!/bin/sh

# WORK_DIR=$(basename "$PWD")

WORK_DIR_NAME=$1
LANGUAGE=$2
THRESHOLD=$3
TASKS_DIR_SPLIT=$4
WORK_ID=$5

IMAGE_NAME="$DF_JPLAG_IMAGE_NAME"
CONTAINER_NAME="jplag-$WORK_ID"

PATH_TO_JPLAG_FILES="$DF_JPLAG_PATH_TO_WORKDIRS/$WORK_DIR_NAME"

docker run --rm \
  --network none \
  -e TERM=xterm \
  --volumes-from $DF_API_CONTAINER_NAME \
  --name "$CONTAINER_NAME" \
  "$IMAGE_NAME" \
  java -jar /jplag/jplag-jar-with-dependencies.jar "$PATH_TO_JPLAG_FILES" -l "$LANGUAGE" --similarity-threshold="$THRESHOLD" -M RUN -r "$PATH_TO_JPLAG_FILES"/result.jplag --overwrite
