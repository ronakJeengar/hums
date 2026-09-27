import uuid
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.audio import TrackResponse
from app.schemas.playlist import PlaylistResponse
from app.schemas.search import SearchAlbumItem


class CreatorPublicProfile(BaseModel):
    """Public creator / artist profile schema without private user data."""
    id: uuid.UUID
    name: str
    username: Optional[str] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    cover_image_url: Optional[str] = None
    is_verified: bool = False
    followers_count: int = 0
    is_following: Optional[bool] = None
    track_count: Optional[int] = 0
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class CreatorDetailResponse(BaseModel):
    """Detailed creator profile response with public content aggregates."""
    id: uuid.UUID
    name: str
    username: Optional[str] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    cover_image_url: Optional[str] = None
    is_verified: bool = False
    followers_count: int = 0
    is_following: Optional[bool] = None
    popular_tracks: List[TrackResponse] = Field(default_factory=list)
    latest_tracks: List[TrackResponse] = Field(default_factory=list)
    albums: List[SearchAlbumItem] = Field(default_factory=list)
    public_playlists: List[PlaylistResponse] = Field(default_factory=list)
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class FollowStatusResponse(BaseModel):
    """Response returned upon follow, unfollow, and follow status checks."""
    creator_id: uuid.UUID
    is_following: bool
    followers_count: int

    model_config = ConfigDict(from_attributes=True)


class FollowerUserItem(BaseModel):
    """Public summary of a follower user."""
    id: uuid.UUID
    name: str
    username: Optional[str] = None
    avatar_url: Optional[str] = None
    followed_at: datetime

    model_config = ConfigDict(from_attributes=True)


class FollowersListResponse(BaseModel):
    """Paginated response of a creator's public followers."""
    items: List[FollowerUserItem] = Field(default_factory=list)
    total: int
    page: int
    size: int
    has_more: bool


class FollowingListResponse(BaseModel):
    """Paginated response of creators followed by a user."""
    items: List[CreatorPublicProfile] = Field(default_factory=list)
    total: int
    page: int
    size: int
    has_more: bool
