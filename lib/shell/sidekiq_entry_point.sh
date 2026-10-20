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

# Run sidekiq
bundle exec sidekiq
