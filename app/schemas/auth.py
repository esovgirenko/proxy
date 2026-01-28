"""
Pydantic схемы для авторизации
"""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class Token(BaseModel):
    """Схема токена"""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class TokenRefresh(BaseModel):
    """Схема для обновления токена"""
    refresh_token: str


class SessionResponse(BaseModel):
    """Схема ответа с данными сессии"""
    id: int
    session_id: str
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    created_at: datetime
    expires_at: datetime
    last_activity: datetime
    
    class Config:
        from_attributes = True
