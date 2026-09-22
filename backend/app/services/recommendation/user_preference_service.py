from collections import Counter
from dataclasses import dataclass, field
from typing import List, Set
import uuid

from app.db.models.user import User
from app.repositories.audio_repository import TrackRepository
from app.repositories.playlist_repository import PlaylistRepository


@dataclass
class UserPreferences:
    """Extracted recommendation signals for a user."""
    preferred_genres: List[str] = field(default_factory=list)
    preferred_artists: List[str] = field(default_factory=list)
    excluded_track_ids: Set[uuid.UUID] = field(default_factory=set)
    total_signals: int = 0

    @property
    def is_cold_start(self) -> bool:
        """Indicates if the user has insufficient signals for deep personalization."""
        return not self.preferred_genres and not self.preferred_artists and self.total_signals == 0


class UserPreferenceService:
    """Extracts explicit and implicit recommendation signals from user history and library."""

    def __init__(
        self,
        playlist_repo: PlaylistRepository,
        track_repo: TrackRepository,
    ):
        self.playlist_repo = playlist_repo
        self.track_repo = track_repo

    async def get_user_preferences(self, user: User) -> UserPreferences:
        """
        Analyzes user playlists and uploaded tracks to build a structured
        preference profile without exposing any PII.
        """
        genre_counter: Counter[str] = Counter()
        artist_counter: Counter[str] = Counter()
        excluded_ids: Set[uuid.UUID] = set()

        # 1. Inspect playlists (strong explicit preference signal)
        user_playlists = await self.playlist_repo.list_by_owner(user.id, skip=0, limit=50)
        for playlist in user_playlists:
            for pt in playlist.playlist_tracks or []:
                track = pt.track
                if track:
                    excluded_ids.add(track.id)
                    if track.genre and track.genre.strip():
                        genre_counter[track.genre.strip()] += 2
                    if track.artist_name and track.artist_name.strip():
                        artist_counter[track.artist_name.strip()] += 2

        # 2. Inspect user-owned tracks (creator style signal)
        user_tracks = await self.track_repo.list_by_owner(user.id, skip=0, limit=50)
        for track in user_tracks:
            excluded_ids.add(track.id)
            if track.genre and track.genre.strip():
                genre_counter[track.genre.strip()] += 1
            if track.artist_name and track.artist_name.strip():
                artist_counter[track.artist_name.strip()] += 1

        preferred_genres = [genre for genre, _ in genre_counter.most_common(10)]
        preferred_artists = [artist for artist, _ in artist_counter.most_common(10)]
        total_signals = sum(genre_counter.values()) + sum(artist_counter.values())

        return UserPreferences(
            preferred_genres=preferred_genres,
            preferred_artists=preferred_artists,
            excluded_track_ids=excluded_ids,
            total_signals=total_signals,
        )
