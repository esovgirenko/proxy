# Решение проблемы 404 при установке с GitHub

## Проблема

Ошибка `404` означает, что файл `install_from_github.sh` еще не закоммичен в репозиторий или находится в другой ветке.

## Решения

### Решение 1: Клонирование репозитория (рекомендуется)

Самый надежный способ - клонировать репозиторий и запустить установку:

```bash
# Клонировать репозиторий
git clone https://github.com/esovgirenko/proxy.git /tmp/proxy

# Перейти в директорию
cd /tmp/proxy

# Запустить установку
chmod +x scripts/install.sh
sudo ./scripts/install.sh
```

### Решение 2: Загрузка архива с GitHub

```bash
# Скачать архив
wget https://github.com/esovgirenko/proxy/archive/refs/heads/main.zip

# Распаковать
unzip main.zip

# Перейти в директорию
cd proxy-main

# Запустить установку
chmod +x scripts/install.sh
sudo ./scripts/install.sh
```

### Решение 3: Создать скрипт установки вручную

Если файл `install_from_github.sh` еще не в репозитории, создайте его вручную:

```bash
# Создать скрипт
cat > /tmp/install_from_github.sh << 'EOF'
#!/bin/bash
set -e

GITHUB_USER="${1:-esovgirenko}"
GITHUB_REPO_NAME="${2:-proxy}"
BRANCH="${3:-main}"
INSTALL_DIR="/opt/proxy"

echo "Клонирование репозитория..."
git clone -b "$BRANCH" "https://github.com/${GITHUB_USER}/${GITHUB_REPO_NAME}.git" /tmp/proxy-temp

echo "Копирование файлов..."
mkdir -p "$INSTALL_DIR"
cp -r /tmp/proxy-temp/* "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/scripts"/*.sh

echo "Запуск установки..."
cd "$INSTALL_DIR"
bash scripts/install.sh

rm -rf /tmp/proxy-temp
EOF

# Сделать исполняемым и запустить
chmod +x /tmp/install_from_github.sh
sudo /tmp/install_from_github.sh esovgirenko proxy
```

### Решение 4: Прямая установка без скрипта

```bash
# Установить git если не установлен
sudo apt-get update
sudo apt-get install -y git

# Клонировать и установить одной командой
sudo bash -c "
  git clone https://github.com/esovgirenko/proxy.git /opt/proxy
  cd /opt/proxy
  chmod +x scripts/install.sh
  ./scripts/install.sh
"
```

## Проверка наличия файла в репозитории

Проверьте, существует ли файл:

```bash
# Проверить через GitHub API
curl -s https://api.github.com/repos/esovgirenko/proxy/contents/scripts/install_from_github.sh

# Или проверить напрямую
curl -I https://raw.githubusercontent.com/esovgirenko/proxy/main/scripts/install_from_github.sh
```

Если файл не существует, нужно:
1. Закоммитить файл в репозиторий
2. Запушить в ветку `main`
3. Затем использовать скрипт

## Рекомендуемый порядок действий

### Шаг 1: Клонировать репозиторий

```bash
git clone https://github.com/esovgirenko/proxy.git /tmp/proxy
cd /tmp/proxy
```

### Шаг 2: Проверить наличие файлов

```bash
ls -la scripts/
# Должны быть файлы: install.sh, security.sh, setup_ssl.sh и др.
```

### Шаг 3: Запустить установку

```bash
chmod +x scripts/install.sh
sudo ./scripts/install.sh
```

### Шаг 4: После установки

```bash
# Настройка безопасности
sudo /opt/proxy/scripts/security.sh

# Настройка SSL
sudo /opt/proxy/scripts/setup_ssl.sh sovgirenko.pro
```

## Если нужно добавить install_from_github.sh в репозиторий

Если файл `install_from_github.sh` создан локально, но не закоммичен:

```bash
# На локальной машине
cd /path/to/proxy
git add scripts/install_from_github.sh
git commit -m "Add install_from_github.sh script"
git push origin main
```

После этого скрипт будет доступен по URL:
```
https://raw.githubusercontent.com/esovgirenko/proxy/main/scripts/install_from_github.sh
```

## Быстрая команда для установки

Используйте эту команду для быстрой установки:

```bash
sudo bash -c "
  apt-get update -qq && apt-get install -y -qq git
  git clone https://github.com/esovgirenko/proxy.git /opt/proxy
  cd /opt/proxy
  chmod +x scripts/install.sh
  ./scripts/install.sh
"
```

Эта команда:
1. Установит git (если не установлен)
2. Клонирует репозиторий
3. Запустит установку
