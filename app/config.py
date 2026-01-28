"""
Конфигурация приложения
"""
import os
from typing import List
from pydantic_settings import BaseSettings
from pydantic import Field
import yaml
from pathlib import Path


class Settings(BaseSettings):
    """Настройки приложения из переменных окружения и config.yaml"""
    
    # Server
    server_host: str = Field(default="0.0.0.0", env="SERVER_HOST")
    server_port: int = Field(default=8080, env="SERVER_PORT")
    log_level: str = Field(default="info", env="LOG_LEVEL")
    
    # Database
    database_url: str = Field(env="DATABASE_URL")
    database_pool_size: int = Field(default=20, env="DATABASE_POOL_SIZE")
    database_max_overflow: int = Field(default=10, env="DATABASE_MAX_OVERFLOW")
    
    # Redis
    redis_url: str = Field(env="REDIS_URL")
    redis_decode_responses: bool = Field(default=True, env="REDIS_DECODE_RESPONSES")
    
    # JWT
    jwt_secret_key: str = Field(env="JWT_SECRET_KEY")
    jwt_algorithm: str = Field(default="HS256", env="JWT_ALGORITHM")
    access_token_expire_minutes: int = Field(default=30, env="ACCESS_TOKEN_EXPIRE_MINUTES")
    refresh_token_expire_days: int = Field(default=30, env="REFRESH_TOKEN_EXPIRE_DAYS")
    
    # Security
    password_min_length: int = Field(default=8, env="PASSWORD_MIN_LENGTH")
    rate_limit_per_minute: int = Field(default=60, env="RATE_LIMIT_PER_MINUTE")
    max_request_size_mb: int = Field(default=10, env="MAX_REQUEST_SIZE_MB")
    
    # Proxy
    proxy_connect_timeout: int = Field(default=10, env="PROXY_CONNECT_TIMEOUT")
    proxy_read_timeout: int = Field(default=30, env="PROXY_READ_TIMEOUT")
    proxy_max_connections_per_user: int = Field(default=100, env="PROXY_MAX_CONNECTIONS_PER_USER")
    
    # iOS
    ios_user_agent: str = Field(default="iOS/26.1", env="IOS_USER_AGENT")
    
    # CORS
    cors_allow_origins: List[str] = Field(default=["*"], env="CORS_ALLOW_ORIGINS")
    cors_allow_credentials: bool = Field(default=True, env="CORS_ALLOW_CREDENTIALS")
    cors_allow_methods: List[str] = Field(
        default=["GET", "POST", "PUT", "DELETE", "CONNECT", "OPTIONS"],
        env="CORS_ALLOW_METHODS"
    )
    cors_allow_headers: List[str] = Field(default=["*"], env="CORS_ALLOW_HEADERS")
    
    # Domain
    domain: str = Field(default="localhost", env="DOMAIN")
    
    # Email (optional)
    smtp_host: str = Field(default="", env="SMTP_HOST")
    smtp_port: int = Field(default=587, env="SMTP_PORT")
    smtp_user: str = Field(default="", env="SMTP_USER")
    smtp_password: str = Field(default="", env="SMTP_PASSWORD")
    email_from: str = Field(default="noreply@proxy.example.com", env="EMAIL_FROM")
    
    # Sentry (optional)
    sentry_dsn: str = Field(default="", env="SENTRY_DSN")
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


def load_config_from_yaml() -> dict:
    """Загружает конфигурацию из config.yaml"""
    config_path = Path(__file__).parent.parent / "config.yaml"
    if config_path.exists():
        with open(config_path, "r", encoding="utf-8") as f:
            return yaml.safe_load(f)
    return {}


# Загружаем настройки
# Переменные окружения имеют приоритет над config.yaml
settings = Settings()
