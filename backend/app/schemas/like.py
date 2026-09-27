import uuid
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict


class LikeStatusResponse(BaseModel):
    """Like status and authoritative counter for a track."""
    track_id: uuid.UUID
    is_liked: bool
    likes_count: int

    model_config = ConfigDict(from_attributes=True)


class LikedTrackItem(BaseModel):
    """Track metadata item for personal library liked tracks."""
    id: uuid.UUID
    title: str
    artist_name: Optional[str] = None
    album_name: Optional[str] = None
    genre: Optional[str] = None
    duration_seconds: Optional[int] = None
    waveform_key: Optional[str] = None
    status: str
    likes_count: int = 0
    is_liked: bool = True
    liked_at: datetime
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class LikedTracksListResponse(BaseModel):
    """Paginated collection of user's liked tracks."""
    items: List[LikedTrackItem]
    total: int
    page: int
    size: int
    has_next: bool

    model_config = ConfigDict(from_attributes=True)
