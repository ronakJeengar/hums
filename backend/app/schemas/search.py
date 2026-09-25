import uuid
from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class SearchType(str, Enum):
    """Allowed entity filter types for search endpoint."""
    ALL = "all"
    TRACKS = "tracks"
    ARTISTS = "artists"
    ALBUMS = "albums"
    PLAYLISTS = "playlists"
    PODCASTS = "podcasts"
    EPISODES = "episodes"


class SearchTrackItem(BaseModel):
    """Search result item representing an audio track."""
    id: uuid.UUID
    owner_id: uuid.UUID
    title: str
    description: str | None = None
    artist_name: str | None = None
    album_name: str | None = None
    genre: str | None = None
    duration_seconds: int | None = None
    waveform_key: str | None = None
    status: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SearchArtistItem(BaseModel):
    """Search result item representing an artist or creator."""
    id: str
    name: str
    username: str | None = None
    avatar_url: str | None = None
    bio: str | None = None
    track_count: int = 0

    model_config = ConfigDict(from_attributes=True)


class SearchAlbumItem(BaseModel):
    """Search result item representing a music album."""
    id: str
    title: str
    artist_name: str | None = None
    track_count: int = 0
    cover_image_key: str | None = None
    cover_image_url: str | None = None

    model_config = ConfigDict(from_attributes=True)


class SearchPlaylistItem(BaseModel):
    """Search result item representing a curated playlist."""
    id: uuid.UUID
    owner_id: uuid.UUID
    name: str
    description: str | None = None
    cover_image_key: str | None = None
    cover_image_url: str | None = None
    is_public: bool
    track_count: int = 0
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SearchPodcastItem(BaseModel):
    """Search result item representing a podcast show."""
    id: str
    title: str
    description: str | None = None
    host: str | None = None
    cover_image_url: str | None = None
    episode_count: int = 0

    model_config = ConfigDict(from_attributes=True)


class SearchEpisodeItem(BaseModel):
    """Search result item representing a podcast episode."""
    id: str
    podcast_id: str | None = None
    title: str
    description: str | None = None
    duration_seconds: int | None = None
    published_at: datetime | None = None
    podcast_title: str | None = None

    model_config = ConfigDict(from_attributes=True)


class SearchResponse(BaseModel):
    """Unified search response payload containing categorized entities and item counts."""
    query: str
    type: str = "all"
    total_tracks: int = 0
    total_artists: int = 0
    total_albums: int = 0
    total_playlists: int = 0
    total_podcasts: int = 0
    total_episodes: int = 0
    tracks: list[SearchTrackItem] = Field(default_factory=list)
    artists: list[SearchArtistItem] = Field(default_factory=list)
    albums: list[SearchAlbumItem] = Field(default_factory=list)
    playlists: list[SearchPlaylistItem] = Field(default_factory=list)
    podcasts: list[SearchPodcastItem] = Field(default_factory=list)
    episodes: list[SearchEpisodeItem] = Field(default_factory=list)


class SearchSuggestionsResponse(BaseModel):
    """Lightweight autocomplete suggestion payload."""
    query: str
    suggestions: list[str] = Field(default_factory=list)
