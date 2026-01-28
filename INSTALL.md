# Подробная инструкция по установке

## Содержание

1. [Требования](#требования)
2. [Подготовка сервера](#подготовка-сервера)
3. [Автоматическая установка](#автоматическая-установка)
4. [Ручная установка](#ручная-установка)
5. [Настройка SSL](#настройка-ssl)
6. [Проверка работы](#проверка-работы)
7. [Устранение неполадок](#устранение-неполадок)

## Требования

### Минимальные требования

- **ОС**: Ubuntu 22.04 LTS (рекомендуется) или Ubuntu 20.04 LTS
- **RAM**: 2 GB (рекомендуется 4 GB)
- **CPU**: 2 ядра (рекомендуется 4 ядра)
- **Диск**: 20 GB свободного места
- **Сеть**: Статический IP адрес и доменное имя (для продакшна)

### Сетевые требования

- Порт 22 (SSH) - для управления сервером
- Порт 80 (HTTP) - для веб-доступа и Let's Encrypt
- Порт 443 (HTTPS) - для защищенного доступа
- Порт 8080 - внутренний порт приложения (не должен быть открыт наружу)

## Подготовка сервера

### 1. Подключение к серверу

```bash
ssh root@your-server-ip
# или
ssh user@your-server-ip
sudo su
```

### 2. Обновление системы

```bash
apt-get update
apt-get upgrade -y
```

### 3. Настройка часового пояса (опционально)

```bash
timedatectl set-timezone Europe/Moscow
```

### 4. Создание пользователя для приложения (опционально)

```bash
adduser proxyuser
usermod -aG sudo proxyuser
```

## Автоматическая установка

### Способ 1: Установка с локального компьютера

1. **Скачайте проект на ваш локальный компьютер**

```bash
git clone <repository-url> proxy
# или распакуйте архив проекта
```

2. **Скопируйте проект на сервер**

```bash
# С локального компьютера
scp -r proxy/ root@your-server-ip:/tmp/
```

3. **Подключитесь к серверу и запустите установку**

```bash
ssh root@your-server-ip
cd /tmp/proxy
chmod +x scripts/install.sh
./scripts/install.sh
```

### Способ 2: Установка напрямую на сервере

1. **Скачайте проект на сервер**

```bash
cd /tmp
wget <repository-url>/archive/main.zip
unzip main.zip
cd proxy-main
# или
git clone <repository-url> proxy
cd proxy
```

2. **Запустите скрипт установки**

```bash
chmod +x scripts/install.sh
sudo ./scripts/install.sh
```

### Что делает скрипт установки

Скрипт `install.sh` автоматически выполняет следующие действия:

1. ✅ Проверяет права доступа и операционную систему
2. ✅ Обновляет систему и устанавливает необходимые пакеты
3. ✅ Настраивает Docker и Docker Compose
4. ✅ Настраивает firewall (UFW)
5. ✅ Создает необходимые директории
6. ✅ Копирует файлы проекта
7. ✅ Настраивает переменные окружения (генерирует секреты)
8. ✅ Настраивает Nginx как reverse proxy
9. ✅ Создает systemd сервис
10. ✅ Инициализирует базу данных
11. ✅ Запускает приложение
12. ✅ Настраивает автоматическое резервное копирование

### Взаимодействие со скриптом

Во время установки скрипт запросит:

- **Доменное имя**: Введите домен для вашего прокси-сервера (например: `proxy.example.com`)
  - Если не указать, будет использован `localhost`

После установки скрипт выведет:
- Доменное имя сервера
- Учетные данные администратора по умолчанию
- Пароль базы данных (сохраните его!)
- JWT секретный ключ (сохраните его!)

## Ручная установка

Если вы предпочитаете установку вручную, следуйте этим шагам:

### Шаг 1: Установка зависимостей

```bash
apt-get update
apt-get install -y \
    docker.io \
    docker-compose \
    nginx \
    certbot \
    python3-certbot-nginx \
    git \
    curl \
    wget \
    ufw
```

### Шаг 2: Настройка Docker

```bash
systemctl enable docker
systemctl start docker
docker --version
```

### Шаг 3: Настройка Firewall

```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
ufw status
```

### Шаг 4: Копирование проекта

```bash
mkdir -p /opt/proxy
# Скопируйте все файлы проекта в /opt/proxy
cp -r /path/to/proxy/* /opt/proxy/
```

### Шаг 5: Настройка переменных окружения

```bash
cd /opt/proxy
cp .env.example .env
nano .env
```

Обязательно установите:
- `DATABASE_URL` - строка подключения к БД
- `REDIS_URL` - строка подключения к Redis
- `JWT_SECRET_KEY` - сгенерируйте: `openssl rand -hex 32`
- `DOMAIN` - ваш домен

### Шаг 6: Обновление docker-compose.yml

Убедитесь, что пароли в `docker-compose.yml` совпадают с `.env`:

```bash
nano docker-compose.yml
```

### Шаг 7: Запуск контейнеров

```bash
docker-compose up -d
```

### Шаг 8: Инициализация базы данных

```bash
docker-compose exec app python init_db.py
```

### Шаг 9: Настройка Nginx

```bash
cp nginx/nginx.conf /etc/nginx/sites-available/proxy
ln -s /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx
```

### Шаг 10: Создание systemd сервиса

```bash
cat > /etc/systemd/system/proxy.service << 'EOF'
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
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable proxy
systemctl start proxy
```

## Настройка SSL

### Автоматическая настройка SSL

После установки запустите скрипт настройки SSL:

```bash
/opt/proxy/scripts/setup_ssl.sh your-domain.com your-email@example.com
```

Скрипт автоматически:
- Установит certbot (если не установлен)
- Получит SSL сертификат от Let's Encrypt
- Настроит Nginx для HTTPS
- Настроит автоматическое обновление сертификатов

### Ручная настройка SSL

1. **Получение сертификата**

```bash
certbot certonly --webroot \
  --webroot-path=/var/www/certbot \
  --email your-email@example.com \
  --agree-tos \
  --no-eff-email \
  -d your-domain.com
```

2. **Обновление конфигурации Nginx**

Отредактируйте `/etc/nginx/sites-available/proxy` и добавьте SSL настройки:

```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    # ... остальная конфигурация
}
```

3. **Настройка автоматического обновления**

```bash
(crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
```

## Проверка работы

### 1. Проверка статуса контейнеров

```bash
cd /opt/proxy
docker-compose ps
```

Все контейнеры должны быть в статусе "Up".

### 2. Проверка логов

```bash
# Логи приложения
docker-compose logs -f app

# Логи базы данных
docker-compose logs -f db

# Логи Redis
docker-compose logs -f redis
```

### 3. Проверка health endpoint

```bash
curl http://localhost:8080/health
# или
curl https://your-domain.com/health
```

Ожидаемый ответ:
```json
{
  "status": "healthy",
  "database": "connected",
  "redis": "connected"
}
```

### 4. Проверка API документации

Откройте в браузере:
- `http://your-domain.com/docs` - Swagger UI
- `http://your-domain.com/redoc` - ReDoc

### 5. Тестирование регистрации

```bash
curl -X POST http://your-domain.com/api/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "username": "testuser",
    "password": "Test1234"
  }'
```

### 6. Тестирование входа

```bash
curl -X POST http://your-domain.com/api/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "admin123"
  }'
```

## Устранение неполадок

### Проблема: Контейнеры не запускаются

**Решение:**
```bash
cd /opt/proxy
docker-compose logs
docker-compose ps
docker-compose down
docker-compose up -d
```

### Проблема: База данных не подключается

**Решение:**
```bash
# Проверка подключения
docker-compose exec db psql -U proxy_user -d proxy_db

# Проверка переменных окружения
cat /opt/proxy/.env | grep DATABASE_URL

# Пересоздание контейнера БД
docker-compose stop db
docker-compose rm -f db
docker-compose up -d db
```

### Проблема: Nginx не запускается

**Решение:**
```bash
# Проверка конфигурации
nginx -t

# Просмотр ошибок
tail -f /var/log/nginx/error.log

# Перезапуск
systemctl restart nginx
systemctl status nginx
```

### Проблема: Порт 8080 занят

**Решение:**
```bash
# Проверка занятости порта
netstat -tulpn | grep 8080

# Измените порт в .env и docker-compose.yml
nano /opt/proxy/.env
# SERVER_PORT=8081
```

### Проблема: SSL сертификат не получается

**Решение:**
```bash
# Проверка доступности домена
curl -I http://your-domain.com

# Проверка DNS
nslookup your-domain.com

# Ручное получение сертификата
certbot certonly --standalone -d your-domain.com
```

### Проблема: Приложение не отвечает

**Решение:**
```bash
# Проверка systemd сервиса
systemctl status proxy

# Перезапуск
systemctl restart proxy

# Проверка логов
journalctl -u proxy -f
```

### Проблема: Ошибки в логах приложения

**Решение:**
```bash
# Просмотр логов
docker-compose logs -f app

# Проверка переменных окружения
docker-compose exec app env | grep -E "DATABASE|REDIS|JWT"

# Пересоздание контейнера
docker-compose restart app
```

## Дополнительная настройка

### Настройка мониторинга

См. раздел "Мониторинг" в [DEPLOY.md](DEPLOY.md)

### Настройка резервного копирования

Автоматическое резервное копирование настроено по умолчанию (каждый день в 2:00).

Ручной бэкап:
```bash
/opt/proxy/scripts/backup.sh
```

### Настройка логирования

Логи сохраняются в `/opt/proxy/logs/`. Настройте ротацию:

```bash
cat > /etc/logrotate.d/proxy << 'EOF'
/opt/proxy/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
EOF
```

### Обновление приложения

```bash
cd /opt/proxy
docker-compose down
# Обновите файлы проекта
docker-compose build
docker-compose up -d
docker-compose exec app alembic upgrade head
```

## Безопасность

### После установки обязательно:

1. ✅ Смените пароль администратора
2. ✅ Настройте SSL сертификат
3. ✅ Ограничьте доступ к админ-панели (если нужно)
4. ✅ Настройте регулярные обновления системы
5. ✅ Настройте мониторинг и алерты

### Рекомендации по безопасности:

- Используйте сильные пароли
- Регулярно обновляйте систему: `apt-get update && apt-get upgrade`
- Настройте fail2ban для защиты от брут-форса
- Используйте SSH ключи вместо паролей
- Ограничьте доступ к портам через firewall
- Регулярно проверяйте логи на подозрительную активность

## Поддержка

Если возникли проблемы:

1. Проверьте логи: `/var/log/proxy_install.log`
2. Проверьте документацию: [README.md](README.md), [API.md](API.md)
3. Проверьте статус сервисов: `systemctl status proxy`

## Следующие шаги

После успешной установки:

1. ✅ Настройте SSL: `/opt/proxy/scripts/setup_ssl.sh your-domain.com`
2. ✅ Смените пароль администратора
3. ✅ Изучите API документацию: `https://your-domain.com/docs`
4. ✅ Настройте мониторинг (опционально)
5. ✅ Настройте резервное копирование (уже настроено автоматически)
