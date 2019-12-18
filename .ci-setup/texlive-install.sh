#!/bin/sh

APP_PATH=`echo $0 | awk '{split($0,patharr,"/"); idx=1; while(patharr[idx+1] != "") { if (patharr[idx] != "/") {printf("%s/", patharr[idx]); idx++ }} }'`
APP_PATH=`cd "$APP_PATH"; pwd`

# See if there is a cached version of TL available
export PATH=/tmp/texlive/bin/x86_64-linux:$PATH
if ! command -v lualatex > /dev/null; then
  # Obtain TeX Live
  wget http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz
  tar -xzf install-tl-unx.tar.gz
  cd install-tl-20*

  echo "Installing using profile:"
  cat ${APP_PATH}/texlive.profile

  echo

  # Install a minimal system
  ./install-tl --profile="${APP_PATH}/texlive.profile"

  cd ..
fi

# Other contrib packages: done as a block to avoid multiple calls to tlmgr
# texlive-latex-base is needed to run pdflatex
tlmgr install   \
  catchfile     \
  fontawesome   \
  framed        \
  fvextra       \
  ifplatform    \
  kvoptions     \
  kvsetkeys     \
  lastpage      \
  letltxmacro   \
  ltxcmds       \
  minted        \
  pdftexcmds    \
  upquote       \
  xstring

# Keep no backups (not required, simply makes cache bigger)
tlmgr option -- autobackup 0

# Update the TL install but add nothing new
tlmgr update --self --all --no-auto-install
