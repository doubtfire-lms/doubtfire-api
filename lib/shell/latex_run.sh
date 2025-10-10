#!/bin/sh

# You can mount your own script onto lib/shell/latex_run.sh
# and run custom PDF generation
#
# eg. If you have lualatex installed in the same container
#     You can call it directly, instead of `docker exec`
#
#  $: lualatex input.tex

WORK_DIR=$(basename "$PWD")
IMAGE_NAME="$DF_LATEX_IMAGE_NAME"
CONTAINER_NAME="texlive-job-$WORK_DIR"

docker run --rm \
  -e TERM=xterm \
  -e DF_LATEX_PATH_TO_WORKDIRS="$DF_LATEX_PATH_TO_WORKDIRS" \
  --volumes-from $DF_API_CONTAINER_NAME \
  --name "$CONTAINER_NAME" \
  "$IMAGE_NAME" \
  ${LATEX_BUILD_PATH:-/texlive/shell/latex_build.sh} $WORK_DIR
