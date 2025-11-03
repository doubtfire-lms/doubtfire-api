#!/bin/sh

# This script is copied into the TeX Live container and remotely executed by latex_run.sh

OUTPUT_DIR=$1
BASE_DIR="/workdir/texlive-latex/${OUTPUT_DIR}"
WORK_DIR="${BASE_DIR}/work"


# Initialise work subfolder
mkdir -p "$WORK_DIR"
cp "$BASE_DIR"/*.tex "$BASE_DIR"/*.py "$WORK_DIR"/

# Compile PDF
lualatex -output-directory="$WORK_DIR" -shell-escape -interaction=batchmode -halt-on-error "$WORK_DIR/input.tex"
RESULT=$?
if [ $RESULT -eq 0 ]; then
  echo "Running lualatex a second time to remove temporary last page..."
  lualatex -output-directory="$WORK_DIR" -shell-escape -interaction=batchmode -halt-on-error "$WORK_DIR/input.tex"
  RESULT=$?
fi

# Copy PDF to parent directory and cleanup
cp "$WORK_DIR"/*.log "$BASE_DIR"/
cp "$WORK_DIR"/*.pdf "$BASE_DIR"/
rm -rf "$WORK_DIR"

exit $RESULT
