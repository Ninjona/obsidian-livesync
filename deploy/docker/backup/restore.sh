#!/bin/bash
set -euo pipefail

backup_dir="${BACKUP_DIR:-/backups}"
db_url="${COUCHDB_URL:-http://couchdb:5984}"
db_user="${COUCHDB_USER:-admin}"
db_pass="${COUCHDB_PASSWORD:-password}"

# List available backups
backups=($(ls -1 $backup_dir/*.json.gz 2>/dev/null || true))
if [ ${#backups[@]} -eq 0 ]; then
  echo "No backups found in $backup_dir."
  exit 1
fi

echo "Available backups:"
for i in "${!backups[@]}"; do
  echo "$((i+1)). ${backups[$i]##*/}"
done

echo -n "Enter the number of the backup to restore: "
read -r idx
if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -lt 1 ] || [ "$idx" -gt ${#backups[@]} ]; then
  echo "Invalid selection."
  exit 1
fi
backup_file="${backups[$((idx-1))]}"

echo "You selected: $backup_file"
echo -n "Are you sure you want to restore this backup? This will overwrite current database contents. (yes/no): "
read -r confirm
if [ "$confirm" != "yes" ]; then
  echo "Restore cancelled."
  exit 0
fi

# Extract database name from filename
filename=$(basename -- "$backup_file")
db_name="${filename%%_*}"

echo "Restoring $db_name from $backup_file..."

gunzip -c "$backup_file" | jq -c '.rows[] | .doc' | while read -r doc; do
  curl -fsS -X POST "$db_url/$db_name" -u "$db_user:$db_pass" -H 'Content-Type: application/json' -d "$doc" > /dev/null
  # Optionally, add error handling here
  done

echo "Restore complete."
