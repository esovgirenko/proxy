"""
Роутер для статистики
"""
from fastapi import APIRouter, Depends
from app.middleware.auth_middleware import get_current_user
from app.models.user import User
from app.redis_client import get_user_stats
from app.schemas.stats import StatsResponse

router = APIRouter(prefix="/api", tags=["stats"])


@router.get("/stats", response_model=StatsResponse)
async def get_stats(
    current_user: User = Depends(get_current_user)
):
    """Получить статистику текущего пользователя"""
    stats = get_user_stats(current_user.id)
    return StatsResponse.from_dict(stats)
