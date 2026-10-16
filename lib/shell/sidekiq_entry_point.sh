#!/bin/bash

# Start the run once job.
echo "Sidekiq docker container has been started"

# Setup new aliases
newaliases

# Setup msmptrc
if [ -f "/shared-files/msmtprc" ]; then
  echo "Copying msmtprc file from shared-files"
  cp -f /shared-files/msmtprc /etc;
else
  echo "msmtprc file not found in shared-files, using default configuration"
fi

# Ensure mail settings are accessible only by root
chown root:root /etc/msmtprc
chmod 600 /etc/msmtprc

# Docker credentials are local to this container. The default worker runs
# AcceptOverseerJob and may need to pull a private image.
if [ "${SIDEKIQ_QUEUE:-default}" = "default" ] && [ -n "${DOCKER_TOKEN:-}" ] && [ -n "${DOCKER_PROXY_URL:-}" ] && [ -n "${DOCKER_USER:-}" ]; then
  if ! printf '%s' "$DOCKER_TOKEN" | docker login --username "$DOCKER_USER" --password-stdin "$DOCKER_PROXY_URL"; then
    echo "Docker registry login failed for the default Sidekiq worker" >&2
  fi
fi

# Each container listens to one queue with one worker thread.
exec bundle exec sidekiq -q "${SIDEKIQ_QUEUE:-default}" -c 1
