import uuid
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class UpNextTrackItem(BaseModel):
    """Client-facing track schema for queue and up-next recommendations."""
    id: uuid.UUID
    title: str
    artist_name: Optional[str] = None
    album_name: Optional[str] = None
    genre: Optional[str] = None
    duration_seconds: Optional[int] = None
    artwork_url: Optional[str] = None
    status: str = "READY"
    waveform_key: Optional[str] = None
    source: str = Field(default="smart_queue", description="Origin of recommendation, e.g. genre_match, artist_match, trending, personalized")

    model_config = ConfigDict(from_attributes=True)


class UpNextResponse(BaseModel):
    """Smart Queue candidate tracks response."""
    items: List[UpNextTrackItem] = Field(default_factory=list)
    total: int
    context: Optional[str] = Field(default=None, description="Contextual reason for queue recommendations")

    model_config = ConfigDict(from_attributes=True)


class TrackResolveResponse(BaseModel):
    """Response containing resolved track metadata for queued items."""
    items: List[UpNextTrackItem] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)
