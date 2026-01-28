#!/bin/bash

# Скрипт для резервного копирования базы данных

set -e

BACKUP_DIR="/opt/proxy/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "Creating database backup..."

# Определяем команду docker compose
if docker compose version > /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    DOCKER_COMPOSE_CMD="docker-compose"
fi

# Резервное копирование PostgreSQL
$DOCKER_COMPOSE_CMD -f /opt/proxy/docker-compose.yml exec -T db pg_dump -U proxy_user proxy_db | gzip > "$BACKUP_FILE"

echo "Backup created: $BACKUP_FILE"

# Удаление старых бэкапов (старше 7 дней)
find "$BACKUP_DIR" -name "backup_*.sql.gz" -mtime +7 -delete

echo "Old backups cleaned up"
