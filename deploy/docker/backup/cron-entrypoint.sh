#!/bin/bash
set -euo pipefail

# Snapshot container env for cron jobs — cron strips the parent environment,
# so backup.sh can't see COUCHDB_USER/PASSWORD unless we persist them here.
{
  printf 'export COUCHDB_URL=%q\n'             "${COUCHDB_URL:-http://couchdb:5984}"
  printf 'export COUCHDB_USER=%q\n'            "${COUCHDB_USER:-}"
  printf 'export COUCHDB_PASSWORD=%q\n'        "${COUCHDB_PASSWORD:-}"
  printf 'export BACKUP_DIR=%q\n'              "${BACKUP_DIR:-/backups}"
  printf 'export BACKUP_RETENTION_DAYS=%q\n'   "${BACKUP_RETENTION_DAYS:-7}"
} > /etc/backup.env
chmod 600 /etc/backup.env

# Render the crontab at runtime so BACKUP_SCHEDULE can override the default.
schedule="${BACKUP_SCHEDULE:-0 * * * *}"
{
  echo "SHELL=/bin/bash"
  echo "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"
  echo "${schedule} /usr/local/bin/backup.sh >> /var/log/cron.log 2>&1"
} | crontab -

# Start cron in the background
cron

# Tail cron log to keep container running
exec tail -F /var/log/cron.log
