import uuid
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class RecommendedTrackItem(BaseModel):
    """Safe, client-facing recommended track schema."""
    id: uuid.UUID
    title: str
    artist_name: Optional[str] = None
    album_name: Optional[str] = None
    genre: Optional[str] = None
    duration_seconds: Optional[int] = None
    artwork_url: Optional[str] = None
    status: str = "READY"
    waveform_key: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class RecommendationSection(BaseModel):
    """A distinct recommendation section containing an ordered group of tracks."""
    id: str = Field(description="Section machine identifier (e.g. 'for-you', 'trending', 'discover')")
    title: str = Field(description="Human-readable section title")
    description: Optional[str] = Field(default=None, description="Section subtitle or explanation")
    items: List[RecommendedTrackItem] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


class RecommendationResponse(BaseModel):
    """Top-level recommendation payload returned by GET /recommendations."""
    sections: List[RecommendationSection] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)


class RecommendationRefreshResponse(BaseModel):
    """Response returned when triggering a recommendation cache refresh."""
    message: str
    queued: bool = False
