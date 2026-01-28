#!/bin/bash

###############################################################################
# Скрипт автоматической установки прокси-сервера с авторизацией
# Для Ubuntu 22.04 LTS
###############################################################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Логирование
LOG_FILE="/var/log/proxy_install.log"
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Проверка прав root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        error "Пожалуйста, запустите скрипт с правами root: sudo $0"
    fi
}

# Проверка ОС
check_os() {
    if [ ! -f /etc/os-release ]; then
        error "Не удалось определить операционную систему"
    fi
    
    . /etc/os-release
    
    if [ "$ID" != "ubuntu" ] || [ "$VERSION_ID" != "22.04" ]; then
        warning "Скрипт протестирован на Ubuntu 22.04. Текущая ОС: $PRETTY_NAME"
        read -p "Продолжить установку? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log "Операционная система: $PRETTY_NAME"
}

# Обновление системы
update_system() {
    log "Обновление списка пакетов..."
    apt-get update -qq
    
    log "Обновление установленных пакетов..."
    apt-get upgrade -y -qq
    
    log "Система обновлена"
}

# Установка необходимых пакетов
install_packages() {
    log "Установка необходимых пакетов..."
    
    local packages=(
        "docker.io"
        "docker-compose"
        "nginx"
        "certbot"
        "python3-certbot-nginx"
        "git"
        "curl"
        "wget"
        "ufw"
        "htop"
        "nano"
    )
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            log "Установка $package..."
            apt-get install -y -qq "$package"
        else
            info "$package уже установлен"
        fi
    done
    
    log "Все пакеты установлены"
}

# Настройка Docker
setup_docker() {
    log "Настройка Docker..."
    
    # Запуск Docker
    systemctl enable docker > /dev/null 2>&1
    systemctl start docker > /dev/null 2>&1
    
    # Проверка работы Docker
    if ! docker ps > /dev/null 2>&1; then
        error "Docker не запустился. Проверьте логи: journalctl -u docker"
    fi
    
    log "Docker настроен и запущен"
}

# Настройка firewall
setup_firewall() {
    log "Настройка firewall (UFW)..."
    
    # Разрешаем SSH (важно сделать первым!)
    ufw allow 22/tcp comment 'SSH' > /dev/null 2>&1 || true
    
    # Разрешаем HTTP и HTTPS
    ufw allow 80/tcp comment 'HTTP' > /dev/null 2>&1
    ufw allow 443/tcp comment 'HTTPS' > /dev/null 2>&1
    
    # Включаем firewall (если еще не включен)
    if ! ufw status | grep -q "Status: active"; then
        echo "y" | ufw enable > /dev/null 2>&1
    fi
    
    log "Firewall настроен"
    
    # Предложение настроить полную безопасность
    echo
    info "Для полной настройки безопасности запустите:"
    info "  /opt/proxy/scripts/security.sh"
    echo
}

# Создание директорий
create_directories() {
    log "Создание директорий..."
    
    local dirs=(
        "/opt/proxy"
        "/opt/proxy/logs"
        "/opt/proxy/backups"
        "/var/www/certbot"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        chmod 755 "$dir"
    done
    
    log "Директории созданы"
}

# Копирование файлов проекта
copy_project_files() {
    log "Копирование файлов проекта..."
    
    local project_dir="/opt/proxy"
    
    # Если скрипт запущен из директории проекта
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    
    if [ -f "$script_dir/docker-compose.yml" ]; then
        log "Копирование файлов из $script_dir..."
        cp -r "$script_dir"/* "$project_dir/" 2>/dev/null || true
        # Исключаем некоторые файлы
        rm -f "$project_dir/.git" "$project_dir/.gitignore" 2>/dev/null || true
    else
        warning "Не найдены файлы проекта. Убедитесь, что все файлы скопированы в $project_dir"
    fi
    
    # Установка прав
    chmod +x "$project_dir/scripts"/*.sh 2>/dev/null || true
    
    log "Файлы проекта скопированы"
}

# Настройка переменных окружения
setup_env() {
    log "Настройка переменных окружения..."
    
    local env_file="/opt/proxy/.env"
    
    if [ -f "$env_file" ]; then
        warning "Файл .env уже существует. Создаю резервную копию..."
        cp "$env_file" "$env_file.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Генерация секретного ключа
    local jwt_secret=$(openssl rand -hex 32)
    local db_password=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
    
    # Запрашиваем домен
    echo
    info "Введите доменное имя для вашего прокси-сервера (например: proxy.example.com)"
    read -p "Домен: " domain
    
    if [ -z "$domain" ]; then
        domain="localhost"
        warning "Домен не указан, используется localhost"
    fi
    
    # Создание .env файла
    cat > "$env_file" << EOF
# Database
DATABASE_URL=postgresql://proxy_user:${db_password}@db:5432/proxy_db

# Redis
REDIS_URL=redis://redis:6379/0

# JWT
JWT_SECRET_KEY=${jwt_secret}
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=30

# Server
SERVER_HOST=0.0.0.0
SERVER_PORT=8080

# Security
RATE_LIMIT_PER_MINUTE=60
MAX_REQUEST_SIZE_MB=10

# Domain
DOMAIN=${domain}

# Email (optional, for email activation)
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASSWORD=
EMAIL_FROM=noreply@${domain}

# Sentry (optional, for error tracking)
SENTRY_DSN=
EOF
    
    chmod 600 "$env_file"
    
    log "Переменные окружения настроены"
    info "Пароль базы данных: ${db_password}"
    info "JWT секретный ключ сгенерирован автоматически"
    warning "Сохраните эти данные в безопасном месте!"
}

# Обновление docker-compose.yml с правильным паролем БД
update_docker_compose() {
    log "Обновление docker-compose.yml..."
    
    local compose_file="/opt/proxy/docker-compose.yml"
    local db_password=$(grep "POSTGRES_PASSWORD" /opt/proxy/.env | cut -d'=' -f2 | cut -d'@' -f1 | cut -d':' -f3)
    
    if [ -f "$compose_file" ] && [ -n "$db_password" ]; then
        # Обновляем пароль в docker-compose.yml
        sed -i "s/POSTGRES_PASSWORD:.*/POSTGRES_PASSWORD: ${db_password}/" "$compose_file" 2>/dev/null || true
    fi
}

# Настройка Nginx
setup_nginx() {
    log "Настройка Nginx..."
    
    local nginx_config="/etc/nginx/sites-available/proxy"
    local domain=$(grep "^DOMAIN=" /opt/proxy/.env | cut -d'=' -f2)
    
    # Создание базовой конфигурации
    cat > "$nginx_config" << 'NGINX_EOF'
upstream proxy_backend {
    server 127.0.0.1:8080;
    keepalive 32;
}

# HTTP сервер (редирект на HTTPS после получения сертификата)
server {
    listen 80;
    server_name _;

    # Для Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Проксирование до получения SSL сертификата
    location / {
        proxy_pass http://proxy_backend;
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
NGINX_EOF
    
    # Активация конфигурации
    if [ ! -L /etc/nginx/sites-enabled/proxy ]; then
        ln -s /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled/
    fi
    
    # Удаление дефолтной конфигурации
    rm -f /etc/nginx/sites-enabled/default
    
    # Тестирование конфигурации
    if nginx -t > /dev/null 2>&1; then
        systemctl restart nginx
        systemctl enable nginx
        log "Nginx настроен и запущен"
    else
        error "Ошибка в конфигурации Nginx. Проверьте: nginx -t"
    fi
}

# Создание systemd сервиса
create_systemd_service() {
    log "Создание systemd сервиса..."
    
    cat > /etc/systemd/system/proxy.service << 'SERVICE_EOF'
[Unit]
Description=Proxy Server with Authentication
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/proxy
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
ExecReload=/usr/bin/docker-compose restart
TimeoutStartSec=0
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF
    
    systemctl daemon-reload
    systemctl enable proxy > /dev/null 2>&1
    
    log "Systemd сервис создан"
}

# Инициализация базы данных
init_database() {
    log "Инициализация базы данных..."
    
    cd /opt/proxy
    
    # Запуск контейнеров БД и Redis
    docker-compose up -d db redis
    
    # Ожидание готовности БД
    log "Ожидание готовности базы данных..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker-compose exec -T db pg_isready -U proxy_user > /dev/null 2>&1; then
            break
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    if [ $attempt -eq $max_attempts ]; then
        error "База данных не запустилась за отведенное время"
    fi
    
    # Инициализация БД
    if docker-compose exec -T app python init_db.py 2>/dev/null; then
        log "База данных инициализирована"
    else
        warning "Ошибка при инициализации БД. Попробуйте вручную: docker-compose exec app python init_db.py"
    fi
}

# Запуск приложения
start_application() {
    log "Запуск приложения..."
    
    cd /opt/proxy
    
    # Запуск всех контейнеров
    docker-compose up -d
    
    # Ожидание запуска
    sleep 5
    
    # Проверка статуса
    if docker-compose ps | grep -q "Up"; then
        log "Приложение запущено"
    else
        warning "Возможны проблемы с запуском контейнеров. Проверьте: docker-compose ps"
    fi
}

# Настройка автоматического резервного копирования
setup_backup_cron() {
    log "Настройка автоматического резервного копирования..."
    
    local backup_script="/opt/proxy/scripts/backup.sh"
    
    if [ -f "$backup_script" ]; then
        chmod +x "$backup_script"
        
        # Добавление в crontab (если еще не добавлено)
        (crontab -l 2>/dev/null | grep -v "$backup_script"; echo "0 2 * * * $backup_script >> /var/log/proxy_backup.log 2>&1") | crontab -
        
        log "Автоматическое резервное копирование настроено (каждый день в 2:00)"
    fi
}

# Вывод итоговой информации
print_summary() {
    local domain=$(grep "^DOMAIN=" /opt/proxy/.env | cut -d'=' -f2)
    
    echo
    echo "==================================================================="
    echo -e "${GREEN}✅ Установка завершена успешно!${NC}"
    echo "==================================================================="
    echo
    echo "📋 Информация о сервере:"
    echo "   - Домен: $domain"
    echo "   - HTTP: http://$domain"
    echo "   - API документация: http://$domain/docs"
    echo "   - Health check: http://$domain/health"
    echo
    echo "🔐 Учетные данные администратора:"
    echo "   - Email: admin@example.com"
    echo "   - Password: admin123"
    echo -e "   ${RED}⚠️  ВАЖНО: Смените пароль после первого входа!${NC}"
    echo
    echo "📁 Расположение файлов:"
    echo "   - Приложение: /opt/proxy"
    echo "   - Логи: /opt/proxy/logs"
    echo "   - Бэкапы: /opt/proxy/backups"
    echo "   - Лог установки: $LOG_FILE"
    echo
    echo "🔧 Полезные команды:"
    echo "   - Статус: systemctl status proxy"
    echo "   - Логи: docker-compose -f /opt/proxy/docker-compose.yml logs -f"
    echo "   - Перезапуск: systemctl restart proxy"
    echo "   - Бэкап: /opt/proxy/scripts/backup.sh"
    echo
    echo "🔒 Следующие шаги:"
    echo "   1. Настройте безопасность системы:"
    echo "      /opt/proxy/scripts/security.sh"
    echo "   2. Настройте SSL сертификат:"
    echo "      /opt/proxy/scripts/setup_ssl.sh $domain"
    echo "   3. Смените пароль администратора"
    echo "   4. Настройте мониторинг (опционально)"
    echo
    echo "==================================================================="
}

# Главная функция
main() {
    clear
    echo "==================================================================="
    echo -e "${GREEN}Установка прокси-сервера с авторизацией${NC}"
    echo "==================================================================="
    echo
    
    check_root
    check_os
    
    log "Начало установки..."
    
    update_system
    install_packages
    setup_docker
    setup_firewall
    create_directories
    copy_project_files
    setup_env
    update_docker_compose
    setup_nginx
    create_systemd_service
    init_database
    start_application
    setup_backup_cron
    
    print_summary
    
    log "Установка завершена. Лог сохранен в $LOG_FILE"
}

# Запуск
main "$@"
