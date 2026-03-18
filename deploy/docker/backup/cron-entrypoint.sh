#!/bin/bash
set -euo pipefail

# Start cron in the background
cron

# Tail cron log to keep container running
exec tail -F /var/log/cron.log
