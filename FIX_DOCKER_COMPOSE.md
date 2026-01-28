# Исправление проблемы с Docker Compose

## Проблема

При попытке установить `docker-compose-plugin` возникает ошибка:
```
E: Unable to locate package docker-compose-plugin
```

Это означает, что официальный репозиторий Docker не добавлен в систему.

## Быстрое решение

### Вариант 1: Автоматический скрипт (рекомендуется)

```bash
cd /path/to/proxy
chmod +x scripts/fix_docker_compose.sh
sudo ./scripts/fix_docker_compose.sh
```

### Вариант 2: Ручная установка

Выполните следующие команды по порядку:

```bash
# 1. Удалить старую версию docker-compose (если установлена)
sudo apt-get remove -y docker-compose

# 2. Установить зависимости
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 3. Добавить официальный GPG ключ Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 4. Добавить репозиторий Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Обновить список пакетов
sudo apt-get update

# 6. Установить Docker Compose plugin
sudo apt-get install -y docker-compose-plugin

# 7. Проверить установку
docker compose version
```

## Проверка установки

После установки проверьте:

```bash
# Проверка версии Docker Compose v2
docker compose version

# Должно вывести что-то вроде:
# Docker Compose version v2.x.x
```

## Использование

Теперь используйте команду с **пробелом** (не дефисом):

```bash
# Правильно (v2)
docker compose up -d
docker compose ps
docker compose logs
docker compose down

# Неправильно (старая версия v1)
docker-compose up -d  # Это старая версия
```

## Продолжение установки прокси-сервера

После исправления Docker Compose, продолжите установку:

```bash
cd /opt/proxy

# Инициализация базы данных
docker compose up -d db redis
sleep 10
docker compose exec -T app python init_db.py

# Запуск всех контейнеров
docker compose up -d

# Проверка статуса
docker compose ps
```

## Если Docker не установлен

Если Docker вообще не установлен, установите его полностью:

```bash
# Удалить старые версии
sudo apt-get remove -y docker docker-engine docker.io containerd runc

# Установить зависимости
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Добавить GPG ключ
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Добавить репозиторий
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Установить Docker
sudo apt-get update
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Запустить Docker
sudo systemctl enable docker
sudo systemctl start docker

# Проверить
docker --version
docker compose version
```

## Обновление systemd сервиса

Если systemd сервис уже создан, обновите его для использования Docker Compose v2:

```bash
# Определить команду
if docker compose version > /dev/null 2>&1; then
    COMPOSE_CMD="/usr/bin/docker compose"
else
    COMPOSE_CMD="/usr/bin/docker-compose"
fi

# Обновить сервис
sudo tee /etc/systemd/system/proxy.service > /dev/null << EOF
[Unit]
Description=Proxy Server with Authentication
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/proxy
ExecStart=${COMPOSE_CMD} up -d
ExecStop=${COMPOSE_CMD} down
ExecReload=${COMPOSE_CMD} restart
TimeoutStartSec=0
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Перезагрузить systemd
sudo systemctl daemon-reload
sudo systemctl restart proxy
```

## Устранение неполадок

### Проблема: "Permission denied" при использовании docker

**Решение:**
```bash
# Добавить пользователя в группу docker
sudo usermod -aG docker $USER

# Выйти и войти снова, или выполнить:
newgrp docker

# Проверить
docker ps
```

### Проблема: Репозиторий не добавляется

**Решение:**
```bash
# Проверить архитектуру
dpkg --print-architecture

# Проверить кодовое имя
lsb_release -cs

# Проверить файл репозитория
cat /etc/apt/sources.list.d/docker.list
```

### Проблема: GPG ключ не добавляется

**Решение:**
```bash
# Удалить старый ключ
sudo rm -f /etc/apt/keyrings/docker.gpg

# Добавить заново
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

## Дополнительная информация

- **Официальная документация Docker**: https://docs.docker.com/engine/install/ubuntu/
- **Docker Compose v2**: https://docs.docker.com/compose/
- **Устранение неполадок**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
