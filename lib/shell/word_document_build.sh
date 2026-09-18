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
INPUT_FILE="$WORK_DIR/input.docx"
OUTPUT_FILE="$WORK_DIR/output.pdf"
TEMP_OUTPUT="$WORK_DIR/output.pdf.tmp"
GOTENBERG_URL="http://localhost:3000"
GOTENBERG_PID=

if [ ! -f "$INPUT_FILE" ]; then
  echo "Word document input was not found" >&2
  exit 1
fi

cleanup() {
  exit_status=$?
  trap - EXIT INT TERM

  if [ -n "$GOTENBERG_PID" ] && kill -0 "$GOTENBERG_PID" 2>/dev/null; then
    kill "$GOTENBERG_PID" 2>/dev/null || true
    wait "$GOTENBERG_PID" 2>/dev/null || true
  fi

  rm -f "$TEMP_OUTPUT"
  exit "$exit_status"
}

start_gotenberg() {
  # Docker replaces the image's normal command with this script, so start the
  # bundled API before making the local conversion request.
  gotenberg --gotenberg-graceful-shutdown-duration=0s &
  GOTENBERG_PID=$!

  curl \
    --fail \
    --silent \
    --show-error \
    --retry 30 \
    --retry-connrefused \
    --retry-delay 1 \
    --connect-timeout 1 \
    --max-time 30 \
    "$GOTENBERG_URL/health" \
    >/dev/null
}

convert_document() {
  curl \
    --fail-with-body \
    --silent \
    --show-error \
    --connect-timeout 5 \
    --max-time "${WORD_DOCUMENT_CONVERSION_TIMEOUT_SECONDS:-120}" \
    --request POST \
    --form "files=@$INPUT_FILE" \
    --output "$TEMP_OUTPUT" \
    "$GOTENBERG_URL/forms/libreoffice/convert"

  if [ ! -s "$TEMP_OUTPUT" ]; then
    echo "Gotenberg did not produce a PDF" >&2
    exit 1
  fi

  mv "$TEMP_OUTPUT" "$OUTPUT_FILE"
}

trap cleanup EXIT INT TERM

start_gotenberg
convert_document
