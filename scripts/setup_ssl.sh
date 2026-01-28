#!/bin/bash

# Скрипт для настройки SSL сертификатов через Let's Encrypt

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Проверка наличия домена
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: $0 <your-domain.com> [email]${NC}"
    echo "Example: $0 proxy.example.com admin@example.com"
    echo
    echo "Перед получением сертификата рекомендуется проверить предварительные условия:"
    echo "  ./scripts/check_ssl_prerequisites.sh <domain>"
    exit 1
fi

DOMAIN=$1
EMAIL=${2:-"admin@${DOMAIN}"}

echo -e "${GREEN}Setting up SSL certificate for ${DOMAIN}${NC}"
echo
info "Рекомендуется сначала проверить предварительные условия:"
info "  ./scripts/check_ssl_prerequisites.sh ${DOMAIN}"
echo
read -p "Продолжить? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Установка certbot если не установлен
if ! command -v certbot &> /dev/null; then
    echo -e "${GREEN}Installing certbot...${NC}"
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
fi

# Создание директории для ACME challenge
mkdir -p /var/www/certbot

# Временная конфигурация Nginx для получения сертификата
if [ ! -f /etc/nginx/sites-available/proxy ]; then
    echo -e "${YELLOW}Creating temporary Nginx configuration...${NC}"
    cat > /etc/nginx/sites-available/proxy << EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    if [ ! -L /etc/nginx/sites-enabled/proxy ]; then
        ln -s /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled/
    fi
    
    rm -f /etc/nginx/sites-enabled/default
    
    nginx -t
    systemctl restart nginx
fi

# Проверка доступности домена
echo -e "${GREEN}Проверка доступности домена...${NC}"
if ! curl -I http://${DOMAIN} > /dev/null 2>&1; then
    warning "Домен ${DOMAIN} недоступен через HTTP. Проверьте:"
    echo "  1. DNS записи настроены правильно"
    echo "  2. Порт 80 открыт в firewall"
    echo "  3. Nginx запущен и слушает порт 80"
    echo
    read -p "Продолжить с standalone режимом? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    
    # Использование standalone режима
    echo -e "${GREEN}Получение сертификата в standalone режиме...${NC}"
    echo -e "${YELLOW}ВНИМАНИЕ: Nginx будет временно остановлен!${NC}"
    read -p "Продолжить? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    
    systemctl stop nginx
    certbot certonly \
        --standalone \
        --email ${EMAIL} \
        --agree-tos \
        --no-eff-email \
        --domains ${DOMAIN} \
        --preferred-challenges http
    systemctl start nginx
else
    # Использование webroot режима
    echo -e "${GREEN}Получение сертификата через webroot...${NC}"
    certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email ${EMAIL} \
        --agree-tos \
        --no-eff-email \
        --domains ${DOMAIN}
fi

# Обновление конфигурации Nginx
echo -e "${GREEN}Updating Nginx configuration...${NC}"
cat > /etc/nginx/sites-available/proxy << EOF
upstream proxy_backend {
    server 127.0.0.1:8080;
    keepalive 32;
}

server {
    listen 80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    client_max_body_size 10M;
    client_body_buffer_size 128k;

    proxy_connect_timeout 75s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;

    location / {
        proxy_pass http://proxy_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_buffering off;
        proxy_request_buffering off;
    }

    location /health {
        proxy_pass http://proxy_backend;
        access_log off;
    }
}
EOF

# Тестирование конфигурации
nginx -t

# Перезапуск Nginx
systemctl restart nginx

# Настройка автоматического обновления
echo -e "${GREEN}Setting up automatic certificate renewal...${NC}"
(crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -

echo -e "${GREEN}✅ SSL certificate setup completed!${NC}"
echo -e "${YELLOW}Certificate will be automatically renewed.${NC}"
echo -e "${GREEN}Your server is now available at: https://${DOMAIN}${NC}"
