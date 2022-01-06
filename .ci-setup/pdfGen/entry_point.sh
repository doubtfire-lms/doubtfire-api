#!/bin/bash

# Start the run once job.
echo "Docker container has been started"

# Save the docker user environment
declare -p | grep -Ev 'BASHOPTS|BASH_VERSINFO|EUID|PPID|SHELLOPTS|UID' > /container.env
cat /container.env

# Ensure log is present
touch /var/log/cron.log

sleep 1

# Setup crontab - clear then load with file
crontab -r
crontab /etc/cron.d/container_cronjob

echo "RESET CRONTAB" >> /var/log/cron.log

# Ensure mail settings are accessible only by root
chown root:root /etc/msmtprc
chmod 600 /etc/msmtprc

# Run cron and follow log
chmod 644 /etc/cron.d/container_cronjob && cron -f && tail -f /var/log/cron.log > /proc/1/fd/1 2>/proc/1/fd/2
