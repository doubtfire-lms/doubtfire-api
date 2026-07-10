#!/bin/sh

set -eu

WORK_ID=${1:-}

if [ -z "$WORK_ID" ]; then
  echo "Usage: word_document_build.sh <work-id>" >&2
  exit 2
fi

case "$WORK_ID" in
  *[!A-Za-z0-9_-]*)
    echo "Invalid Gotenberg work id" >&2
    exit 2
    ;;
esac

WORK_DIR="/workdir/gotenberg/$WORK_ID"
BUILD_DIR="$WORK_DIR/work"
INPUT_FILE="$WORK_DIR/input.docx"
OUTPUT_FILE="$WORK_DIR/output.pdf"
BUILD_INPUT="$BUILD_DIR/input.docx"
BUILD_OUTPUT="$BUILD_DIR/output.pdf"

if [ ! -f "$INPUT_FILE" ]; then
  echo "Word document input was not found" >&2
  exit 1
fi

cleanup() {
  rm -rf "$BUILD_DIR"
}
trap cleanup EXIT INT TERM

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
chmod 0777 "$BUILD_DIR"
cp "$INPUT_FILE" "$BUILD_INPUT"

curl \
  --fail-with-body \
  --silent \
  --show-error \
  --connect-timeout 5 \
  --max-time "${WORD_DOCUMENT_CONVERSION_TIMEOUT_SECONDS:-120}" \
  --request POST \
  --form "files=@$BUILD_INPUT" \
  --output "$BUILD_OUTPUT" \
  http://localhost:3000/forms/libreoffice/convert

if [ ! -s "$BUILD_OUTPUT" ]; then
  echo "Gotenberg did not produce a PDF" >&2
  exit 1
fi

mv "$BUILD_OUTPUT" "$OUTPUT_FILE"
