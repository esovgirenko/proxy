# Устранение неполадок

## Проблемы с Docker Compose

### Ошибка: ModuleNotFoundError: No module named 'distutils'

**Причина:** Старая версия `docker-compose` (v1) несовместима с Python 3.12+.

**Решение 1: Использовать Docker Compose v2 (рекомендуется)**

Docker Compose v2 входит в состав Docker и не требует Python:

```bash
# Проверка версии
docker compose version

# Использование (обратите внимание на пробел, не дефис)
docker compose up -d
docker compose ps
docker compose logs
```

**Решение 2: Установить Docker Compose plugin**

```bash
# Удалить старую версию
apt-get remove -y docker-compose

# Установить Docker Compose plugin
apt-get install -y docker-compose-plugin

# Проверить
docker compose version
```

**Решение 3: Установить python3-distutils (временное решение)**

```bash
apt-get install -y python3-distutils
```

Но лучше использовать Docker Compose v2.

### Обновление скриптов для использования Docker Compose v2

Все скрипты обновлены для автоматического определения версии:

- Если доступен `docker compose` (v2) - используется он
- Если нет - используется `docker-compose` (v1)

## Проблемы с установкой Docker

### Ошибка при установке Docker

**Решение:**

```bash
# Удалить старые версии
apt-get remove -y docker docker-engine docker.io containerd runc

# Установить зависимости
apt-get install -y ca-certificates curl gnupg lsb-release

# Добавить официальный репозиторий Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

## Проблемы с базой данных

### База данных не запускается

**Проверка:**

```bash
cd /opt/proxy
docker compose ps
docker compose logs db
```

**Решение:**

```bash
# Остановить и удалить контейнеры
docker compose down

# Удалить volumes (ОСТОРОЖНО: удалит данные!)
docker compose down -v

# Запустить заново
docker compose up -d db redis

# Проверить логи
docker compose logs -f db
```

### Ошибка подключения к базе данных

**Проверка:**

```bash
# Проверить переменные окружения
cat /opt/proxy/.env | grep DATABASE_URL

# Проверить подключение
docker compose exec db psql -U proxy_user -d proxy_db
```

**Решение:**

Убедитесь, что пароли в `.env` и `docker-compose.yml` совпадают.

## Проблемы с Redis

### Redis не запускается

**Проверка:**

```bash
docker compose logs redis
docker compose exec redis redis-cli ping
```

**Решение:**

```bash
# Перезапуск Redis
docker compose restart redis

# Или пересоздание
docker compose up -d --force-recreate redis
```

## Проблемы с приложением

### Приложение не запускается

**Проверка:**

```bash
docker compose logs app
docker compose ps
```

**Решение:**

```bash
# Перезапуск приложения
docker compose restart app

# Пересборка и запуск
docker compose build app
docker compose up -d app
```

### Ошибки в логах приложения

**Просмотр логов:**

```bash
# Все логи
docker compose logs -f app

# Последние 100 строк
docker compose logs --tail=100 app

# Логи с временными метками
docker compose logs -f --timestamps app
```

## Проблемы с Nginx

### Nginx не запускается

**Проверка:**

```bash
nginx -t
systemctl status nginx
tail -f /var/log/nginx/error.log
```

**Решение:**

```bash
# Проверка конфигурации
nginx -t

# Перезапуск
systemctl restart nginx

# Если ошибка - проверьте конфигурацию
nano /etc/nginx/sites-available/proxy
```

### 502 Bad Gateway

**Причина:** Nginx не может подключиться к приложению.

**Решение:**

```bash
# Проверить, запущено ли приложение
docker compose ps

# Проверить порт
netstat -tulpn | grep 8080

# Перезапустить приложение
docker compose restart app
```

## Проблемы с портами

### Порт уже занят

**Проверка:**

```bash
netstat -tulpn | grep 8080
ss -tulpn | grep 8080
lsof -i :8080
```

**Решение:**

1. Изменить порт в `.env`:
```bash
nano /opt/proxy/.env
# SERVER_PORT=8081
```

2. Обновить `docker-compose.yml`:
```bash
nano /opt/proxy/docker-compose.yml
# Изменить порт в секции ports
```

3. Перезапустить:
```bash
docker compose down
docker compose up -d
```

## Проблемы с SSL

### Не получается сертификат

**Проверка:**

```bash
# Проверка DNS
nslookup your-domain.com

# Проверка доступности
curl -I http://your-domain.com

# Проверка портов
ufw status | grep 80
```

**Решение:**

1. Убедитесь, что DNS настроен правильно
2. Убедитесь, что порт 80 открыт
3. Проверьте, что Nginx доступен извне

```bash
# Ручное получение сертификата
certbot certonly --standalone -d your-domain.com
```

## Проблемы с правами доступа

### Permission denied

**Решение:**

```bash
# Проверить права на файлы
ls -la /opt/proxy

# Установить правильные права
chown -R root:root /opt/proxy
chmod +x /opt/proxy/scripts/*.sh
```

## Проблемы с systemd

### Сервис не запускается

**Проверка:**

```bash
systemctl status proxy
journalctl -u proxy -f
```

**Решение:**

```bash
# Перезагрузить конфигурацию
systemctl daemon-reload

# Перезапустить сервис
systemctl restart proxy

# Проверить логи
journalctl -u proxy -n 50
```

## Общие команды для диагностики

### Проверка статуса всех компонентов

```bash
# Docker
docker ps
docker compose ps

# Systemd сервисы
systemctl status proxy
systemctl status docker
systemctl status nginx

# Порты
ss -tulpn | grep -E "8080|5432|6379"

# Логи
docker compose logs --tail=50
tail -50 /var/log/nginx/error.log
```

### Очистка и переустановка

```bash
# Остановить все
cd /opt/proxy
docker compose down

# Удалить volumes (ОСТОРОЖНО!)
docker compose down -v

# Очистить неиспользуемые образы
docker system prune -a

# Перезапустить
docker compose up -d
```

## Получение помощи

Если проблема не решена:

1. Соберите информацию:
```bash
# Версии
docker --version
docker compose version
nginx -v
uname -a

# Логи
docker compose logs > docker_logs.txt
journalctl -u proxy > systemd_logs.txt
```

2. Проверьте документацию:
   - [INSTALL.md](INSTALL.md)
   - [SECURITY.md](SECURITY.md)
   - [API.md](API.md)

3. Проверьте логи установки:
```bash
cat /var/log/proxy_install.log
```
