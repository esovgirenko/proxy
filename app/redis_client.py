"""
Redis клиент для кэширования и хранения сессий
"""
import redis
from typing import Optional
from app.config import settings
import json
from datetime import timedelta

# Создаем Redis клиент
redis_client: Optional[redis.Redis] = None


def get_redis() -> redis.Redis:
    """Получить Redis клиент"""
    global redis_client
    if redis_client is None:
        redis_client = redis.from_url(
            settings.redis_url,
            decode_responses=settings.redis_decode_responses,
            socket_connect_timeout=5,
            socket_timeout=5,
            retry_on_timeout=True
        )
    return redis_client


def cache_token(token: str, user_id: int, expire_minutes: int = 30):
    """Кэшировать токен"""
    r = get_redis()
    key = f"token:{token}"
    r.setex(key, expire_minutes * 60, user_id)


def get_user_from_token(token: str) -> Optional[int]:
    """Получить user_id из токена"""
    r = get_redis()
    key = f"token:{token}"
    user_id = r.get(key)
    return int(user_id) if user_id else None


def invalidate_token(token: str):
    """Удалить токен из кэша"""
    r = get_redis()
    key = f"token:{token}"
    r.delete(key)


def cache_session(session_id: str, user_id: int, data: dict, expire_days: int = 30):
    """Кэшировать сессию"""
    r = get_redis()
    key = f"session:{session_id}"
    r.setex(key, expire_days * 24 * 60 * 60, json.dumps(data))
    # Также добавляем в список сессий пользователя
    user_sessions_key = f"user_sessions:{user_id}"
    r.sadd(user_sessions_key, session_id)
    r.expire(user_sessions_key, expire_days * 24 * 60 * 60)


def get_session(session_id: str) -> Optional[dict]:
    """Получить сессию"""
    r = get_redis()
    key = f"session:{session_id}"
    data = r.get(key)
    return json.loads(data) if data else None


def delete_session(session_id: str, user_id: int):
    """Удалить сессию"""
    r = get_redis()
    key = f"session:{session_id}"
    r.delete(key)
    user_sessions_key = f"user_sessions:{user_id}"
    r.srem(user_sessions_key, session_id)


def get_user_sessions(user_id: int) -> list:
    """Получить все сессии пользователя"""
    r = get_redis()
    user_sessions_key = f"user_sessions:{user_id}"
    return list(r.smembers(user_sessions_key))


def increment_user_stats(user_id: int, bytes_sent: int, bytes_received: int):
    """Увеличить статистику пользователя"""
    r = get_redis()
    stats_key = f"stats:{user_id}"
    r.hincrby(stats_key, "bytes_sent", bytes_sent)
    r.hincrby(stats_key, "bytes_received", bytes_received)
    r.hincrby(stats_key, "requests", 1)
    r.expire(stats_key, 86400 * 7)  # Храним 7 дней


def get_user_stats(user_id: int) -> dict:
    """Получить статистику пользователя"""
    r = get_redis()
    stats_key = f"stats:{user_id}"
    stats = r.hgetall(stats_key)
    return {
        "bytes_sent": int(stats.get("bytes_sent", 0)),
        "bytes_received": int(stats.get("bytes_received", 0)),
        "requests": int(stats.get("requests", 0))
    }
