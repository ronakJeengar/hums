import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, ConfigDict, Field


class CreatorTrackItem(BaseModel):
    id: uuid.UUID
    title: str
    artist_name: Optional[str] = None
    album_name: Optional[str] = None
    genre: Optional[str] = None
    duration_seconds: Optional[int] = None
    status: str
    is_published: bool = True
    cover_image_key: Optional[str] = None
    likes_count: int = 0
    play_count: int = 0
    created_at: datetime
    waveform_key: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class AudioFileInfo(BaseModel):
    id: uuid.UUID
    original_filename: str
    mime_type: str
    file_size_bytes: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AudioRenditionInfo(BaseModel):
    id: uuid.UUID
    format: str
    codec: str
    bitrate_kbps: int
    sample_rate: Optional[int] = None
    channels: Optional[int] = None
    duration_seconds: Optional[int] = None
    file_size_bytes: int
    storage_key: str

    model_config = ConfigDict(from_attributes=True)


class ProcessingJobInfo(BaseModel):
    id: uuid.UUID
    job_type: str
    status: str
    attempts: int
    error_message: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class CreatorTrackDetail(CreatorTrackItem):
    description: Optional[str] = None
    audio_files: List[AudioFileInfo] = []
    renditions: List[AudioRenditionInfo] = []
    processing_jobs: List[ProcessingJobInfo] = []


class CreatorDashboardStats(BaseModel):
    published_tracks: int
    processing_tracks: int
    failed_uploads: int
    total_plays: int
    follower_count: int
    total_likes: int
    top_tracks: List[CreatorTrackItem] = []
    recent_uploads: List[CreatorTrackItem] = []


class UpdateTrackRequest(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=255)
    artist_name: Optional[str] = Field(None, max_length=255)
    album_name: Optional[str] = Field(None, max_length=255)
    genre: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = None


class SetPublishingRequest(BaseModel):
    is_published: bool


class BulkItemResult(BaseModel):
    track_id: uuid.UUID
    title: Optional[str] = None
    status: str  # "success" or "failed"
    message: Optional[str] = None
    error: Optional[str] = None


class BulkTrackActionResult(BaseModel):
    action: str
    total: int
    succeeded: int
    failed: int
    results: List[BulkItemResult] = []


class CreatorBulkTrackActionRequest(BaseModel):
    model_config = ConfigDict(extra="allow")

    track_ids: List[uuid.UUID] = Field(..., min_length=1, max_length=50)
    action: str = Field(..., pattern="^(publish|unpublish|retry|update_metadata)$")
    genre: Optional[str] = None
    title: Optional[str] = None
    artist_name: Optional[str] = None
    album_name: Optional[str] = None
    description: Optional[str] = None
    data: Optional[Dict[str, Any]] = None


class TrackArtworkUploadResponse(BaseModel):
    track_id: uuid.UUID
    cover_image_key: str
    cover_image_url: Optional[str] = None


class DailyPlayStat(BaseModel):
    date: str
    plays: int


class TrackPlayStat(BaseModel):
    track_id: uuid.UUID
    title: str
    plays: int


class CreatorAnalyticsResponse(BaseModel):
    period: str
    total_plays: int
    unique_listeners: int
    plays_timeline: List[DailyPlayStat] = []
    top_tracks: List[TrackPlayStat] = []
    sources_breakdown: Dict[str, int] = {}


class CreatorStudioProfile(BaseModel):
    id: uuid.UUID
    user_id: Optional[uuid.UUID] = None
    name: str
    username: Optional[str] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    cover_image_url: Optional[str] = None
    is_verified: bool
    followers_count: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class UpdateCreatorProfileRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=255)
    bio: Optional[str] = Field(None, max_length=2000)
    avatar_url: Optional[str] = Field(None, max_length=500)
    cover_image_url: Optional[str] = Field(None, max_length=500)
