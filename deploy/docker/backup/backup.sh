#!/bin/bash
set -euo pipefail

# Load env snapshot written by cron-entrypoint.sh (cron jobs don't inherit
# container env). Harmless when invoked manually — values match what's already set.
[ -f /etc/backup.env ] && . /etc/backup.env

# Configuration
db_url="${COUCHDB_URL:-http://couchdb:5984}"
db_user="${COUCHDB_USER:-admin}"
db_pass="${COUCHDB_PASSWORD:-password}"
backup_dir="${BACKUP_DIR:-/backups}"
retention_days="${BACKUP_RETENTION_DAYS:-7}"
timestamp=$(date +"%Y%m%d-%H%M%S")

# Ensure backup directory exists
mkdir -p "$backup_dir"

# List all non-system databases. Fail fast if metadata fetch/auth/parsing fails.
dbs=$(curl -fsS -u "$db_user:$db_pass" "$db_url/_all_dbs" | jq -r '.[] | select(startswith("_") | not)')

if [ -z "$dbs" ]; then
  echo "No user databases found to back up."
  exit 0
fi

for db in $dbs; do
  echo "Backing up $db..."
  curl -fsS -u "$db_user:$db_pass" "$db_url/$db/_all_docs?include_docs=true" \
    | gzip > "$backup_dir/${db}_$timestamp.json.gz"
done

echo "Backup complete. Cleaning up old backups..."
find "$backup_dir" -type f -name '*.json.gz' -mtime +$retention_days -delete
