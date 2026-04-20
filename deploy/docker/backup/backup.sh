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
state_dir="$backup_dir/.state"
lock_file="/var/lock/backup.lock"
timestamp=$(date +"%Y%m%d-%H%M%S")

mkdir -p "$backup_dir" "$state_dir"

# Prevent overlap if a prior run is still going (e.g. large db + tight schedule).
exec 9>"$lock_file"
if ! flock -n 9; then
  echo "Another backup is already running; exiting."
  exit 0
fi

# List all non-system databases. Fail fast if metadata fetch/auth/parsing fails.
dbs=$(curl -fsS -u "$db_user:$db_pass" "$db_url/_all_dbs" | jq -r '.[] | select(startswith("_") | not)')

if [ -z "$dbs" ]; then
  echo "No user databases found to back up."
  exit 0
fi

# Accumulate per-db outcomes for the status file written at the end.
status='{"databases":{}}'

for db in $dbs; do
  # update_seq is CouchDB's authoritative "anything changed?" marker.
  current_seq=$(curl -fsS -u "$db_user:$db_pass" "$db_url/$db" | jq -r '.update_seq')
  seq_file="$state_dir/$db.seq"
  last_seq=""
  [ -f "$seq_file" ] && last_seq=$(cat "$seq_file")

  if [ -n "$last_seq" ] && [ "$current_seq" = "$last_seq" ]; then
    echo "Skipping $db — no changes since last backup."
    status=$(jq --arg db "$db" --arg seq "$current_seq" \
      '.databases[$db] = {status:"skipped", seq:$seq}' <<<"$status")
    continue
  fi

  echo "Backing up $db..."
  out="$backup_dir/${db}_$timestamp.json.gz"
  tmp="$out.tmp"
  # attachments=true inlines attachment bodies (base64) so restores are complete.
  # att_encoding_info=true preserves transport encoding (e.g. gzip) on round-trip.
  curl -fsS -u "$db_user:$db_pass" \
    "$db_url/$db/_all_docs?include_docs=true&attachments=true&att_encoding_info=true" \
    | gzip > "$tmp"
  mv "$tmp" "$out"
  printf '%s\n' "$current_seq" > "$seq_file"
  status=$(jq --arg db "$db" --arg seq "$current_seq" --arg file "$(basename "$out")" \
    '.databases[$db] = {status:"backed_up", seq:$seq, file:$file}' <<<"$status")
done

echo "Backup complete. Cleaning up old backups..."
# Touch the newest backup per db so mtime-based retention can't delete the only
# copy of a db that hasn't changed in $retention_days (would otherwise happen
# because we now skip unchanged dbs).
for db in $dbs; do
  latest=$(ls -1t "$backup_dir/${db}_"*.json.gz 2>/dev/null | head -n1 || true)
  [ -n "$latest" ] && touch "$latest"
done
find "$backup_dir" -type f -name '*.json.gz' -mtime +$retention_days -delete

# Health signal — external monitoring can alert on staleness of this file.
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '. + {last_success: $ts}' <<<"$status" > "$backup_dir/.status.json"
