from typing import Dict, List, Protocol
import uuid

from app.db.models.audio import Track
from app.repositories.audio_repository import TrackRepository
from app.services.recommendation.user_preference_service import UserPreferences


class CandidateSource(Protocol):
    """Protocol for modular recommendation candidate sources."""

    async def get_candidates(
        self,
        preferences: UserPreferences,
        limit: int,
    ) -> List[Track]:
        ...


class GenreCandidateSource:
    """Retrieves ready tracks matching user preferred genres."""

    def __init__(self, track_repo: TrackRepository):
        self.track_repo = track_repo

    async def get_candidates(
        self, preferences: UserPreferences, limit: int = 20
    ) -> List[Track]:
        if not preferences.preferred_genres:
            return []
        return await self.track_repo.list_ready_by_genres(
            genres=preferences.preferred_genres,
            limit=limit,
            exclude_ids=list(preferences.excluded_track_ids),
        )


class ArtistCandidateSource:
    """Retrieves ready tracks matching user preferred artists."""

    def __init__(self, track_repo: TrackRepository):
        self.track_repo = track_repo

    async def get_candidates(
        self, preferences: UserPreferences, limit: int = 20
    ) -> List[Track]:
        if not preferences.preferred_artists:
            return []
        return await self.track_repo.list_ready_by_artists(
            artists=preferences.preferred_artists,
            limit=limit,
            exclude_ids=list(preferences.excluded_track_ids),
        )


class PopularCandidateSource:
    """Retrieves platform-wide trending and popular ready tracks."""

    def __init__(self, track_repo: TrackRepository):
        self.track_repo = track_repo

    async def get_candidates(
        self, preferences: UserPreferences, limit: int = 20
    ) -> List[Track]:
        return await self.track_repo.list_popular_ready_tracks(
            limit=limit,
            exclude_ids=list(preferences.excluded_track_ids),
        )


class RecentCandidateSource:
    """Retrieves fresh, newly released ready tracks for discovery."""

    def __init__(self, track_repo: TrackRepository):
        self.track_repo = track_repo

    async def get_candidates(
        self, preferences: UserPreferences, limit: int = 20
    ) -> List[Track]:
        return await self.track_repo.list_recent_ready_tracks(
            limit=limit,
            exclude_ids=list(preferences.excluded_track_ids),
        )


class CandidateGenerationService:
    """Aggregates candidates across multiple sources, ensuring deduplication and quality."""

    def __init__(self, track_repo: TrackRepository):
        self.track_repo = track_repo
        self.genre_source = GenreCandidateSource(track_repo)
        self.artist_source = ArtistCandidateSource(track_repo)
        self.popular_source = PopularCandidateSource(track_repo)
        self.recent_source = RecentCandidateSource(track_repo)

    async def generate_candidates(
        self,
        preferences: UserPreferences,
        max_candidates: int = 50,
    ) -> List[Track]:
        """
        Executes candidate sources and returns a deduplicated pool of READY tracks.
        """
        candidate_map: Dict[uuid.UUID, Track] = {}

        # 1. Fetch preference-based candidates if available
        if not preferences.is_cold_start:
            genre_tracks = await self.genre_source.get_candidates(preferences, limit=25)
            for t in genre_tracks:
                if t.status == "READY":
                    candidate_map[t.id] = t

            artist_tracks = await self.artist_source.get_candidates(preferences, limit=20)
            for t in artist_tracks:
                if t.status == "READY":
                    candidate_map[t.id] = t

        # 2. Fetch popular and recent candidates for discovery and freshness
        popular_tracks = await self.popular_source.get_candidates(preferences, limit=25)
        for t in popular_tracks:
            if t.status == "READY":
                candidate_map[t.id] = t

        recent_tracks = await self.recent_source.get_candidates(preferences, limit=20)
        for t in recent_tracks:
            if t.status == "READY":
                candidate_map[t.id] = t

        # 3. If still short on candidates, fetch additional general ready tracks
        if len(candidate_map) < max_candidates:
            fallback_tracks = await self.track_repo.list_ready_tracks(
                skip=0,
                limit=max_candidates - len(candidate_map),
                exclude_ids=list(preferences.excluded_track_ids) + list(candidate_map.keys()),
            )
            for t in fallback_tracks:
                if t.status == "READY":
                    candidate_map[t.id] = t

        return list(candidate_map.values())[:max_candidates]
