#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR=/root/backups
TS=$(date +%F_%H-%M-%S)
DB=family_ledger
USER=bill_user
export PGPASSWORD='QWEqwe111!'

mkdir -p "$BACKUP_DIR"

pg_dump -h 127.0.0.1 -U "$USER" -d "$DB" -F c -f "$BACKUP_DIR/${DB}_${TS}.dump"
pg_dump -h 127.0.0.1 -U "$USER" -d "$DB" -F p | gzip > "$BACKUP_DIR/${DB}_${TS}.sql.gz"

find "$BACKUP_DIR" -type f -name "${DB}_*" -mtime +30 -delete
