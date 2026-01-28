#!/bin/bash

###############################################################################
# Скрипт для установки прокси-сервера напрямую с GitHub
# Использование: 
#   curl ... | sudo bash -s -- USERNAME REPO_NAME [BRANCH]
#   Или: wget ... && sudo ./install_from_github.sh USERNAME REPO_NAME
###############################################################################

set -e

# Цвета
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

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    error "Пожалуйста, запустите скрипт с правами root: sudo bash $0"
fi

# Параметры из аргументов командной строки
if [ -n "$1" ] && [ -n "$2" ]; then
    GITHUB_USER="$1"
    GITHUB_REPO_NAME="$2"
    BRANCH="${3:-main}"
    GITHUB_REPO="https://github.com/${GITHUB_USER}/${GITHUB_REPO_NAME}.git"
    log "Использованы параметры из командной строки: $GITHUB_USER/$GITHUB_REPO_NAME (ветка: $BRANCH)"
elif [ -n "$GITHUB_USER" ] && [ -n "$GITHUB_REPO_NAME" ]; then
    # Параметры из переменных окружения (если переданы через sudo -E)
    BRANCH="${BRANCH:-main}"
    GITHUB_REPO="https://github.com/${GITHUB_USER}/${GITHUB_REPO_NAME}.git"
    log "Использованы параметры из переменных окружения: $GITHUB_USER/$GITHUB_REPO_NAME"
else
    # Интерактивный режим
    echo "==================================================================="
    echo -e "${GREEN}Установка прокси-сервера с GitHub${NC}"
    echo "==================================================================="
    echo
    echo "Введите данные репозитория GitHub:"
    echo
    read -p "GitHub username или organization: " GITHUB_USER
    read -p "Название репозитория (например: proxy): " GITHUB_REPO_NAME
    read -p "Ветка (по умолчанию: main): " BRANCH_INPUT
    
    if [ -n "$BRANCH_INPUT" ]; then
        BRANCH="$BRANCH_INPUT"
    else
        BRANCH="main"
    fi
    
    GITHUB_REPO="https://github.com/${GITHUB_USER}/${GITHUB_REPO_NAME}.git"
fi

INSTALL_DIR="${INSTALL_DIR:-/opt/proxy}"

# Если все еще не задано
if [ -z "$GITHUB_REPO" ] || [ -z "$GITHUB_USER" ] || [ -z "$GITHUB_REPO_NAME" ]; then
    error "Не указан репозиторий GitHub."
    echo
    echo "Используйте один из вариантов:"
    echo "  1. bash $0 USERNAME REPO_NAME [BRANCH]"
    echo "     Пример: bash $0 esovgirenko proxy main"
    echo
    echo "  2. sudo -E GITHUB_USER=username GITHUB_REPO_NAME=repo bash $0"
    echo "     (флаг -E сохраняет переменные окружения)"
    echo
    echo "  3. Запустите без параметров для интерактивного режима"
    exit 1
fi

log "Репозиторий: $GITHUB_REPO"
log "Ветка: $BRANCH"
log "Директория установки: $INSTALL_DIR"
echo

# Установка git если не установлен
if ! command -v git &> /dev/null; then
    log "Установка git..."
    apt-get update -qq
    apt-get install -y -qq git
fi

# Создание временной директории
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

log "Загрузка проекта с GitHub..."
cd "$TEMP_DIR"

# Клонирование репозитория
if git clone -b "$BRANCH" "$GITHUB_REPO" proxy 2>/dev/null; then
    log "Проект успешно загружен"
else
    error "Не удалось загрузить проект. Проверьте:"
    echo "  - Правильность URL репозитория"
    echo "  - Доступность репозитория (публичный или есть доступ)"
    echo "  - Правильность названия ветки"
fi

# Проверка наличия необходимых файлов
if [ ! -f "proxy/scripts/install.sh" ]; then
    error "Не найден файл scripts/install.sh в репозитории"
fi

# Копирование проекта в целевую директорию
log "Копирование файлов в $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp -r proxy/* "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/scripts"/*.sh 2>/dev/null || true

log "Файлы скопированы"

# Запуск основного скрипта установки
log "Запуск скрипта установки..."
cd "$INSTALL_DIR"
bash scripts/install.sh

log "Установка завершена!"
