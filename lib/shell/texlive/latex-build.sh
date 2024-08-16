#!/bin/sh

# Name of the working directory
WORK_DIR=$1

mkdir -p /workdir/texlive-latex/${WORK_DIR}/work

# Copy input.tex and jupynotex.py into the /work folder
cp -r /workdir/texlive-latex/${WORK_DIR}/*.tex /workdir/texlive-latex/${WORK_DIR}/work/
cp -r /workdir/texlive-latex/${WORK_DIR}/*.py /workdir/texlive-latex/${WORK_DIR}/work/

cd /workdir/texlive-latex/${WORK_DIR}/work

# Compile PDFs
/bin/bash -c "lualatex -shell-escape -interaction=batchmode -halt-on-error input.tex"
echo "Running lualatex a second time to remove temporary last page..."
/bin/bash -c "lualatex -shell-escape -interaction=batchmode -halt-on-error input.tex"

# Copy input.pdf and input.log into #{WORK_DIR}
if [ -f "input.pdf" ]; then
  cp input.pdf ../
fi
if [ -f "input.log" ]; then
  cp input.log ../
fi

# Remove /work directory - leaving input.pdf, input.log, and
cd ..
rm -rf work
