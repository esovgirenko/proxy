"""
Роутер для прокси-запросов
"""
from fastapi import APIRouter, Request, Depends, HTTPException, status, WebSocket, WebSocketDisconnect
from fastapi.responses import Response
from app.middleware.auth_middleware import get_current_user
from app.models.user import User
from app.services.proxy_service import ProxyService
from urllib.parse import urlparse
import re

router = APIRouter(tags=["proxy"])


def validate_url(url: str) -> bool:
    """Валидация URL"""
    try:
        result = urlparse(url)
        # Разрешаем только HTTP и HTTPS
        return result.scheme in ["http", "https"] and result.netloc
    except:
        return False


@router.api_route("/proxy/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"])
async def proxy_request(
    path: str,
    request: Request,
    current_user: User = Depends(get_current_user)
):
    """
    Прокси-эндпоинт для всех HTTP методов
    
    Использование: 
    - /proxy?url=https://example.com/path (рекомендуется)
    - /proxy/https://example.com/path
    """
    from app.config import settings
    
    # Получаем полный URL из query параметра или path
    target_url = request.query_params.get("url")
    
    if not target_url:
        # Если URL не в query, пытаемся восстановить из path
        if path.startswith("http://") or path.startswith("https://"):
            target_url = path
        else:
            # Пытаемся добавить https:// если протокол не указан
            if "://" not in path:
                target_url = f"https://{path}"
            else:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Не указан URL для проксирования. Используйте параметр ?url= или полный URL в path"
                )
    
    # Валидация URL
    if not validate_url(target_url):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Некорректный URL. Разрешены только HTTP и HTTPS протоколы"
        )
    
    # Проверка размера запроса
    content_length = request.headers.get("content-length")
    if content_length:
        try:
            size_mb = int(content_length) / (1024 * 1024)
            if size_mb > settings.max_request_size_mb:
                raise HTTPException(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    detail=f"Размер запроса превышает {settings.max_request_size_mb}MB"
                )
        except ValueError:
            pass  # Игнорируем некорректный content-length
    
    # Проксируем запрос
    response = await ProxyService.proxy_request(request, target_url, current_user.id)
    return response


@router.websocket("/proxy/ws/{path:path}")
async def proxy_websocket(
    websocket: WebSocket,
    path: str
):
    """
    Прокси для WebSocket соединений
    
    Использование: ws://server/proxy/ws/wss://target-server/path?token=JWT_TOKEN
    """
    await websocket.accept()
    
    # Получаем токен из query параметров
    token = websocket.query_params.get("token")
    
    # Проверяем токен
    if not token:
        await websocket.close(code=1008, reason="Token required")
        return
    
    # Декодируем токен и получаем пользователя
    from app.utils.security import decode_token
    from app.database import SessionLocal
    from app.services.auth_service import AuthService
    
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        await websocket.close(code=1008, reason="Invalid token")
        return
    
    user_id = int(payload.get("sub"))
    db = SessionLocal()
    try:
        user = AuthService.get_user_by_id(db, user_id)
        if not user or not user.is_active:
            await websocket.close(code=1008, reason="User not found or inactive")
            return
    finally:
        db.close()
    
    # Формируем целевой URL
    if path.startswith("ws://") or path.startswith("wss://"):
        target_url = path
    else:
        target_url = f"wss://{path}"
    
    # Проксируем WebSocket
    try:
        await ProxyService.proxy_websocket(websocket, target_url, user_id)
    except WebSocketDisconnect:
        pass
    except Exception as e:
        await websocket.close(code=1011, reason=f"Proxy error: {str(e)}")
