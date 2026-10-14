import uuid
from datetime import datetime
from typing import Dict, List, Optional
from pydantic import BaseModel, ConfigDict, Field


class CreatorTrackItem(BaseModel):
    id: uuid.UUID
    title: str
    artist_name: Optional[str] = None
    album_name: Optional[str] = None
    genre: Optional[str] = None
    duration_seconds: Optional[int] = None
    status: str
    likes_count: int = 0
    play_count: int = 0
    created_at: datetime
    waveform_key: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


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
