#!/bin/sh

OUTPUT_DIR=$1
INPUT_FILE=$2

# OUTPUT_DIR and INPUT_FILE contain the name of the working directory.
# Example:
#
# OUTPUT_DIR = "123-567890"
# INPUT_FILE = "123-567890/input.tex"

cd /workdir/texlive-latex/${OUTPUT_DIR}

# TODO: add back -halt-on-error and fix .pygtex related errors
/bin/bash -c "lualatex -output-directory /workdir/texlive-latex/${OUTPUT_DIR} -shell-escape -interaction=batchmode /workdir/texlive-latex/${INPUT_FILE}"

echo "Running lualatex a second time to remove the temporary last page..."

/bin/bash -c "lualatex -output-directory /workdir/texlive-latex/${OUTPUT_DIR} -shell-escape -interaction=batchmode /workdir/texlive-latex/${INPUT_FILE}"