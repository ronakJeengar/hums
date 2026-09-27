from datetime import datetime, timezone
from typing import Any, Dict, Generic, Optional, TypeVar
from pydantic import BaseModel, Field

DataT = TypeVar("DataT")


class ApiMeta(BaseModel):
    timestamp: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    version: str = "1.0.0"


class ApiResponse(BaseModel, Generic[DataT]):
    success: bool = True
    data: DataT
    meta: ApiMeta = Field(default_factory=ApiMeta)


class MessageData(BaseModel):
    message: str


class ErrorDetail(BaseModel):
    code: str
    message: str
    details: Dict[str, Any] = Field(default_factory=dict)


class ErrorResponse(BaseModel):
    success: bool = False
    error: ErrorDetail


class HealthServiceStatus(BaseModel):
    database: str
    redis: str
    celery_broker: Optional[str] = "connected"
    storage: Optional[str] = "connected"


class HealthData(BaseModel):
    status: str
    version: str = "1.0.0"
    environment: str
    services: HealthServiceStatus
