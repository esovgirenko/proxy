#!/bin/bash

###############################################################################
# Быстрая установка прокси-сервера с GitHub
# Использование: curl -fsSL https://raw.githubusercontent.com/esovgirenko/proxy/main/scripts/quick_install.sh | sudo bash
# Или: wget -qO- ... | sudo bash
###############################################################################

set -e

GITHUB_USER="${1:-esovgirenko}"
GITHUB_REPO="${2:-proxy}"
BRANCH="${3:-main}"
INSTALL_DIR="/opt/proxy"

echo "==================================================================="
echo "Установка прокси-сервера с GitHub"
echo "Репозиторий: https://github.com/${GITHUB_USER}/${GITHUB_REPO}"
echo "==================================================================="
echo

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo "Ошибка: Запустите с правами root: sudo bash $0"
    exit 1
fi

# Установка git если не установлен
if ! command -v git &> /dev/null; then
    echo "Установка git..."
    apt-get update -qq
    apt-get install -y -qq git
fi

# Создание временной директории
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Клонирование репозитория
echo "Клонирование репозитория..."
cd "$TEMP_DIR"
if git clone -b "$BRANCH" "https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git" proxy 2>&1; then
    echo "✓ Репозиторий успешно клонирован"
else
    echo "Ошибка: Не удалось клонировать репозиторий"
    exit 1
fi

# Проверка наличия install.sh
if [ ! -f "proxy/scripts/install.sh" ]; then
    echo "Ошибка: Не найден файл scripts/install.sh"
    exit 1
fi

# Копирование в целевую директорию
echo "Копирование файлов в $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp -r proxy/* "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/scripts"/*.sh 2>/dev/null || true
echo "✓ Файлы скопированы"

# Запуск установки
echo "Запуск установки..."
cd "$INSTALL_DIR"
bash scripts/install.sh

echo "✓ Установка завершена!"
