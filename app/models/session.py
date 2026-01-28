"""
Модель сессии пользователя
"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text, Index
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base


class Session(Base):
    """Модель сессии пользователя"""
    __tablename__ = "sessions"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    session_id = Column(String(255), unique=True, index=True, nullable=False)
    refresh_token = Column(Text, nullable=True)
    ip_address = Column(String(45), nullable=True)  # IPv6 support
    user_agent = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    last_activity = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    
    # Связи
    user = relationship("User", back_populates="sessions")
    
    __table_args__ = (
        Index('idx_user_expires', 'user_id', 'expires_at'),
    )
    
    def __repr__(self):
        return f"<Session(id={self.id}, user_id={self.user_id}, session_id={self.session_id})>"
