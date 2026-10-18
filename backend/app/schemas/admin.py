import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, ConfigDict, Field


class AdminDashboardStats(BaseModel):
    total_users: int
    active_users_30d: int
    total_creators: int
    published_tracks: int
    failed_uploads: int
    pending_applications: int
    pending_reports: int
    subscriptions_summary: Dict[str, int]
    recent_activity: List["AdminAuditLogItem"] = []


class AdminUserItem(BaseModel):
    id: uuid.UUID
    email: str
    username: Optional[str] = None
    full_name: Optional[str] = None
    role: str = "listener"
    is_active: bool
    is_verified: bool
    suspension_reason: Optional[str] = None
    created_at: datetime
    last_login_at: Optional[datetime] = None
    tracks_count: int = 0
    has_creator_profile: bool = False
    subscription_tier: str = "FREE"

    model_config = ConfigDict(from_attributes=True)


class AdminUserDetail(AdminUserItem):
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    creator_id: Optional[uuid.UUID] = None
    creator_name: Optional[str] = None
    recent_tracks: List[Dict[str, Any]] = []


class UpdateUserStatusRequest(BaseModel):
    is_active: bool
    reason: Optional[str] = Field(None, max_length=500)


class UpdateUserRoleRequest(BaseModel):
    role: str = Field(..., pattern="^(listener|creator|moderator|admin)$")
    reason: Optional[str] = Field(None, max_length=500)


class AdminCreatorItem(BaseModel):
    id: uuid.UUID
    user_id: Optional[uuid.UUID] = None
    user_email: Optional[str] = None
    name: str
    username: Optional[str] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    cover_image_url: Optional[str] = None
    is_verified: bool
    followers_count: int
    tracks_count: int = 0
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class VerifyCreatorRequest(BaseModel):
    is_verified: bool
    reason: Optional[str] = Field(None, max_length=500)


class CreatorApplicationItem(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    user_email: Optional[str] = None
    user_name: Optional[str] = None
    artist_name: str
    bio: Optional[str] = None
    genres: Optional[str] = None
    portfolio_url: Optional[str] = None
    status: str  # PENDING, APPROVED, REJECTED
    reviewer_id: Optional[uuid.UUID] = None
    review_notes: Optional[str] = None
    created_at: datetime
    reviewed_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class CreateCreatorApplicationRequest(BaseModel):
    artist_name: str = Field(..., min_length=2, max_length=255)
    bio: Optional[str] = Field(None, max_length=2000)
    genres: Optional[str] = Field(None, max_length=255)
    portfolio_url: Optional[str] = Field(None, max_length=500)


class ReviewApplicationRequest(BaseModel):
    status: str = Field(..., pattern="^(APPROVED|REJECTED)$")
    review_notes: Optional[str] = Field(None, max_length=1000)


class AdminTrackItem(BaseModel):
    id: uuid.UUID
    title: str
    artist_name: Optional[str] = None
    album_name: Optional[str] = None
    genre: Optional[str] = None
    duration_seconds: Optional[int] = None
    status: str  # UPLOADED, PROCESSING, READY, FAILED, MODERATED
    is_published: bool = True
    cover_image_key: Optional[str] = None
    owner_id: uuid.UUID
    owner_email: Optional[str] = None
    created_at: datetime
    likes_count: int = 0
    play_count: int = 0

    model_config = ConfigDict(from_attributes=True)


class AdminTrackDetail(AdminTrackItem):
    description: Optional[str] = None
    waveform_key: Optional[str] = None
    renditions: List[Dict[str, Any]] = []
    processing_jobs: List[Dict[str, Any]] = []
    audit_logs: List[Dict[str, Any]] = []


class ModerateTrackRequest(BaseModel):
    status: str = Field(..., pattern="^(READY|MODERATED|FAILED)$")
    reason: str = Field(..., min_length=3, max_length=500)


class AdminBulkTrackActionRequest(BaseModel):
    model_config = ConfigDict(extra="allow")

    track_ids: List[uuid.UUID] = Field(..., min_length=1, max_length=50)
    action: str = Field(..., pattern="^(moderate|retry|publish|unpublish|update_metadata)$")
    reason: str = Field(..., min_length=3, max_length=500)
    status: Optional[str] = Field(None, pattern="^(READY|MODERATED|FAILED)$")
    target_status: Optional[str] = Field(None, pattern="^(READY|MODERATED|FAILED)$")
    data: Optional[Dict[str, Any]] = None
    metadata_updates: Optional[Dict[str, Any]] = None


class ContentReportItem(BaseModel):
    id: uuid.UUID
    reporter_id: uuid.UUID
    reporter_email: Optional[str] = None
    entity_type: str  # track, creator, user
    entity_id: uuid.UUID
    entity_name: Optional[str] = None
    reason: str  # COPYRIGHT, INAPPROPRIATE, SPAM, HARASSMENT, OTHER
    description: Optional[str] = None
    status: str  # PENDING, INVESTIGATING, RESOLVED, DISMISSED
    moderator_id: Optional[uuid.UUID] = None
    resolution_notes: Optional[str] = None
    action_taken: Optional[str] = None
    created_at: datetime
    resolved_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class CreateReportRequest(BaseModel):
    entity_type: str = Field(..., pattern="^(track|creator|user)$")
    entity_id: uuid.UUID
    reason: str = Field(..., min_length=2, max_length=100)
    description: Optional[str] = Field(None, max_length=2000)


class ResolveReportRequest(BaseModel):
    status: str = Field(..., pattern="^(RESOLVED|DISMISSED|INVESTIGATING)$")
    action_taken: Optional[str] = Field(None, max_length=100)
    resolution_notes: Optional[str] = Field(None, max_length=1000)


class AdminAuditLogItem(BaseModel):
    id: uuid.UUID
    actor_id: uuid.UUID
    actor_email: str
    action: str
    target_type: str
    target_id: str
    details: Optional[Dict[str, Any]] = None
    reason: Optional[str] = None
    ip_address: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SystemHealthStatus(BaseModel):
    database: bool
    redis: bool
    celery_broker: bool
    storage: bool
    environment: str
    timestamp: datetime


class ProcessingJobItem(BaseModel):
    id: uuid.UUID
    track_id: uuid.UUID
    track_title: Optional[str] = None
    job_type: str
    status: str
    attempts: int
    error_message: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# Forward reference resolution
AdminDashboardStats.model_rebuild()
