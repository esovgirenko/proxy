# Устранение проблем с SSL сертификатами

## Ошибка: Timeout during connect (likely firewall problem)

Эта ошибка означает, что Let's Encrypt не может подключиться к вашему серверу для проверки домена.

### Причины:

1. **Firewall блокирует порт 80**
2. **Провайдер/облако блокирует порт 80**
3. **Nginx не настроен для /.well-known/acme-challenge/**
4. **DNS не настроен правильно**

## Решение

### Шаг 1: Проверка предварительных условий

```bash
# Используйте скрипт проверки
chmod +x scripts/check_ssl_prerequisites.sh
sudo ./scripts/check_ssl_prerequisites.sh sovgirenko.pro
```

### Шаг 2: Проверка Firewall

```bash
# Проверить статус firewall
sudo ufw status

# Открыть порт 80 (если не открыт)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Проверить снова
sudo ufw status
```

### Шаг 3: Проверка Nginx

```bash
# Проверить, что Nginx запущен
sudo systemctl status nginx

# Проверить конфигурацию
sudo nginx -t

# Проверить, что Nginx слушает порт 80
sudo netstat -tuln | grep :80
# или
sudo ss -tuln | grep :80
```

### Шаг 4: Проверка конфигурации Nginx для ACME challenge

Убедитесь, что в конфигурации Nginx есть:

```nginx
server {
    listen 80;
    server_name sovgirenko.pro;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        # остальная конфигурация
    }
}
```

Проверьте файл:
```bash
sudo cat /etc/nginx/sites-available/proxy
```

### Шаг 5: Проверка доступности домена

```bash
# Проверить доступность с сервера
curl -I http://sovgirenko.pro

# Проверить доступность извне (с другого компьютера)
# или используйте онлайн-сервис: https://www.yougetsignal.com/tools/open-ports/
```

### Шаг 6: Проверка DNS

```bash
# Проверить DNS записи
dig sovgirenko.pro +short
nslookup sovgirenko.pro

# Проверить, что DNS указывает на правильный IP
curl -s ifconfig.me  # IP вашего сервера
```

## Альтернативные методы получения сертификата

### Метод 1: Standalone режим (если webroot не работает)

Этот метод временно останавливает Nginx и использует встроенный веб-сервер Certbot:

```bash
# Остановить Nginx
sudo systemctl stop nginx

# Получить сертификат
sudo certbot certonly --standalone \
    -d sovgirenko.pro \
    --email your-email@example.com \
    --agree-tos \
    --no-eff-email

# Запустить Nginx
sudo systemctl start nginx
```

### Метод 2: DNS challenge (если порт 80 заблокирован)

Если порт 80 полностью заблокирован провайдером, используйте DNS challenge:

```bash
sudo certbot certonly --manual --preferred-challenges dns \
    -d sovgirenko.pro \
    --email your-email@example.com \
    --agree-tos \
    --no-eff-email
```

Certbot попросит добавить TXT запись в DNS. После добавления нажмите Enter.

### Метод 3: Проверка через другой порт (не рекомендуется)

Если у вас есть другой способ доступа к серверу, можно временно перенастроить.

## Проверка настроек провайдера/облака

### Для популярных платформ:

**DigitalOcean:**
- Проверьте Firewall в панели управления
- Убедитесь, что порты 80 и 443 открыты

**AWS:**
- Проверьте Security Groups
- Убедитесь, что правила для портов 80 и 443 настроены

**Google Cloud:**
- Проверьте Firewall rules
- Убедитесь, что правила для портов 80 и 443 настроены

**Azure:**
- Проверьте Network Security Groups
- Убедитесь, что порты 80 и 443 открыты

**Hetzner:**
- Проверьте Firewall в панели управления
- Убедитесь, что порты 80 и 443 открыты

## Быстрое решение

Если нужно быстро получить сертификат:

```bash
# 1. Остановить Nginx
sudo systemctl stop nginx

# 2. Получить сертификат в standalone режиме
sudo certbot certonly --standalone \
    -d sovgirenko.pro \
    --email your-email@example.com \
    --agree-tos \
    --no-eff-email

# 3. Запустить Nginx
sudo systemctl start nginx

# 4. Обновить конфигурацию Nginx для HTTPS
sudo /opt/proxy/scripts/setup_ssl.sh sovgirenko.pro
```

## Проверка после получения сертификата

```bash
# Проверить сертификат
sudo certbot certificates

# Проверить срок действия
sudo openssl x509 -in /etc/letsencrypt/live/sovgirenko.pro/cert.pem -noout -dates

# Тест обновления (dry-run)
sudo certbot renew --dry-run
```

## Обновление конфигурации Nginx после получения сертификата

После получения сертификата обновите конфигурацию Nginx:

```bash
sudo /opt/proxy/scripts/setup_ssl.sh sovgirenko.pro
```

Или вручную обновите `/etc/nginx/sites-available/proxy`:

```nginx
server {
    listen 443 ssl http2;
    server_name sovgirenko.pro;

    ssl_certificate /etc/letsencrypt/live/sovgirenko.pro/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/sovgirenko.pro/privkey.pem;
    
    # остальная конфигурация
}
```

## Автоматическое обновление сертификатов

После успешного получения сертификата настройте автоматическое обновление:

```bash
# Добавить в crontab
sudo crontab -e

# Добавить строку:
0 0 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'
```

## Дополнительная диагностика

### Проверка логов Certbot

```bash
sudo tail -f /var/log/letsencrypt/letsencrypt.log
```

### Проверка подключения к Let's Encrypt

```bash
# Проверить доступность Let's Encrypt
curl -I http://acme-v02.api.letsencrypt.org/directory
```

### Тест с подробным выводом

```bash
sudo certbot certonly --webroot \
    -w /var/www/certbot \
    -d sovgirenko.pro \
    --email your-email@example.com \
    --agree-tos \
    --no-eff-email \
    -v
```

## Частые проблемы

### Проблема: Провайдер блокирует порт 80

**Решение:** Используйте DNS challenge или standalone режим.

### Проблема: Nginx не может создать файлы в /var/www/certbot

**Решение:**
```bash
sudo mkdir -p /var/www/certbot
sudo chown -R www-data:www-data /var/www/certbot
sudo chmod -R 755 /var/www/certbot
```

### Проблема: Сертификат получен, но сайт не работает по HTTPS

**Решение:**
1. Проверьте конфигурацию Nginx
2. Убедитесь, что порт 443 открыт
3. Перезапустите Nginx: `sudo systemctl restart nginx`

## Полезные ссылки

- [Let's Encrypt Community](https://community.letsencrypt.org/)
- [Certbot Documentation](https://certbot.eff.org/docs/)
- [Troubleshooting Let's Encrypt](https://letsencrypt.org/docs/revoking/)
