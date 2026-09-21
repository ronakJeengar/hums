import uuid
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator


class PlaylistCreate(BaseModel):
    """Schema for creating a new user playlist."""
    name: str = Field(..., min_length=1, max_length=255, description="Playlist name")
    description: Optional[str] = Field(None, max_length=1000, description="Optional playlist description")

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        trimmed = v.strip()
        if not trimmed:
            raise ValueError("Playlist name cannot be empty or whitespace only")
        return trimmed

    @field_validator("description")
    @classmethod
    def validate_description(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            trimmed = v.strip()
            return trimmed if trimmed else None
        return None


class PlaylistUpdate(BaseModel):
    """Schema for updating playlist metadata."""
    name: Optional[str] = Field(None, min_length=1, max_length=255, description="Updated playlist name")
    description: Optional[str] = Field(None, max_length=1000, description="Updated playlist description")
    is_public: Optional[bool] = Field(None, description="Playlist visibility")

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            trimmed = v.strip()
            if not trimmed:
                raise ValueError("Playlist name cannot be empty or whitespace only")
            return trimmed
        return None

    @field_validator("description")
    @classmethod
    def validate_description(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            trimmed = v.strip()
            return trimmed if trimmed else None
        return None


class PlaylistTrackAdd(BaseModel):
    """Schema for adding a track to a playlist."""
    track_id: uuid.UUID = Field(..., description="ID of the track to add")


class PlaylistTracksReorder(BaseModel):
    """Schema for reordering all tracks in a playlist."""
    track_ids: List[uuid.UUID] = Field(..., min_length=1, description="Ordered list of track IDs")

    @field_validator("track_ids")
    @classmethod
    def validate_unique_track_ids(cls, v: List[uuid.UUID]) -> List[uuid.UUID]:
        if len(v) != len(set(v)):
            raise ValueError("track_ids must not contain duplicate entries")
        return v


class PlaylistTrackItem(BaseModel):
    """Schema representing an individual track item within a playlist."""
    id: uuid.UUID
    track_id: uuid.UUID
    position: int
    added_at: datetime
    title: str
    artist_name: Optional[str] = None
    album_name: Optional[str] = None
    duration_seconds: Optional[int] = None
    waveform_key: Optional[str] = None
    status: str

    model_config = ConfigDict(from_attributes=True)


class PlaylistResponse(BaseModel):
    """Playlist summary response schema."""
    id: uuid.UUID
    owner_id: uuid.UUID
    name: str
    description: Optional[str] = None
    cover_image_key: Optional[str] = None
    cover_image_url: Optional[str] = None
    is_public: bool
    track_count: int = 0
    duration_seconds: int = 0
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class PlaylistDetailResponse(PlaylistResponse):
    """Detailed playlist response schema including all ordered track items."""
    tracks: List[PlaylistTrackItem] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)
