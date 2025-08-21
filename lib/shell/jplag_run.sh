#!/bin/sh

# WORK_DIR=$(basename "$PWD")

WORK_DIR_NAME=$1
LANGUAGE=$2
THRESHOLD=$3
TASKS_DIR_SPLIT=$4
WORK_ID=$5

IMAGE_NAME="devcontainer-jplag"
CONTAINER_NAME="jplag-$WORK_ID"

docker run --rm \
  --network none \
  -e TERM=xterm \
  --volumes-from 1-formatif-dev-container \
  --name "$CONTAINER_NAME" \
  "$IMAGE_NAME" \
  java -jar /jplag/jplag-jar-with-dependencies.jar /tmp/jplag/"$WORK_DIR_NAME" -l "$LANGUAGE" --similarity-threshold="$THRESHOLD" -M RUN -r /tmp/jplag/"$WORK_DIR_NAME"/result.jplag
