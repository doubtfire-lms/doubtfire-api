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

  rm -rf "$BUILD_DIR"
  exit "$exit_status"
}
trap cleanup EXIT INT TERM

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
chmod 0777 "$BUILD_DIR"
cp "$INPUT_FILE" "$BUILD_INPUT"

# The worker has no network interfaces other than loopback. Run the API in the
# same container so this request cannot leave the worker.
gotenberg --gotenberg-graceful-shutdown-duration=0s &
GOTENBERG_PID=$!

attempt=0
until curl --fail --silent --head --max-time 1 http://localhost:3000/health >/dev/null 2>&1; do
  if ! kill -0 "$GOTENBERG_PID" 2>/dev/null; then
    wait "$GOTENBERG_PID" 2>/dev/null || true
    echo "Gotenberg stopped before becoming ready" >&2
    exit 1
  fi

  attempt=$((attempt + 1))
  if [ "$attempt" -ge 30 ]; then
    echo "Gotenberg did not become ready within 30 seconds" >&2
    exit 1
  fi

  sleep 1
done

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
