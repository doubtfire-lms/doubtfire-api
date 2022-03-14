#!/bin/bash
set -e

rm -f tmp/pids/server.pid

exec bundle exec "$@"
