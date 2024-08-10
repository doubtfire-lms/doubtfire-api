#!/bin/sh

# Name of the working directory
WORK_DIR=$1 

cd /workdir/texlive-latex/${WORK_DIR}

# TODO: debug test file submissions: '002-code.cs', 'java_with_invalid_unicode.java', 'long.ipynb' ... (are they supposed to fail lualatex compile?)
/bin/bash -c "lualatex -shell-escape -interaction=batchmode -halt-on-error input.tex"
echo "Running lualatex a second time to remove temporary last page..."
/bin/bash -c "lualatex -shell-escape -interaction=batchmode -halt-on-error input.tex"