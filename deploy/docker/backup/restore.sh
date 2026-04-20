#!/bin/bash
set -euo pipefail

# Load env snapshot written by cron-entrypoint.sh when available so manual
# `docker exec` invocations see the same config as the scheduled backup.
[ -f /etc/backup.env ] && . /etc/backup.env

backup_dir="${BACKUP_DIR:-/backups}"
db_url="${COUCHDB_URL:-http://couchdb:5984}"
db_user="${COUCHDB_USER:-admin}"
db_pass="${COUCHDB_PASSWORD:-password}"
batch_size="${RESTORE_BATCH_SIZE:-500}"

backups=($(ls -1 "$backup_dir"/*.json.gz 2>/dev/null || true))
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

filename=$(basename -- "$backup_file")
# Strip .json.gz, then strip the trailing _YYYYMMDD-HHMMSS suffix. Using %_* (not
# %%_*) keeps underscores in the db name intact — CouchDB permits them.
stem="${filename%.json.gz}"
db_name="${stem%_*}"

echo "You selected: $backup_file"
echo "Target database: $db_name"
echo "Restore uses _bulk_docs with new_edits=false, which preserves the original"
echo "revisions. Existing docs with the same _rev are left alone; divergent revs"
echo "become conflicts that LiveSync clients will resolve on next sync."
echo -n "Continue? (yes/no): "
read -r confirm
if [ "$confirm" != "yes" ]; then
  echo "Restore cancelled."
  exit 0
fi

# Ensure the database exists. 201/202 = created, 412 = already exists.
http_code=$(curl -sS -o /dev/null -w "%{http_code}" \
  -u "$db_user:$db_pass" -X PUT "$db_url/$db_name")
case "$http_code" in
  201|202|412) ;;
  *) echo "Failed to create/verify database (HTTP $http_code)"; exit 1 ;;
esac

echo "Restoring $db_name from $backup_file..."

# Chunk docs into batches of $batch_size, then POST each batch to _bulk_docs.
# new_edits:false tells CouchDB to accept the docs' existing _rev values verbatim
# (how replication works internally) rather than assigning new revisions.
gunzip -c "$backup_file" \
  | jq -c --argjson n "$batch_size" '
      [ .rows[].doc ] as $docs
      | range(0; $docs | length; $n)
      | { new_edits: false, docs: $docs[.:. + $n] }
    ' \
  | while read -r batch; do
      count=$(jq '.docs | length' <<<"$batch")
      echo "Uploading batch ($count docs)..."
      curl -fsS -o /dev/null \
        -u "$db_user:$db_pass" \
        -X POST "$db_url/$db_name/_bulk_docs" \
        -H 'Content-Type: application/json' \
        --data-binary @- <<<"$batch"
    done

echo "Restore complete."
