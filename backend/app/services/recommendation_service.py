from collections import defaultdict
from datetime import datetime, timedelta, timezone
import logging
from typing import Dict, List, Optional
import uuid

from app.ai.gemini_recommendation_client import GeminiRecommendationClient
from app.core.config import get_settings
from app.db.models.audio import Track
from app.db.models.recommendation import RecommendationItem, RecommendationSet
from app.db.models.user import User
from app.repositories.audio_repository import TrackRepository
from app.repositories.playlist_repository import PlaylistRepository
from app.repositories.recommendation_repository import (
    RecommendationItemRepository,
    RecommendationSetRepository,
)
from app.schemas.recommendation import (
    RecommendationResponse,
    RecommendationSection,
    RecommendedTrackItem,
)
from app.services.recommendation.cache_service import RecommendationCacheService
from app.services.recommendation.candidate_service import CandidateGenerationService
from app.services.recommendation.diversity_service import DiversityService
from app.services.recommendation.ranking_service import RankingService
from app.services.recommendation.user_preference_service import UserPreferenceService

logger = logging.getLogger("hums.recommendation_service")
settings = get_settings()

SECTION_TITLES = {
    "for-you": ("Recommended for You", "Curated tracks based on your listening style"),
    "genre": ("Because You Like {genre}", "Explore more {genre} tracks"),
    "trending": ("Trending on Hums", "Most popular and added tracks across the community"),
    "discover": ("Discover Something New", "Fresh sounds from new releases and emerging creators"),
}


class RecommendationService:
    """Orchestrates candidate generation, ranking, Gemini enrichment, diversity, and caching."""

    def __init__(
        self,
        preference_service: UserPreferenceService,
        candidate_service: CandidateGenerationService,
        ranking_service: RankingService,
        diversity_service: DiversityService,
        gemini_client: GeminiRecommendationClient,
        cache_service: RecommendationCacheService,
        rec_set_repo: RecommendationSetRepository,
        rec_item_repo: RecommendationItemRepository,
        track_repo: TrackRepository,
    ):
        self.preference_service = preference_service
        self.candidate_service = candidate_service
        self.ranking_service = ranking_service
        self.diversity_service = diversity_service
        self.gemini_client = gemini_client
        self.cache_service = cache_service
        self.rec_set_repo = rec_set_repo
        self.rec_item_repo = rec_item_repo
        self.track_repo = track_repo

    def _to_recommended_item(self, track: Track) -> RecommendedTrackItem:
        """Transforms a Track DB model into a client-safe RecommendedTrackItem."""
        return RecommendedTrackItem(
            id=track.id,
            title=track.title,
            artist_name=track.artist_name,
            album_name=track.album_name,
            genre=track.genre,
            duration_seconds=track.duration_seconds,
            artwork_url=None,
            status=track.status,
            waveform_key=track.waveform_key,
        )

    def _to_response_from_db(
        self, rec_set: RecommendationSet, section_filter: Optional[str] = None
    ) -> RecommendationResponse:
        """Reconstructs RecommendationResponse from a persisted RecommendationSet."""
        items_by_section: Dict[str, List[RecommendationItem]] = defaultdict(list)
        for item in sorted(rec_set.items or [], key=lambda i: i.position):
            items_by_section[item.section].append(item)

        sections: List[RecommendationSection] = []
        for sec_id, items in items_by_section.items():
            if section_filter and sec_id != section_filter:
                continue
            title_tpl, desc_tpl = SECTION_TITLES.get(sec_id, (sec_id.capitalize(), None))
            track_items = [
                self._to_recommended_item(item.track)
                for item in items
                if item.track and item.track.status == "READY"
            ]
            sections.append(
                RecommendationSection(
                    id=sec_id,
                    title=title_tpl,
                    description=desc_tpl,
                    items=track_items,
                )
            )

        return RecommendationResponse(sections=sections)

    async def get_recommendations(
        self,
        user: User,
        limit: int = 10,
        section_filter: Optional[str] = None,
        refresh: bool = False,
    ) -> RecommendationResponse:
        """
        Retrieves personalized recommendation sections with multi-layer caching,
        concurrency locking, and deterministic fallback.
        """
        # 1. Cache HIT path
        if not refresh:
            cached_data = await self.cache_service.get_cached(user.id)
            if cached_data:
                logger.info(f"Cache hit for user {user.id} recommendations")
                resp = RecommendationResponse.model_validate(cached_data)
                if section_filter:
                    resp.sections = [s for s in resp.sections if s.id == section_filter]
                return resp

        # 2. Check debounce if refresh was requested
        if refresh:
            if await self.cache_service.is_debounced(user.id):
                logger.info(f"Refresh debounced for user {user.id}; serving active recommendations")
                active_set = await self.rec_set_repo.get_latest_active_by_user(user.id)
                if active_set and active_set.items:
                    return self._to_response_from_db(active_set, section_filter)

        # 3. Acquire generation lock to prevent duplicate concurrent runs
        acquired = await self.cache_service.acquire_generation_lock(user.id)
        if not acquired:
            logger.info(f"Generation already in progress for user {user.id}; serving active set")
            active_set = await self.rec_set_repo.get_latest_active_by_user(user.id)
            if active_set and active_set.items:
                return self._to_response_from_db(active_set, section_filter)

        try:
            # 4. Extract user preference signals
            preferences = await self.preference_service.get_user_preferences(user)

            # 5. Generate candidate tracks pool
            candidates = await self.candidate_service.generate_candidates(
                preferences, max_candidates=settings.RECOMMENDATION_MAX_CANDIDATES
            )

            # 6. Rank candidates deterministically
            deterministic_ranked = self.ranking_service.rank_candidates(candidates, preferences)

            # 7. Optional Gemini semantic re-ranking
            model_used = "deterministic"
            prompt_version_used = None
            final_ranked = None

            if self.gemini_client.is_available and not preferences.is_cold_start:
                ai_ranked = await self.gemini_client.rerank_candidates(deterministic_ranked, preferences)
                if ai_ranked:
                    final_ranked = ai_ranked
                    model_used = self.gemini_client.model
                    prompt_version_used = self.gemini_client.prompt_version

            if final_ranked is None:
                final_ranked = deterministic_ranked

            # 8. Diversity filtering for primary "for-you" recommendations
            for_you_tracks = self.diversity_service.apply_diversity(final_ranked, limit=limit)

            # 9. Assemble recommendation sections
            sections: List[RecommendationSection] = []

            # Section 1: "Recommended for You"
            for_you_items = [self._to_recommended_item(t) for t, _ in for_you_tracks]
            sections.append(
                RecommendationSection(
                    id="for-you",
                    title="Recommended for You",
                    description="Curated tracks based on your listening style",
                    items=for_you_items,
                )
            )

            # Section 2: "Because You Like {Genre}"
            top_genre = preferences.preferred_genres[0] if preferences.preferred_genres else None
            if top_genre:
                genre_candidates = [
                    t for t, _ in final_ranked
                    if t.genre and t.genre.lower() == top_genre.lower()
                    and t.id not in {item.id for item in for_you_items[:4]}
                ]
                if not genre_candidates:
                    genre_candidates = await self.track_repo.list_ready_by_genres(
                        [top_genre], limit=limit, exclude_ids=[item.id for item in for_you_items]
                    )
                if genre_candidates:
                    sections.append(
                        RecommendationSection(
                            id="genre",
                            title=f"Because You Like {top_genre}",
                            description=f"Explore more {top_genre} tracks",
                            items=[self._to_recommended_item(t) for t in genre_candidates[:limit]],
                        )
                    )

            # Section 3: "Trending on Hums"
            popular_tracks = await self.track_repo.list_popular_ready_tracks(
                limit=limit,
                exclude_ids=[item.id for item in for_you_items[:3]],
            )
            if popular_tracks:
                sections.append(
                    RecommendationSection(
                        id="trending",
                        title="Trending on Hums",
                        description="Most popular and added tracks across the community",
                        items=[self._to_recommended_item(t) for t in popular_tracks[:limit]],
                    )
                )

            # Section 4: "Discover Something New"
            discover_candidates = [
                t for t, _ in final_ranked
                if (not top_genre or (t.genre and t.genre.lower() != top_genre.lower()))
                and t.id not in {item.id for item in for_you_items}
            ]
            if not discover_candidates:
                discover_candidates = await self.track_repo.list_recent_ready_tracks(
                    limit=limit,
                    exclude_ids=[item.id for item in for_you_items],
                )
            if discover_candidates:
                sections.append(
                    RecommendationSection(
                        id="discover",
                        title="Discover Something New",
                        description="Fresh sounds from new releases and emerging creators",
                        items=[self._to_recommended_item(t) for t in discover_candidates[:limit]],
                    )
                )

            # 10. Persist to PostgreSQL
            now = datetime.now(timezone.utc)
            expires_at = now + timedelta(seconds=settings.RECOMMENDATION_CACHE_TTL_SECONDS)
            set_id = uuid.uuid4()

            await self.rec_set_repo.create(
                id=set_id,
                user_id=user.id,
                algorithm_version="v1-hybrid",
                model_name=model_used,
                prompt_version=prompt_version_used,
                expires_at=expires_at,
            )

            items_to_persist = []
            for sec in sections:
                for pos, track_item in enumerate(sec.items):
                    items_to_persist.append({
                        "id": uuid.uuid4(),
                        "recommendation_set_id": set_id,
                        "track_id": track_item.id,
                        "section": sec.id,
                        "position": pos,
                        "score": None,
                    })
            if items_to_persist:
                await self.rec_item_repo.create_items(items_to_persist)

            # 11. Cache payload in Redis and set debounce window
            response_payload = RecommendationResponse(sections=sections)
            await self.cache_service.set_cached(
                user.id,
                response_payload.model_dump(mode="json"),
                ttl_seconds=settings.RECOMMENDATION_CACHE_TTL_SECONDS,
            )
            await self.cache_service.set_debounce(user.id)

            if section_filter:
                return RecommendationResponse(
                    sections=[s for s in response_payload.sections if s.id == section_filter]
                )
            return response_payload

        finally:
            await self.cache_service.release_generation_lock(user.id)
