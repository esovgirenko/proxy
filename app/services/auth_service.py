"""
Сервис авторизации
"""
from datetime import datetime, timedelta
from typing import Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.user import User
from app.models.session import Session as SessionModel
from app.schemas.user import UserCreate, UserLogin
from app.utils.security import (
    verify_password, get_password_hash, create_access_token,
    create_refresh_token, decode_token, generate_session_id
)
from app.redis_client import cache_token, cache_session, get_user_sessions
from app.config import settings


class AuthService:
    """Сервис для работы с авторизацией"""
    
    @staticmethod
    def register_user(db: Session, user_data: UserCreate) -> User:
        """Регистрация нового пользователя"""
        # Проверяем, существует ли пользователь с таким email
        existing_user = db.query(User).filter(User.email == user_data.email).first()
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Пользователь с таким email уже существует"
            )
        
        # Проверяем, существует ли пользователь с таким username
        existing_username = db.query(User).filter(User.username == user_data.username).first()
        if existing_username:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Пользователь с таким username уже существует"
            )
        
        # Создаем нового пользователя
        hashed_password = get_password_hash(user_data.password)
        new_user = User(
            email=user_data.email,
            username=user_data.username,
            hashed_password=hashed_password,
            is_active=True,
            is_verified=False  # В продакшене можно добавить email активацию
        )
        
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        
        return new_user
    
    @staticmethod
    def authenticate_user(db: Session, user_data: UserLogin, ip_address: Optional[str] = None, user_agent: Optional[str] = None) -> tuple[User, str, str]:
        """Аутентификация пользователя"""
        # Находим пользователя по email
        user = db.query(User).filter(User.email == user_data.email).first()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Неверный email или пароль"
            )
        
        # Проверяем пароль
        if not verify_password(user_data.password, user.hashed_password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Неверный email или пароль"
            )
        
        # Проверяем, активен ли пользователь
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Пользователь неактивен"
            )
        
        # Обновляем время последнего входа
        user.last_login = datetime.utcnow()
        db.commit()
        
        # Создаем токены
        access_token_data = {"sub": str(user.id), "email": user.email}
        access_token = create_access_token(access_token_data)
        refresh_token = create_refresh_token(access_token_data)
        
        # Кэшируем токен
        cache_token(access_token, user.id, settings.access_token_expire_minutes)
        
        # Создаем сессию
        session_id = generate_session_id()
        expires_at = datetime.utcnow() + timedelta(days=settings.refresh_token_expire_days)
        
        session = SessionModel(
            user_id=user.id,
            session_id=session_id,
            refresh_token=refresh_token,
            ip_address=ip_address,
            user_agent=user_agent,
            expires_at=expires_at
        )
        db.add(session)
        db.commit()
        
        # Кэшируем сессию в Redis
        cache_session(
            session_id,
            user.id,
            {
                "refresh_token": refresh_token,
                "ip_address": ip_address,
                "user_agent": user_agent
            },
            settings.refresh_token_expire_days
        )
        
        return user, access_token, refresh_token
    
    @staticmethod
    def refresh_access_token(db: Session, refresh_token: str) -> tuple[str, str]:
        """Обновление access токена"""
        # Декодируем refresh токен
        payload = decode_token(refresh_token)
        if not payload or payload.get("type") != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Неверный refresh токен"
            )
        
        user_id = int(payload.get("sub"))
        user = db.query(User).filter(User.id == user_id).first()
        if not user or not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Пользователь не найден или неактивен"
            )
        
        # Проверяем, существует ли сессия с таким refresh токеном
        session = db.query(SessionModel).filter(
            SessionModel.refresh_token == refresh_token,
            SessionModel.user_id == user_id,
            SessionModel.expires_at > datetime.utcnow()
        ).first()
        
        if not session:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Сессия не найдена или истекла"
            )
        
        # Создаем новый access токен
        access_token_data = {"sub": str(user.id), "email": user.email}
        new_access_token = create_access_token(access_token_data)
        
        # Кэшируем новый токен
        cache_token(new_access_token, user.id, settings.access_token_expire_minutes)
        
        # Обновляем время последней активности
        session.last_activity = datetime.utcnow()
        db.commit()
        
        return new_access_token, refresh_token
    
    @staticmethod
    def get_user_by_id(db: Session, user_id: int) -> Optional[User]:
        """Получить пользователя по ID"""
        return db.query(User).filter(User.id == user_id).first()
    
    @staticmethod
    def get_user_sessions(db: Session, user_id: int) -> list[SessionModel]:
        """Получить все сессии пользователя"""
        return db.query(SessionModel).filter(
            SessionModel.user_id == user_id,
            SessionModel.expires_at > datetime.utcnow()
        ).all()
    
    @staticmethod
    def delete_session(db: Session, session_id: str, user_id: int) -> bool:
        """Удалить сессию"""
        session = db.query(SessionModel).filter(
            SessionModel.session_id == session_id,
            SessionModel.user_id == user_id
        ).first()
        
        if not session:
            return False
        
        db.delete(session)
        db.commit()
        
        # Удаляем из Redis
        from app.redis_client import delete_session
        delete_session(session_id, user_id)
        
        return True
