import uuid
from datetime import datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class PlaybackEventType(str, Enum):
    PLAY_STARTED = "PLAY_STARTED"
    PROGRESS_CHECKPOINT = "PROGRESS_CHECKPOINT"
    PAUSED = "PAUSED"
    RESUMED = "RESUMED"
    SEEKED = "SEEKED"
    SKIPPED = "SKIPPED"
    COMPLETED = "COMPLETED"
    STOPPED = "STOPPED"


class PlaybackTrackSummary(BaseModel):
    """Essential track metadata for playback history and queue contexts."""
    id: uuid.UUID
    owner_id: uuid.UUID
    title: str
    description: Optional[str] = None
    artist_name: Optional[str] = None
    album_name: Optional[str] = None
    genre: Optional[str] = None
    duration_seconds: Optional[int] = None
    waveform_key: Optional[str] = None
    status: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class PlaybackProgressUpdateRequest(BaseModel):
    """Direct progress update payload from client checkpoint."""
    position_ms: int = Field(..., ge=0, description="Current track position in milliseconds")
    duration_ms: int = Field(..., ge=0, description="Total track duration in milliseconds")
    completed: Optional[bool] = Field(None, description="Optional explicit completion flag")


class PlaybackProgressResponse(BaseModel):
    """Resume progress state for a track."""
    track_id: uuid.UUID
    position_ms: int
    duration_ms: int
    completed: bool
    progress_percent: float
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class PlaybackBatchProgressResponse(BaseModel):
    """Batch progress lookup response."""
    items: List[PlaybackProgressResponse]


class PlaybackEventCreateRequest(BaseModel):
    """Single playback event ingestion request."""
    event_id: uuid.UUID = Field(..., description="Unique client-generated event UUID for idempotency")
    track_id: uuid.UUID = Field(..., description="Target track UUID")
    event_type: PlaybackEventType = Field(..., description="Playback lifecycle event type")
    position_ms: int = Field(..., ge=0, description="Position when event occurred in milliseconds")
    duration_ms: int = Field(..., ge=0, description="Track duration in milliseconds")
    played_at: datetime = Field(..., description="Client timestamp in UTC when the event occurred")
    source: str = Field(default="player", max_length=50, description="Event source e.g. player, offline_sync")
    device_id: Optional[str] = Field(None, max_length=100, description="Client device identifier")


class PlaybackBatchEventsRequest(BaseModel):
    """Batch of playback events (typically from offline queue sync)."""
    events: List[PlaybackEventCreateRequest] = Field(
        ...,
        min_length=1,
        max_length=100,
        description="Batched playback events (max 100 items)",
    )


class PlaybackEventsIngestResponse(BaseModel):
    """Result summary of batched event ingestion."""
    accepted_count: int
    duplicate_count: int
    message: str


class ListeningHistoryItemResponse(BaseModel):
    """A recently played track item in user listening history."""
    id: uuid.UUID
    track_id: uuid.UUID
    position_ms: int
    duration_ms: int
    completed: bool
    progress_percent: float
    last_played_at: datetime
    track: Optional[PlaybackTrackSummary] = None

    model_config = ConfigDict(from_attributes=True)


class ListeningHistoryListResponse(BaseModel):
    """Paginated listening history response."""
    items: List[ListeningHistoryItemResponse]
    total: int
    skip: int
    limit: int
    has_more: bool


class RecommendationListeningSignal(BaseModel):
    """Aggregated listening signal for feeding the recommendation engine."""
    track_id: uuid.UUID
    play_count: int
    completion_count: int
    total_duration_listened_ms: int
    last_played_at: datetime
    completed: bool
