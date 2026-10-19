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
GOTENBERG_LOG="/tmp/gotenberg.log"
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
  # Keep the startup banner out of stdout so failures show the real error
  gotenberg --gotenberg-graceful-shutdown-duration=0s >"$GOTENBERG_LOG" 2>&1 &
  GOTENBERG_PID=$!

  health_status=0
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
    >/dev/null 2>&1 || health_status=$?

  if [ "$health_status" -ne 0 ]; then
    echo "Gotenberg failed to start" >&2
    tail -n 20 "$GOTENBERG_LOG" >&2 || true
    exit "$health_status"
  fi
}

convert_document() {
  convert_status=0
  curl \
    --fail-with-body \
    --silent \
    --show-error \
    --connect-timeout 5 \
    --max-time "${WORD_DOCUMENT_CONVERSION_TIMEOUT_SECONDS:-120}" \
    --request POST \
    --form "files=@$INPUT_FILE" \
    --output "$TEMP_OUTPUT" \
    "$GOTENBERG_URL/forms/libreoffice/convert" || convert_status=$?

  if [ "$convert_status" -ne 0 ]; then
    # --fail-with-body writes Gotenberg's error response to the output file
    if [ -s "$TEMP_OUTPUT" ]; then
      cat "$TEMP_OUTPUT" >&2
      echo >&2
    fi
    grep '"level":"error"' "$GOTENBERG_LOG" >&2 || true
    exit "$convert_status"
  fi

  if [ ! -s "$TEMP_OUTPUT" ]; then
    echo "Gotenberg did not produce a PDF" >&2
    exit 1
  fi

  mv "$TEMP_OUTPUT" "$OUTPUT_FILE"
}

trap cleanup EXIT INT TERM

start_gotenberg
convert_document
