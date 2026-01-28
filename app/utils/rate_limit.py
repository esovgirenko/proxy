"""
Rate limiting утилиты
"""
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from fastapi import Request
from app.config import settings

# Создаем лимитер
limiter = Limiter(key_func=get_remote_address)


def get_user_id_from_request(request: Request) -> str:
    """Получить user_id из запроса для rate limiting по пользователю"""
    # Если есть текущий пользователь в request.state, используем его
    if hasattr(request.state, "user_id"):
        return str(request.state.user_id)
    # Иначе используем IP адрес
    return get_remote_address(request)
