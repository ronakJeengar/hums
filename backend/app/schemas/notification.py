import uuid
from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, ConfigDict, Field


class NotificationType(str, Enum):
    NEW_RELEASE = "NEW_RELEASE"
    PLAYLIST_UPDATE = "PLAYLIST_UPDATE"
    UPLOAD_COMPLETE = "UPLOAD_COMPLETE"
    TRANSCRIPTION_COMPLETE = "TRANSCRIPTION_COMPLETE"
    RECOMMENDATION_READY = "RECOMMENDATION_READY"
    SYSTEM = "SYSTEM"


class PlatformType(str, Enum):
    ANDROID = "ANDROID"
    IOS = "IOS"
    WEB = "WEB"


# ---------------------------------------------------------------------------
# Device Schemas
# ---------------------------------------------------------------------------

class DeviceRegistrationRequest(BaseModel):
    token: str = Field(..., min_length=10, max_length=500, description="Push notification token (FCM or APNs)")
    platform: PlatformType = Field(default=PlatformType.ANDROID, description="Target device platform")
    device_name: Optional[str] = Field(None, max_length=100, description="Optional human-readable device model/name")
    app_version: Optional[str] = Field(None, max_length=50, description="Current client app version string")


class DeviceResponse(BaseModel):
    id: uuid.UUID
    device_token: str
    platform: str
    device_name: Optional[str] = None
    app_version: Optional[str] = None
    is_active: bool
    last_seen_at: datetime
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------------------------
# Notification Preferences Schemas
# ---------------------------------------------------------------------------

class NotificationPreferencesResponse(BaseModel):
    push_enabled: bool = True
    new_releases_enabled: bool = True
    playlist_updates_enabled: bool = True
    recommendations_enabled: bool = True
    processing_updates_enabled: bool = True

    model_config = ConfigDict(from_attributes=True)


class NotificationPreferencesUpdate(BaseModel):
    push_enabled: Optional[bool] = None
    new_releases_enabled: Optional[bool] = None
    playlist_updates_enabled: Optional[bool] = None
    recommendations_enabled: Optional[bool] = None
    processing_updates_enabled: Optional[bool] = None


# ---------------------------------------------------------------------------
# Notification History & Item Schemas
# ---------------------------------------------------------------------------

class NotificationItemResponse(BaseModel):
    id: uuid.UUID
    type: str
    title: str
    body: str
    data: Optional[Dict[str, Any]] = None
    is_read: bool
    read_at: Optional[datetime] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class NotificationListResponse(BaseModel):
    items: List[NotificationItemResponse]
    total: int
    skip: int
    limit: int


class UnreadCountResponse(BaseModel):
    unread_count: int


class ReadAllResponse(BaseModel):
    marked_count: int
