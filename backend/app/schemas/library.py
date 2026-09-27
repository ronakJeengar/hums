from typing import List
from pydantic import BaseModel, ConfigDict
from app.schemas.like import LikedTrackItem


class LibrarySummaryResponse(BaseModel):
    """Structured summary of user's personal library metrics and recent content."""
    liked_tracks_count: int = 0
    playlists_count: int = 0
    following_creators_count: int = 0
    recent_liked_tracks: List[LikedTrackItem] = []

    model_config = ConfigDict(from_attributes=True)
