"""
Pydantic схемы для статистики
"""
from pydantic import BaseModel
from typing import Optional


class StatsResponse(BaseModel):
    """Схема ответа со статистикой"""
    bytes_sent: int
    bytes_received: int
    requests: int
    total_bytes: int
    
    @classmethod
    def from_dict(cls, data: dict):
        """Создать из словаря"""
        total = data.get("bytes_sent", 0) + data.get("bytes_received", 0)
        return cls(
            bytes_sent=data.get("bytes_sent", 0),
            bytes_received=data.get("bytes_received", 0),
            requests=data.get("requests", 0),
            total_bytes=total
        )
