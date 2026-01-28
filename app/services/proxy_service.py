"""
Сервис проксирования запросов
"""
import httpx
from typing import Optional
from fastapi import Request, Response
from fastapi.responses import StreamingResponse
from app.config import settings
from app.redis_client import increment_user_stats
import asyncio


class ProxyService:
    """Сервис для проксирования HTTP/HTTPS запросов"""
    
    @staticmethod
    async def proxy_request(
        request: Request,
        target_url: str,
        user_id: int
    ) -> Response:
        """Проксировать HTTP запрос"""
        # Получаем заголовки от клиента
        headers = dict(request.headers)
        
        # Удаляем заголовки, которые не должны передаваться
        headers.pop("host", None)
        headers.pop("content-length", None)
        headers.pop("connection", None)
        headers.pop("transfer-encoding", None)
        
        # Устанавливаем User-Agent для iOS
        headers["User-Agent"] = settings.ios_user_agent
        
        # Получаем тело запроса
        body = await request.body()
        
        # Создаем клиент для проксирования
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(
                connect=settings.proxy_connect_timeout,
                read=settings.proxy_read_timeout
            ),
            follow_redirects=True,
            verify=False  # Для HTTPS проксирования
        ) as client:
            try:
                # Выполняем запрос
                response = await client.request(
                    method=request.method,
                    url=target_url,
                    headers=headers,
                    content=body if body else None,
                    params=dict(request.query_params)
                )
                
                # Собираем статистику
                bytes_sent = len(body) if body else 0
                bytes_received = len(response.content) if response.content else 0
                increment_user_stats(user_id, bytes_sent, bytes_received)
                
                # Формируем ответ
                response_headers = dict(response.headers)
                # Удаляем заголовки, которые не должны передаваться клиенту
                response_headers.pop("content-encoding", None)
                response_headers.pop("transfer-encoding", None)
                response_headers.pop("connection", None)
                response_headers.pop("keep-alive", None)
                
                return Response(
                    content=response.content,
                    status_code=response.status_code,
                    headers=response_headers,
                    media_type=response.headers.get("content-type")
                )
                
            except httpx.TimeoutException:
                return Response(
                    content="Request timeout",
                    status_code=504,
                    media_type="text/plain"
                )
            except httpx.ConnectError:
                return Response(
                    content="Connection error",
                    status_code=502,
                    media_type="text/plain"
                )
            except Exception as e:
                return Response(
                    content=f"Proxy error: {str(e)}",
                    status_code=500,
                    media_type="text/plain"
                )
    
    @staticmethod
    async def proxy_streaming(
        request: Request,
        target_url: str,
        user_id: int
    ) -> StreamingResponse:
        """Проксировать запрос с потоковой передачей (для больших файлов)"""
        headers = dict(request.headers)
        headers.pop("host", None)
        headers.pop("content-length", None)
        headers.pop("connection", None)
        headers["User-Agent"] = settings.ios_user_agent
        
        async def generate():
            bytes_sent = 0
            bytes_received = 0
            
            async with httpx.AsyncClient(
                timeout=httpx.Timeout(
                    connect=settings.proxy_connect_timeout,
                    read=settings.proxy_read_timeout
                ),
                follow_redirects=True,
                verify=False
            ) as client:
                # Получаем тело запроса
                body = await request.body() if request.method in ["POST", "PUT", "PATCH"] else None
                bytes_sent = len(body) if body else 0
                
                async with client.stream(
                    method=request.method,
                    url=target_url,
                    headers=headers,
                    content=body,
                    params=dict(request.query_params)
                ) as response:
                    async for chunk in response.aiter_bytes():
                        bytes_received += len(chunk)
                        yield chunk
                
                # Обновляем статистику
                increment_user_stats(user_id, bytes_sent, bytes_received)
        
        return StreamingResponse(
            generate(),
            status_code=200,
            headers={"Content-Type": "application/octet-stream"}
        )
    
    @staticmethod
    async def proxy_websocket(
        websocket,
        target_url: str,
        user_id: int
    ):
        """Проксировать WebSocket соединение"""
        # WebSocket проксирование требует специальной обработки
        # Для полной поддержки нужна библиотека websockets
        try:
            import websockets
            
            # Подключаемся к целевому WebSocket серверу
            async with websockets.connect(target_url) as target_ws:
                # Создаем задачи для двунаправленной передачи
                async def forward_to_target():
                    bytes_sent = 0
                    try:
                        while True:
                            data = await websocket.receive_bytes()
                            bytes_sent += len(data)
                            await target_ws.send(data)
                    except Exception:
                        pass
                    finally:
                        increment_user_stats(user_id, bytes_sent, 0)
                
                async def forward_to_client():
                    bytes_received = 0
                    try:
                        while True:
                            data = await target_ws.recv()
                            bytes_received += len(data)
                            await websocket.send_bytes(data)
                    except Exception:
                        pass
                    finally:
                        increment_user_stats(user_id, 0, bytes_received)
                
                # Запускаем обе задачи параллельно
                await asyncio.gather(
                    forward_to_target(),
                    forward_to_client()
                )
        except ImportError:
            # Если websockets не установлен, закрываем соединение
            await websocket.close(code=1011, reason="WebSocket proxy not available")
        except Exception as e:
            await websocket.close(code=1011, reason=f"Proxy error: {str(e)}")
