#!/bin/bash

###############################################################################
# Скрипт автоматического развертывания прокси-сервера
# Для Ubuntu 22.04 LTS
# 
# ВАЖНО: Этот скрипт предполагает, что файлы проекта уже скопированы в /opt/proxy
# Для полной автоматической установки используйте scripts/install.sh
###############################################################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Обновление системы
echo -e "${GREEN}Updating system packages...${NC}"
apt-get update
apt-get upgrade -y

# Установка Docker через официальный репозиторий
echo -e "${GREEN}Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
    # Удаляем старые версии
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Устанавливаем зависимости
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Добавляем официальный GPG ключ Docker
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Добавляем репозиторий Docker
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    
    # Устанавливаем Docker и Docker Compose plugin
    apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
fi

# Установка остальных пакетов
echo -e "${GREEN}Installing required packages...${NC}"
apt-get install -y \
    nginx \
    certbot \
    python3-certbot-nginx \
    git \
    curl

# Запуск Docker
systemctl enable docker
systemctl start docker

# Создание директорий
echo -e "${GREEN}Creating directories...${NC}"
mkdir -p /opt/proxy
mkdir -p /opt/proxy/logs
mkdir -p /opt/proxy/backups

# Копирование файлов (предполагается, что код уже скопирован)
# Если нет, можно добавить git clone или scp

# Настройка переменных окружения
if [ ! -f /opt/proxy/.env ]; then
    echo -e "${YELLOW}Creating .env file...${NC}"
    cat > /opt/proxy/.env << EOF
DATABASE_URL=postgresql://proxy_user:CHANGE_PASSWORD@db:5432/proxy_db
REDIS_URL=redis://redis:6379/0
JWT_SECRET_KEY=$(openssl rand -hex 32)
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=30
SERVER_HOST=0.0.0.0
SERVER_PORT=8080
RATE_LIMIT_PER_MINUTE=60
MAX_REQUEST_SIZE_MB=10
DOMAIN=your-domain.com
EOF
    echo -e "${YELLOW}⚠️  Please edit /opt/proxy/.env and set your domain and passwords!${NC}"
fi

# Настройка Nginx
echo -e "${GREEN}Configuring Nginx...${NC}"
cat > /etc/nginx/sites-available/proxy << 'EOF'
server {
    listen 80;
    server_name _;

    client_max_body_size 10M;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
EOF

# Активация конфигурации Nginx
if [ ! -L /etc/nginx/sites-enabled/proxy ]; then
    ln -s /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled/
fi

# Удаление дефолтной конфигурации
rm -f /etc/nginx/sites-enabled/default

# Тестирование конфигурации Nginx
nginx -t

# Запуск Nginx
systemctl restart nginx
systemctl enable nginx

# Определяем команду docker compose для systemd
if docker compose version > /dev/null 2>&1; then
    COMPOSE_CMD="/usr/bin/docker compose"
else
    COMPOSE_CMD="/usr/bin/docker-compose"
fi

# Создание systemd сервиса для приложения
cat > /etc/systemd/system/proxy.service << EOF
[Unit]
Description=Proxy Server
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/proxy
ExecStart=${COMPOSE_CMD} up -d
ExecStop=${COMPOSE_CMD} down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Перезагрузка systemd
systemctl daemon-reload

# Инициализация базы данных
echo -e "${GREEN}Initializing database...${NC}"
cd /opt/proxy

# Определяем команду docker compose
if docker compose version > /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    DOCKER_COMPOSE_CMD="docker-compose"
fi

$DOCKER_COMPOSE_CMD up -d db redis
sleep 10
$DOCKER_COMPOSE_CMD exec -T app python init_db.py || echo "Database already initialized"

# Запуск приложения
echo -e "${GREEN}Starting application...${NC}"
systemctl enable proxy
systemctl start proxy

echo -e "${GREEN}✅ Deployment completed!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Edit /opt/proxy/.env with your domain and passwords"
echo "2. Run: certbot --nginx -d your-domain.com"
echo "3. Restart nginx: systemctl restart nginx"
echo "4. Check logs: docker-compose -f /opt/proxy/docker-compose.yml logs -f"
