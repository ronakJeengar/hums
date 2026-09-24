import uuid
from datetime import datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class SearchType(str, Enum):
    """Allowed entity filter types for search endpoint."""
    ALL = "all"
    TRACKS = "tracks"
    ARTISTS = "artists"
    PLAYLISTS = "playlists"


class SearchTrackItem(BaseModel):
    """Search result item representing an audio track."""
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
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SearchArtistItem(BaseModel):
    """Search result item representing an artist or creator."""
    id: str
    name: str
    username: Optional[str] = None
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    track_count: int = 0

    model_config = ConfigDict(from_attributes=True)


class SearchPlaylistItem(BaseModel):
    """Search result item representing a curated playlist."""
    id: uuid.UUID
    owner_id: uuid.UUID
    name: str
    description: Optional[str] = None
    cover_image_key: Optional[str] = None
    cover_image_url: Optional[str] = None
    is_public: bool
    track_count: int = 0
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SearchResponse(BaseModel):
    """Unified search response payload containing categorized entities and item counts."""
    query: str
    type: str = "all"
    total_tracks: int = 0
    total_artists: int = 0
    total_playlists: int = 0
    tracks: List[SearchTrackItem] = Field(default_factory=list)
    artists: List[SearchArtistItem] = Field(default_factory=list)
    playlists: List[SearchPlaylistItem] = Field(default_factory=list)
