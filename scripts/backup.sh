#!/bin/bash

# Скрипт для резервного копирования базы данных

set -e

BACKUP_DIR="/opt/proxy/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "Creating database backup..."

# Резервное копирование PostgreSQL
docker-compose -f /opt/proxy/docker-compose.yml exec -T db pg_dump -U proxy_user proxy_db | gzip > "$BACKUP_FILE"

echo "Backup created: $BACKUP_FILE"

# Удаление старых бэкапов (старше 7 дней)
find "$BACKUP_DIR" -name "backup_*.sql.gz" -mtime +7 -delete

echo "Old backups cleaned up"
