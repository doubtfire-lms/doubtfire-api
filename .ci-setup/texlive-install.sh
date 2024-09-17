#!/bin/bash

set -e
APP_PATH="$(readlink -f "$(dirname "$0")")"
TEX_COMPILER=lualatex

CTAN_REPO="https://mirror.aarnet.edu.au/pub/CTAN/systems/texlive/tlnet"

# See if there is a cached version of TL available
# shellcheck disable=SC2155
export PATH="/tmp/texlive/bin/$(uname -m)-linux:$PATH"
if ! command -v "$TEX_COMPILER" > /dev/null; then
  echo "----------------------------------------"
  echo "Downloading texlive installer archive from CTAN:"
  wget "$CTAN_REPO/install-tl-unx.tar.gz"
  tar -xzf install-tl-unx.tar.gz
  cd install-tl-20*

  echo "----------------------------------------"
  echo "Installing texlive using profile:"
  cat "${APP_PATH}"/texlive.profile
  echo
  ./install-tl --profile="${APP_PATH}/texlive.profile" -repository "$CTAN_REPO"

  echo "----------------------------------------"
  echo "Set tlmgr repository:"
  tlmgr option repository "$CTAN_REPO"

  echo "----------------------------------------"
  echo "Installing additional texlive packages:"
  tlmgr install fontawesome luatextra luacode minted fvextra catchfile xstring framed lastpage pdfmanagement-testphase newpax tcolorbox environ pdfcol tikzfill markdown paralist csvsimple gobble upquote tagpdf

  echo "----------------------------------------"
  echo "Ensuring the newpax package is sufficiently up to date:"
  if NEWPAX_VERSION=$(tlmgr info --only-installed --data cat-version newpax) ; then
    if [[ $(echo "$NEWPAX_VERSION < 0.53" | bc) == 1 ]]; then
      echo >&2 "Package newpax version lower than 0.53 contain several bugs that are now fixed, giving up."; exit 1;
    else
      echo "Version $NEWPAX_VERSION found."
    fi
  else
      echo >&2 "Package newpax not found!"; exit 1;
  fi

  cd ..

  # Keep no backups (not required, simply makes cache bigger)
  tlmgr option -- autobackup 0
fi

echo "----------------------------------------"
echo "Installation complete, verifying installation of $TEX_COMPILER."
command -v "$TEX_COMPILER" >/dev/null 2>&1 || { echo >&2 "$TEX_COMPILER is not found."; exit 1; }
# Do a test compile recommended by https://www.tug.org/texlive/quickinstall.html
"$TEX_COMPILER" small2e || { echo >&2 "Failed to process test file with $TEX_COMPILER."; exit 1; }
# remove test files
rm small2e.aux small2e.log small2e.pdf
