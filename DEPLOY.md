# Инструкция по развертыванию на Ubuntu 22.04

## Предварительные требования

- Ubuntu 22.04 LTS
- Root доступ или sudo права
- Доменное имя (для SSL сертификатов)

## Автоматическое развертывание

1. Скопируйте проект на сервер:
```bash
scp -r proxy/ user@your-server:/opt/
```

2. Запустите скрипт развертывания:
```bash
cd /opt/proxy
chmod +x scripts/deploy.sh
sudo ./scripts/deploy.sh
```

3. Настройте переменные окружения:
```bash
sudo nano /opt/proxy/.env
```

Обязательно измените:
- `DATABASE_URL` - пароль базы данных
- `JWT_SECRET_KEY` - секретный ключ (уже сгенерирован)
- `DOMAIN` - ваш домен

4. Получите SSL сертификат:
```bash
sudo certbot --nginx -d your-domain.com
```

5. Перезапустите Nginx:
```bash
sudo systemctl restart nginx
```

## Ручное развертывание

### 1. Установка зависимостей

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose nginx certbot python3-certbot-nginx
```

### 2. Настройка Docker

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

### 3. Копирование проекта

```bash
sudo mkdir -p /opt/proxy
sudo cp -r /path/to/proxy/* /opt/proxy/
sudo chown -R $USER:$USER /opt/proxy
```

### 4. Настройка переменных окружения

Создайте файл `/opt/proxy/.env`:

```bash
cd /opt/proxy
cp .env.example .env
nano .env
```

Сгенерируйте секретный ключ:
```bash
openssl rand -hex 32
```

### 5. Запуск контейнеров

```bash
cd /opt/proxy
docker-compose up -d
```

### 6. Инициализация базы данных

```bash
docker-compose exec app python init_db.py
```

### 7. Настройка Nginx

Скопируйте конфигурацию:
```bash
sudo cp nginx/nginx.conf /etc/nginx/sites-available/proxy
sudo ln -s /etc/nginx/sites-available/proxy /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
```

Отредактируйте конфигурацию, заменив `your-domain.com` на ваш домен:
```bash
sudo nano /etc/nginx/sites-available/proxy
```

Проверьте конфигурацию:
```bash
sudo nginx -t
```

### 8. Получение SSL сертификата

```bash
sudo certbot --nginx -d your-domain.com
```

Certbot автоматически обновит конфигурацию Nginx.

### 9. Запуск сервисов

```bash
sudo systemctl restart nginx
sudo systemctl enable nginx
```

### 10. Создание systemd сервиса (опционально)

Создайте файл `/etc/systemd/system/proxy.service`:

```ini
[Unit]
Description=Proxy Server
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
```

Активируйте сервис:
```bash
sudo systemctl daemon-reload
sudo systemctl enable proxy
sudo systemctl start proxy
```

## Проверка работы

1. Проверьте статус контейнеров:
```bash
docker-compose ps
```

2. Проверьте логи:
```bash
docker-compose logs -f app
```

3. Проверьте health endpoint:
```bash
curl https://your-domain.com/health
```

4. Откройте документацию API:
```
https://your-domain.com/docs
```

## Резервное копирование

Настройте автоматическое резервное копирование через cron:

```bash
sudo crontab -e
```

Добавьте строку:
```
0 2 * * * /opt/proxy/scripts/backup.sh
```

Это будет создавать бэкап каждый день в 2:00 ночи.

## Обновление

1. Остановите контейнеры:
```bash
cd /opt/proxy
docker-compose down
```

2. Обновите код:
```bash
git pull  # или скопируйте новые файлы
```

3. Пересоберите образы:
```bash
docker-compose build
```

4. Запустите контейнеры:
```bash
docker-compose up -d
```

5. Примените миграции (если есть):
```bash
docker-compose exec app alembic upgrade head
```

## Мониторинг

### Логи

```bash
# Логи приложения
docker-compose logs -f app

# Логи базы данных
docker-compose logs -f db

# Логи Redis
docker-compose logs -f redis
```

### Метрики Prometheus

Метрики доступны по адресу: `https://your-domain.com/metrics`

### Health Check

```bash
curl https://your-domain.com/health
```

## Безопасность

1. **Измените пароли по умолчанию** в `.env`
2. **Настройте firewall**:
```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

3. **Регулярно обновляйте систему**:
```bash
sudo apt-get update && sudo apt-get upgrade
```

4. **Настройте автоматическое обновление SSL сертификатов**:
```bash
sudo certbot renew --dry-run
```

## Устранение неполадок

### Контейнеры не запускаются

```bash
docker-compose logs
docker-compose ps
```

### Проблемы с базой данных

```bash
docker-compose exec db psql -U proxy_user -d proxy_db
```

### Проблемы с Redis

```bash
docker-compose exec redis redis-cli ping
```

### Проблемы с Nginx

```bash
sudo nginx -t
sudo systemctl status nginx
sudo tail -f /var/log/nginx/error.log
```

## Дополнительные настройки

### Настройка логирования

Логи сохраняются в `/opt/proxy/logs/`. Настройте ротацию логов в `/etc/logrotate.d/proxy`:

```
/opt/proxy/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
```

### Оптимизация производительности

В `docker-compose.yml` можно настроить:
- Количество воркеров uvicorn
- Размер пула соединений БД
- Лимиты памяти для контейнеров
