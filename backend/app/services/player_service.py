import logging
from typing import Dict, List, Optional, Set
import uuid

from app.db.models.audio import Track
from app.db.models.user import User
from app.repositories.audio_repository import TrackRepository
from app.repositories.playback_repository import PlaybackRepository
from app.schemas.queue import TrackResolveResponse, UpNextResponse, UpNextTrackItem
from app.services.recommendation.candidate_service import CandidateGenerationService
from app.services.recommendation.user_preference_service import UserPreferenceService

logger = logging.getLogger("hums.player_service")


class PlayerService:
    """Orchestrates smart queue recommendations, track resolution, and playback continuity."""

    def __init__(
        self,
        track_repo: TrackRepository,
        preference_service: UserPreferenceService,
        candidate_service: CandidateGenerationService,
        playback_repo: PlaybackRepository,
    ):
        self.track_repo = track_repo
        self.preference_service = preference_service
        self.candidate_service = candidate_service
        self.playback_repo = playback_repo

    def _to_up_next_item(self, track: Track, source: str = "smart_queue") -> UpNextTrackItem:
        return UpNextTrackItem(
            id=track.id,
            title=track.title,
            artist_name=track.artist_name,
            album_name=track.album_name,
            genre=track.genre,
            duration_seconds=track.duration_seconds,
            artwork_url=None,
            status=track.status,
            waveform_key=track.waveform_key,
            source=source,
        )

    async def get_up_next(
        self,
        user: Optional[User],
        current_track_id: Optional[uuid.UUID] = None,
        limit: int = 10,
        exclude_ids: Optional[List[uuid.UUID]] = None,
    ) -> UpNextResponse:
        """Generates dynamic smart up-next queue recommendations to prevent playback silence.

        Considers:
        1. Current track's genre and artist (for seamless musical continuity)
        2. User's taste profile and preferences (if authenticated)
        3. Exclusion of current track, explicit exclude IDs, and recent listening history (to prevent immediate repeats)
        4. Freshness and popularity backfills
        Strictly ensures only READY tracks are returned.
        """
        clamped_limit = min(max(1, limit), 50)
        exclusions: Set[uuid.UUID] = set(exclude_ids or [])

        current_track: Optional[Track] = None
        if current_track_id:
            exclusions.add(current_track_id)
            current_track = await self.track_repo.get_by_id(current_track_id)

        # Exclude recent listening history (last 20 tracks) to avoid repeat fatigue
        if user:
            try:
                recent_history, _ = await self.playback_repo.get_history(user.id, skip=0, limit=20)
                for item in recent_history:
                    exclusions.add(item.track_id)
            except Exception as e:
                logger.warning(f"Failed to fetch recent history for user {user.id}: {e}")

        # Gather preference signals if user is authenticated
        preferences = None
        if user:
            try:
                preferences = await self.preference_service.get_user_preferences(user)
                # Combine user exclusions
                exclusions.update(preferences.excluded_track_ids)
            except Exception as e:
                logger.warning(f"Failed to load preferences for user {user.id}: {e}")

        candidates_map: Dict[uuid.UUID, UpNextTrackItem] = {}
        context = "discovery"

        # 1. Primary Seed: Continuity with Current Track
        if current_track and current_track.status == "READY":
            context = f"similar_to_{current_track.title[:20]}"
            # Genre match from current track
            if current_track.genre:
                genre_tracks = await self.track_repo.list_ready_by_genres(
                    [current_track.genre],
                    limit=clamped_limit,
                    exclude_ids=list(exclusions) + list(candidates_map.keys()),
                )
                for t in genre_tracks:
                    if t.status == "READY" and t.id not in candidates_map:
                        candidates_map[t.id] = self._to_up_next_item(t, source="genre_match")
                        if len(candidates_map) >= clamped_limit:
                            break

            # Artist match from current track
            if len(candidates_map) < clamped_limit and current_track.artist_name:
                artist_tracks = await self.track_repo.list_ready_by_artists(
                    [current_track.artist_name],
                    limit=clamped_limit // 2 + 1,
                    exclude_ids=list(exclusions) + list(candidates_map.keys()),
                )
                for t in artist_tracks:
                    if t.status == "READY" and t.id not in candidates_map:
                        candidates_map[t.id] = self._to_up_next_item(t, source="artist_match")
                        if len(candidates_map) >= clamped_limit:
                            break

        # 2. Secondary Seed: User Preference Affinity
        if len(candidates_map) < clamped_limit and preferences and not preferences.is_cold_start:
            context = "personalized"
            pref_candidates = await self.candidate_service.generate_candidates(
                preferences, max_candidates=clamped_limit
            )
            for t in pref_candidates:
                if t.status == "READY" and t.id not in exclusions and t.id not in candidates_map:
                    candidates_map[t.id] = self._to_up_next_item(t, source="personalized")
                    if len(candidates_map) >= clamped_limit:
                        break

        # 3. Tertiary Seed: Platform Trending & Popular Tracks
        if len(candidates_map) < clamped_limit:
            if context == "discovery":
                context = "trending"
            popular_tracks = await self.track_repo.list_popular_ready_tracks(
                limit=clamped_limit,
                exclude_ids=list(exclusions) + list(candidates_map.keys()),
            )
            for t in popular_tracks:
                if t.status == "READY" and t.id not in candidates_map:
                    candidates_map[t.id] = self._to_up_next_item(t, source="trending")
                    if len(candidates_map) >= clamped_limit:
                        break

        # 4. Fallback Seed: Recent Ready Releases
        if len(candidates_map) < clamped_limit:
            recent_tracks = await self.track_repo.list_recent_ready_tracks(
                limit=clamped_limit,
                exclude_ids=list(exclusions) + list(candidates_map.keys()),
            )
            for t in recent_tracks:
                if t.status == "READY" and t.id not in candidates_map:
                    candidates_map[t.id] = self._to_up_next_item(t, source="fresh_discovery")
                    if len(candidates_map) >= clamped_limit:
                        break

        # 5. Ultimate Fallback: Any ready tracks
        if len(candidates_map) < clamped_limit:
            fallback = await self.track_repo.list_ready_tracks(
                skip=0,
                limit=clamped_limit,
                exclude_ids=list(exclusions) + list(candidates_map.keys()),
            )
            for t in fallback:
                if t.status == "READY" and t.id not in candidates_map:
                    candidates_map[t.id] = self._to_up_next_item(t, source="smart_queue")
                    if len(candidates_map) >= clamped_limit:
                        break

        items = list(candidates_map.values())[:clamped_limit]
        return UpNextResponse(
            items=items,
            total=len(items),
            context=context,
        )

    async def resolve_tracks(self, track_ids: List[uuid.UUID]) -> TrackResolveResponse:
        """Resolves metadata for a batch of track UUIDs, ensuring tracks are playable."""
        if not track_ids:
            return TrackResolveResponse(items=[])

        # Bounded resolution (max 100)
        bounded_ids = track_ids[:100]
        resolved_items: List[UpNextTrackItem] = []

        for tid in bounded_ids:
            track = await self.track_repo.get_by_id(tid)
            if track and track.status == "READY":
                resolved_items.append(self._to_up_next_item(track, source="resolved"))

        return TrackResolveResponse(items=resolved_items)
