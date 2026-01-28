# Proxy Server with Authentication

Прокси-сервер с системой авторизации для iOS-клиентов версии 26.1.

## Технологии

- **Backend**: Python 3.9+ с FastAPI
- **База данных**: PostgreSQL 14+
- **Кэширование**: Redis
- **Контейнеризация**: Docker & Docker Compose

## Быстрый старт

### Локальная разработка

1. Клонируйте репозиторий
2. Скопируйте `.env.example` в `.env` и настройте переменные окружения
3. Запустите через Docker Compose:

```bash
docker-compose up -d
```

4. Инициализируйте базу данных:

```bash
docker-compose exec app python init_db.py
```

5. Сервер будет доступен на `http://localhost:8080`

### API Документация

После запуска сервера:
- Swagger UI: `http://localhost:8080/docs`
- ReDoc: `http://localhost:8080/redoc`

## Установка

### 🚀 Установка с GitHub (самый простой способ)

```bash
# Вариант 1: Интерактивный режим (скрипт спросит данные)
curl -fsSL https://raw.githubusercontent.com/USERNAME/REPO/main/scripts/install_from_github.sh | sudo bash

# Вариант 2: С параметрами
curl -fsSL https://raw.githubusercontent.com/USERNAME/REPO/main/scripts/install_from_github.sh | \
  sudo bash -s -- USERNAME REPO_NAME [BRANCH]
```

**Пример:**
```bash
# Интерактивный режим
curl -fsSL https://raw.githubusercontent.com/esovgirenko/proxy/main/scripts/install_from_github.sh | sudo bash

# С параметрами
curl -fsSL https://raw.githubusercontent.com/esovgirenko/proxy/main/scripts/install_from_github.sh | \
  sudo bash -s -- esovgirenko proxy
```

**Или загрузите скрипт и запустите:**
```bash
wget https://raw.githubusercontent.com/esovgirenko/proxy/main/scripts/install_from_github.sh
chmod +x install_from_github.sh
sudo ./install_from_github.sh esovgirenko proxy
```

Скрипт автоматически:
1. Загрузит проект с GitHub
2. Установит все зависимости
3. Настроит и запустит сервер

**Подробная инструкция**: [INSTALL_FROM_GITHUB.md](INSTALL_FROM_GITHUB.md)

### 📦 Локальная установка

```bash
# 1. Скачайте проект на сервер
git clone <repository-url> proxy && cd proxy

# 2. Запустите скрипт установки
chmod +x scripts/install.sh && sudo ./scripts/install.sh

# 3. Настройте SSL
sudo /opt/proxy/scripts/setup_ssl.sh your-domain.com your-email@example.com
```

**Краткая инструкция**: [INSTALL_QUICK.md](INSTALL_QUICK.md)  
**Подробная инструкция**: [INSTALL.md](INSTALL.md)

## Развертывание на продакшн сервере

См. [DEPLOY.md](DEPLOY.md) для подробных инструкций по развертыванию.

## Структура проекта

```
proxy/
├── app/
│   ├── __init__.py
│   ├── main.py              # Точка входа FastAPI
│   ├── config.py            # Конфигурация
│   ├── database.py          # Подключение к БД
│   ├── redis_client.py      # Redis клиент
│   ├── models/              # SQLAlchemy модели
│   ├── schemas/             # Pydantic схемы
│   ├── routers/             # API роутеры
│   ├── services/            # Бизнес-логика
│   ├── middleware/          # Middleware
│   └── utils/               # Утилиты
├── alembic/                 # Миграции БД
├── scripts/                 # Скрипты деплоя
├── nginx/                   # Nginx конфигурация
├── docker-compose.yml
├── Dockerfile
└── requirements.txt
```

## Основные эндпоинты

### Авторизация
- `POST /api/register` - Регистрация
- `POST /api/login` - Вход
- `POST /api/refresh` - Обновление токена
- `GET /api/sessions` - Список сессий
- `DELETE /api/sessions/{id}` - Завершение сессии

### Прокси
- `/{path:path}` - Прокси-эндпоинт (требует авторизации)

### Профиль
- `GET /api/profile` - Профиль пользователя
- `PUT /api/profile` - Обновление профиля
- `POST /api/change-password` - Смена пароля

### Админ
- `GET /api/admin/users` - Список пользователей
- `PUT /api/admin/users/{id}` - Изменение пользователя
- `DELETE /api/admin/users/{id}` - Удаление пользователя
- `GET /api/admin/stats` - Статистика

### Мониторинг
- `GET /health` - Health check
- `GET /metrics` - Prometheus метрики

## Документация

### Установка
- [INSTALL_QUICK.md](INSTALL_QUICK.md) - 🚀 Быстрая установка (3 шага)
- [INSTALL.md](INSTALL.md) - 📖 Подробная инструкция по установке
- [SECURITY.md](SECURITY.md) - 🔒 Настройка безопасности Ubuntu
- [scripts/README.md](scripts/README.md) - Описание скриптов установки

### Разработка и использование
- [QUICKSTART.md](QUICKSTART.md) - Быстрый старт для локальной разработки
- [API.md](API.md) - Полная документация API
- [DEPLOY.md](DEPLOY.md) - Инструкция по развертыванию на продакшн сервере

## Основные файлы

- `docker-compose.yml` - Конфигурация Docker Compose
- `Dockerfile` - Docker образ приложения
- `config.yaml` - Конфигурация приложения
- `.env.example` - Пример переменных окружения
- `postman_collection.json` - Postman коллекция для тестирования API

## Скрипты

- `scripts/install.sh` - **Автоматическая установка** (рекомендуется для новой установки)
- `scripts/security.sh` - **Настройка безопасности Ubuntu** (firewall, fail2ban, SSH и др.)
- `scripts/deploy.sh` - Автоматическое развертывание (если файлы уже на сервере)
- `scripts/backup.sh` - Резервное копирование базы данных
- `scripts/setup_ssl.sh` - Настройка SSL сертификатов

## Лицензия

MIT
