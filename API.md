# API Документация

## Базовый URL

```
http://localhost:8080  # Локальная разработка
https://your-domain.com  # Продакшн
```

## Аутентификация

Большинство эндпоинтов требуют JWT токен в заголовке:

```
Authorization: Bearer <access_token>
```

## Эндпоинты

### Авторизация

#### POST /api/register
Регистрация нового пользователя.

**Request Body:**
```json
{
  "email": "user@example.com",
  "username": "testuser",
  "password": "Test1234"
}
```

**Response (201):**
```json
{
  "message": "Пользователь успешно зарегистрирован",
  "user_id": 1,
  "email": "user@example.com"
}
```

#### POST /api/login
Вход в систему.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "Test1234"
}
```

**Response (200):**
```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "token_type": "bearer",
  "expires_in": 1800
}
```

#### POST /api/refresh
Обновление access токена.

**Request Body:**
```json
{
  "refresh_token": "eyJ..."
}
```

**Response (200):**
```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "token_type": "bearer",
  "expires_in": 1800
}
```

#### GET /api/sessions
Получить список активных сессий пользователя.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200):**
```json
[
  {
    "id": 1,
    "session_id": "abc123...",
    "ip_address": "192.168.1.1",
    "user_agent": "Mozilla/5.0...",
    "created_at": "2026-01-28T10:00:00Z",
    "expires_at": "2026-02-27T10:00:00Z",
    "last_activity": "2026-01-28T10:00:00Z"
  }
]
```

#### DELETE /api/sessions/{session_id}
Завершить конкретную сессию.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (204):** No Content

### Профиль

#### GET /api/profile
Получить данные профиля текущего пользователя.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200):**
```json
{
  "id": 1,
  "email": "user@example.com",
  "username": "testuser",
  "is_active": true,
  "is_admin": false,
  "is_verified": false,
  "created_at": "2026-01-28T10:00:00Z",
  "updated_at": "2026-01-28T10:00:00Z",
  "last_login": "2026-01-28T10:00:00Z"
}
```

#### PUT /api/profile
Обновить профиль.

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "email": "newemail@example.com",  // опционально
  "username": "newusername"  // опционально
}
```

**Response (200):** Обновленный профиль

#### POST /api/change-password
Сменить пароль.

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "current_password": "OldPass1234",
  "new_password": "NewPass1234"
}
```

**Response (204):** No Content

### Прокси

#### GET/POST/PUT/DELETE /proxy/{path:path}
Проксировать HTTP запрос.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Параметры:**
- `url` (query parameter): Целевой URL для проксирования
- Или полный URL в path: `/proxy/https://example.com/path`

**Примеры:**
```
GET /proxy?url=https://httpbin.org/get
GET /proxy/https://example.com/api/data
POST /proxy?url=https://api.example.com/endpoint
```

**Response:** Ответ от целевого сервера

#### WebSocket /proxy/ws/{path:path}
Проксировать WebSocket соединение.

**Параметры:**
- `token` (query parameter): JWT access token
- `path`: Целевой WebSocket URL (ws:// или wss://)

**Пример:**
```
ws://server/proxy/ws/wss://target-server/path?token=JWT_TOKEN
```

### Статистика

#### GET /api/stats
Получить статистику текущего пользователя.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200):**
```json
{
  "bytes_sent": 1024000,
  "bytes_received": 2048000,
  "requests": 150,
  "total_bytes": 3072000
}
```

### Админ (требует прав администратора)

#### GET /api/admin/users
Получить список всех пользователей.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Query Parameters:**
- `skip` (int, default: 0): Количество пропущенных записей
- `limit` (int, default: 100): Максимальное количество записей

**Response (200):**
```json
[
  {
    "id": 1,
    "email": "user@example.com",
    "username": "testuser",
    ...
  }
]
```

#### GET /api/admin/users/{user_id}
Получить данные пользователя по ID.

#### PUT /api/admin/users/{user_id}
Обновить данные пользователя.

**Request Body:**
```json
{
  "email": "newemail@example.com",
  "username": "newusername"
}
```

#### DELETE /api/admin/users/{user_id}
Удалить пользователя.

#### GET /api/admin/stats
Получить статистику всех пользователей.

**Response (200):**
```json
{
  "users": {
    "1": {
      "user_id": 1,
      "email": "user@example.com",
      "username": "testuser",
      "bytes_sent": 1024000,
      "bytes_received": 2048000,
      "requests": 150
    }
  },
  "total_users": 10
}
```

### Мониторинг

#### GET /health
Проверка здоровья сервиса.

**Response (200):**
```json
{
  "status": "healthy",
  "database": "connected",
  "redis": "connected"
}
```

#### GET /metrics
Prometheus метрики.

**Response (200):** Prometheus формата метрики

## Коды ошибок

- `400 Bad Request` - Некорректный запрос
- `401 Unauthorized` - Не авторизован или неверный токен
- `403 Forbidden` - Недостаточно прав доступа
- `404 Not Found` - Ресурс не найден
- `413 Request Entity Too Large` - Превышен размер запроса
- `500 Internal Server Error` - Внутренняя ошибка сервера
- `502 Bad Gateway` - Ошибка подключения к целевому серверу
- `504 Gateway Timeout` - Таймаут запроса

## Примеры использования

### cURL

```bash
# Регистрация
curl -X POST http://localhost:8080/api/register \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","username":"testuser","password":"Test1234"}'

# Вход
curl -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"Test1234"}'

# Прокси запрос
curl -X GET "http://localhost:8080/proxy?url=https://httpbin.org/get" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Python

```python
import requests

# Вход
response = requests.post(
    "http://localhost:8080/api/login",
    json={"email": "user@example.com", "password": "Test1234"}
)
token = response.json()["access_token"]

# Прокси запрос
response = requests.get(
    "http://localhost:8080/proxy",
    params={"url": "https://httpbin.org/get"},
    headers={"Authorization": f"Bearer {token}"}
)
print(response.json())
```

### iOS (Swift)

```swift
// Вход
let loginData = ["email": "user@example.com", "password": "Test1234"]
var request = URLRequest(url: URL(string: "https://your-domain.com/api/login")!)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = try? JSONSerialization.data(withJSONObject: loginData)

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    if let data = data {
        let json = try? JSONSerialization.jsonObject(with: data)
        // Сохранить access_token
    }
}
task.resume()

// Прокси запрос
var proxyRequest = URLRequest(url: URL(string: "https://your-domain.com/proxy?url=https://example.com")!)
proxyRequest.setValue("Bearer YOUR_ACCESS_TOKEN", forHTTPHeaderField: "Authorization")
let proxyTask = URLSession.shared.dataTask(with: proxyRequest)
proxyTask.resume()
```
