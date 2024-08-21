#!/bin/sh

# This script is copied into the TeX Live container and remotely executed by run_latex.sh

OUTPUT_DIR=$1

cd /workdir/texlive-latex/${OUTPUT_DIR}

# Initialise work subfolder
mkdir -p work
cp *.tex *.py work/
cd work

# Compile PDF
lualatex -shell-escape -interaction=batchmode -halt-on-error input.tex
echo "Running lualatex a second time to remove temporary last page..."
lualatex -shell-escape -interaction=batchmode -halt-on-error input.tex

# Copy PDF to parent directory and cleanup
cp *.pdf *.log ../
cd ..
rm -rf work
