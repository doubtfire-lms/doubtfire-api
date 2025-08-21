#!/bin/sh

# You can mount your own script onto lib/shell/latex_run.sh
# and run custom PDF generation
#
# eg. If you have lualatex installed in the same container
#     You can call it directly, instead of `docker exec`
#
#  $: lualatex input.tex

WORK_DIR=$(basename "$PWD")
IMAGE_NAME="lmsdoubtfire/formatif-latex:10.0.0-10"
CONTAINER_NAME="texlive-job-$WORK_DIR"

docker run --rm \
  -e TERM=xterm \
  --volumes-from 1-formatif-dev-container \
  --name "$CONTAINER_NAME" \
  "$IMAGE_NAME" \
  ${LATEX_BUILD_PATH:-/texlive/shell/latex_build.sh} $WORK_DIR
