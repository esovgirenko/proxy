"""
Главный файл FastAPI приложения
"""
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
import logging
import sys
from contextlib import asynccontextmanager

from app.config import settings
from app.database import engine, Base
from app.routers import auth, profile, admin, proxy, stats, health
from app.utils.rate_limit import limiter

# Настройка логирования
logging.basicConfig(
    level=getattr(logging, settings.log_level.upper()),
    format='{"time": "%(asctime)s", "level": "%(levelname)s", "message": "%(message)s", "module": "%(name)s"}',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Управление жизненным циклом приложения"""
    # Startup
    logger.info("Starting up proxy server...")
    logger.info(f"Server will run on {settings.server_host}:{settings.server_port}")
    
    # Создаем таблицы (в продакшене лучше использовать миграции)
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables created/verified")
    except Exception as e:
        logger.error(f"Error creating database tables: {e}")
    
    yield
    
    # Shutdown
    logger.info("Shutting down proxy server...")


# Создаем FastAPI приложение
app = FastAPI(
    title="Proxy Server with Authentication",
    description="Прокси-сервер с системой авторизации для iOS-клиентов",
    version="1.0.0",
    lifespan=lifespan
)

# Настраиваем rate limiting
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Настраиваем CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_allow_origins,
    allow_credentials=settings.cors_allow_credentials,
    allow_methods=settings.cors_allow_methods,
    allow_headers=settings.cors_allow_headers,
)


# Обработчик ошибок
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Глобальный обработчик исключений"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Внутренняя ошибка сервера"}
    )


# Подключаем роутеры
app.include_router(auth.router)
app.include_router(profile.router)
app.include_router(admin.router)
app.include_router(proxy.router)
app.include_router(stats.router)
app.include_router(health.router)


@app.get("/")
async def root():
    """Корневой эндпоинт"""
    return {
        "message": "Proxy Server with Authentication",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.server_host,
        port=settings.server_port,
        reload=True,
        log_level=settings.log_level
    )
