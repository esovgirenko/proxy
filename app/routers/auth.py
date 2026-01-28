"""
Роутер для авторизации
"""
from fastapi import APIRouter, Depends, HTTPException, status, Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.user import UserCreate, UserLogin
from app.schemas.auth import Token, TokenRefresh, SessionResponse
from app.services.auth_service import AuthService
from app.middleware.auth_middleware import get_current_user
from app.utils.rate_limit import limiter
from app.config import settings

router = APIRouter(prefix="/api", tags=["auth"])


@router.post("/register", response_model=dict, status_code=status.HTTP_201_CREATED)
@limiter.limit(f"{settings.rate_limit_per_minute}/minute")
async def register(
    request: Request,
    user_data: UserCreate,
    db: Session = Depends(get_db)
):
    """Регистрация нового пользователя"""
    user = AuthService.register_user(db, user_data)
    return {
        "message": "Пользователь успешно зарегистрирован",
        "user_id": user.id,
        "email": user.email
    }


@router.post("/login", response_model=Token)
@limiter.limit(f"{settings.rate_limit_per_minute}/minute")
async def login(
    request: Request,
    user_data: UserLogin,
    db: Session = Depends(get_db)
):
    """Вход в систему"""
    ip_address = get_remote_address(request)
    user_agent = request.headers.get("user-agent")
    
    user, access_token, refresh_token = AuthService.authenticate_user(
        db, user_data, ip_address, user_agent
    )
    
    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=settings.access_token_expire_minutes * 60
    )


@router.post("/refresh", response_model=Token)
async def refresh_token(
    token_data: TokenRefresh,
    db: Session = Depends(get_db)
):
    """Обновление access токена"""
    new_access_token, refresh_token = AuthService.refresh_access_token(
        db, token_data.refresh_token
    )
    
    return Token(
        access_token=new_access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=settings.access_token_expire_minutes * 60
    )


@router.get("/sessions", response_model=list[SessionResponse])
async def get_sessions(
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Получить список активных сессий пользователя"""
    sessions = AuthService.get_user_sessions(db, current_user.id)
    return sessions


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_session(
    session_id: str,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Завершить конкретную сессию"""
    success = AuthService.delete_session(db, session_id, current_user.id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Сессия не найдена"
        )
