# Быстрый старт

## Локальная разработка

### 1. Клонирование и настройка

```bash
cd /path/to/proxy
cp .env.example .env
```

Отредактируйте `.env` и установите необходимые значения.

### 2. Запуск через Docker Compose

```bash
docker-compose up -d
```

Это запустит:
- PostgreSQL на порту 5432
- Redis на порту 6379
- Приложение на порту 8080

### 3. Инициализация базы данных

```bash
docker-compose exec app python init_db.py
```

Это создаст таблицы и администратора по умолчанию:
- Email: `admin@example.com`
- Password: `admin123`

⚠️ **ВАЖНО**: Смените пароль администратора сразу после первого входа!

### 4. Проверка работы

Откройте в браузере:
- API документация: http://localhost:8080/docs
- Health check: http://localhost:8080/health

## Тестирование API

### Регистрация пользователя

```bash
curl -X POST http://localhost:8080/api/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "username": "testuser",
    "password": "Test1234"
  }'
```

### Вход

```bash
curl -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "Test1234"
  }'
```

Сохраните `access_token` из ответа.

### Прокси запрос

```bash
curl -X GET "http://localhost:8080/proxy?url=https://httpbin.org/get" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

## Использование Postman

1. Импортируйте `postman_collection.json` в Postman
2. Установите переменную `base_url` на `http://localhost:8080`
3. Выполните запрос "Login" - токены сохранятся автоматически
4. Теперь можно использовать другие запросы

## Остановка

```bash
docker-compose down
```

Для удаления данных:
```bash
docker-compose down -v
```

## Логи

```bash
# Все логи
docker-compose logs -f

# Только приложение
docker-compose logs -f app

# Только база данных
docker-compose logs -f db
```

## Миграции базы данных

```bash
# Применить миграции
docker-compose exec app alembic upgrade head

# Создать новую миграцию
docker-compose exec app alembic revision --autogenerate -m "description"

# Откатить миграцию
docker-compose exec app alembic downgrade -1
```

## Разработка без Docker

### Установка зависимостей

```bash
python3 -m venv venv
source venv/bin/activate  # Linux/Mac
# или
venv\Scripts\activate  # Windows

pip install -r requirements.txt
```

### Настройка базы данных

Убедитесь, что PostgreSQL и Redis запущены локально, или используйте Docker только для них:

```bash
docker-compose up -d db redis
```

### Запуск приложения

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8080
```

## Структура проекта

```
proxy/
├── app/                    # Код приложения
│   ├── main.py             # Точка входа
│   ├── config.py           # Конфигурация
│   ├── database.py         # БД подключение
│   ├── models/             # SQLAlchemy модели
│   ├── schemas/            # Pydantic схемы
│   ├── routers/            # API роутеры
│   ├── services/           # Бизнес-логика
│   └── middleware/        # Middleware
├── alembic/                # Миграции БД
├── scripts/                # Скрипты деплоя
├── nginx/                  # Nginx конфигурация
├── docker-compose.yml      # Docker Compose
├── Dockerfile              # Docker образ
└── requirements.txt        # Python зависимости
```

## Следующие шаги

1. Прочитайте [API.md](API.md) для полной документации API
2. Прочитайте [DEPLOY.md](DEPLOY.md) для развертывания на продакшн сервере
3. Настройте SSL сертификаты для продакшна
4. Настройте мониторинг и алерты
