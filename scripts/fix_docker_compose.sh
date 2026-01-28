#!/bin/bash

###############################################################################
# Скрипт для исправления проблемы с Docker Compose
# Устанавливает Docker Compose v2 через официальный репозиторий Docker
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    error "Пожалуйста, запустите скрипт с правами root: sudo $0"
fi

log "Исправление проблемы с Docker Compose..."

# Шаг 1: Удаление старой версии docker-compose
log "Удаление старой версии docker-compose..."
apt-get remove -y docker-compose 2>/dev/null || true

# Шаг 2: Установка зависимостей
log "Установка зависимостей..."
apt-get update -qq
apt-get install -y -qq \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Шаг 3: Добавление официального GPG ключа Docker
log "Добавление GPG ключа Docker..."
install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    log "GPG ключ добавлен"
else
    log "GPG ключ уже существует"
fi

# Шаг 4: Добавление репозитория Docker
log "Добавление репозитория Docker..."
ARCH=$(dpkg --print-architecture)
CODENAME=$(lsb_release -cs)

if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    echo \
      "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      ${CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    log "Репозиторий добавлен"
else
    log "Репозиторий уже существует"
fi

# Шаг 5: Обновление списка пакетов
log "Обновление списка пакетов..."
apt-get update -qq

# Шаг 6: Установка Docker (если не установлен)
if ! command -v docker &> /dev/null; then
    log "Установка Docker..."
    apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
else
    log "Docker уже установлен"
    # Установка только docker-compose-plugin
    apt-get install -y -qq docker-compose-plugin
fi

# Шаг 7: Запуск Docker
log "Запуск Docker..."
systemctl enable docker > /dev/null 2>&1
systemctl start docker > /dev/null 2>&1

# Шаг 8: Проверка установки
log "Проверка установки..."
if docker compose version > /dev/null 2>&1; then
    echo
    echo "==================================================================="
    echo -e "${GREEN}✅ Docker Compose v2 успешно установлен!${NC}"
    echo "==================================================================="
    echo
    docker compose version
    echo
    log "Теперь можно использовать команду: docker compose"
    log "Пример: docker compose up -d"
    echo
else
    error "Docker Compose не установлен. Проверьте ошибки выше."
fi
