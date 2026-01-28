"""
Роутер для мониторинга здоровья сервиса
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.database import get_db, engine
from app.redis_client import get_redis
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response

router = APIRouter(tags=["monitoring"])


@router.get("/health")
async def health_check(db: Session = Depends(get_db)):
    """Проверка здоровья сервиса"""
    status = {
        "status": "healthy",
        "database": "unknown",
        "redis": "unknown"
    }
    
    # Проверка базы данных
    try:
        db.execute(text("SELECT 1"))
        status["database"] = "connected"
    except Exception as e:
        status["database"] = f"error: {str(e)}"
        status["status"] = "unhealthy"
    
    # Проверка Redis
    try:
        redis = get_redis()
        redis.ping()
        status["redis"] = "connected"
    except Exception as e:
        status["redis"] = f"error: {str(e)}"
        status["status"] = "unhealthy"
    
    return status


@router.get("/metrics")
async def metrics():
    """Prometheus метрики"""
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )
