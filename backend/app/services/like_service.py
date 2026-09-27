import json
import logging
import uuid
from typing import Optional
from redis.asyncio import Redis

from app.repositories.creator_repository import CreatorRepository
from app.repositories.like_repository import LikeRepository
from app.repositories.playlist_repository import PlaylistRepository
from app.schemas.library import LibrarySummaryResponse
from app.schemas.like import LikeStatusResponse, LikedTracksListResponse

logger = logging.getLogger(__name__)

STATUS_CACHE_TTL = 3600  # 1 hour
SUMMARY_CACHE_TTL = 300  # 5 minutes


class LikeService:
    """Service orchestrating track likes, personal library aggregation, and caching."""

    def __init__(
        self,
        like_repo: LikeRepository,
        redis_client: Optional[Redis] = None,
        playlist_repo: Optional[PlaylistRepository] = None,
        creator_repo: Optional[CreatorRepository] = None,
    ):
        self.like_repo = like_repo
        self.redis = redis_client
        self.playlist_repo = playlist_repo
        self.creator_repo = creator_repo

    async def like_track(
        self, user_id: uuid.UUID, track_id: uuid.UUID
    ) -> LikeStatusResponse:
        """Likes a track, invalidates related caches, and returns authoritative status."""
        is_liked, count = await self.like_repo.like_track(user_id, track_id)

        # Invalidate Redis caches
        if self.redis:
            try:
                await self.redis.delete(
                    f"like:status:{user_id}:{track_id}",
                    f"like:count:{track_id}",
                    f"library:summary:{user_id}",
                )
            except Exception as e:
                logger.warning("Failed to invalidate Redis cache on like_track: %s", e)

        return LikeStatusResponse(
            track_id=track_id,
            is_liked=is_liked,
            likes_count=count,
        )

    async def unlike_track(
        self, user_id: uuid.UUID, track_id: uuid.UUID
    ) -> LikeStatusResponse:
        """Unlikes a track, invalidates related caches, and returns authoritative status."""
        is_liked, count = await self.like_repo.unlike_track(user_id, track_id)

        # Invalidate Redis caches
        if self.redis:
            try:
                await self.redis.delete(
                    f"like:status:{user_id}:{track_id}",
                    f"like:count:{track_id}",
                    f"library:summary:{user_id}",
                )
            except Exception as e:
                logger.warning("Failed to invalidate Redis cache on unlike_track: %s", e)

        return LikeStatusResponse(
            track_id=track_id,
            is_liked=is_liked,
            likes_count=count,
        )

    async def get_like_status(
        self, user_id: Optional[uuid.UUID], track_id: uuid.UUID
    ) -> LikeStatusResponse:
        """Retrieves like status and count, utilizing Redis cache when available."""
        if user_id and self.redis:
            cache_key = f"like:status:{user_id}:{track_id}"
            try:
                cached = await self.redis.get(cache_key)
                if cached:
                    data = json.loads(cached)
                    return LikeStatusResponse.model_validate(data)
            except Exception as e:
                logger.debug("Redis cache miss or error on get_like_status: %s", e)

        is_liked, count = await self.like_repo.get_like_status(user_id, track_id)
        response = LikeStatusResponse(
            track_id=track_id,
            is_liked=is_liked,
            likes_count=count,
        )

        if user_id and self.redis:
            cache_key = f"like:status:{user_id}:{track_id}"
            try:
                await self.redis.set(
                    cache_key,
                    response.model_dump_json(),
                    ex=STATUS_CACHE_TTL,
                )
            except Exception as e:
                logger.warning("Failed to cache like status in Redis: %s", e)

        return response

    async def get_liked_tracks(
        self, user_id: uuid.UUID, page: int = 1, size: int = 20
    ) -> LikedTracksListResponse:
        """Retrieves paginated list of user's liked tracks."""
        items, total = await self.like_repo.get_liked_tracks(
            user_id, page=page, size=size
        )
        has_next = (page * size) < total
        return LikedTracksListResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            has_next=has_next,
        )

    async def get_library_summary(self, user_id: uuid.UUID) -> LibrarySummaryResponse:
        """
        Retrieves high-level personal library counts and recent liked tracks preview.
        Cached in Redis with user-isolated key (TTL 300s).
        """
        cache_key = f"library:summary:{user_id}"
        if self.redis:
            try:
                cached = await self.redis.get(cache_key)
                if cached:
                    return LibrarySummaryResponse.model_validate_json(cached)
            except Exception as e:
                logger.debug("Redis cache miss for library summary: %s", e)

        liked_count = await self.like_repo.count_user_likes(user_id)

        playlists_count = 0
        if self.playlist_repo:
            user_playlists = await self.playlist_repo.list_by_owner(user_id, skip=0, limit=1000)
            playlists_count = len(user_playlists)

        following_count = 0
        if self.creator_repo:
            _, following_count = await self.creator_repo.get_following(user_id, page=1, size=1)

        recent_liked, _ = await self.like_repo.get_liked_tracks(user_id, page=1, size=5)

        summary = LibrarySummaryResponse(
            liked_tracks_count=liked_count,
            playlists_count=playlists_count,
            following_creators_count=following_count,
            recent_liked_tracks=recent_liked,
        )

        if self.redis:
            try:
                await self.redis.set(
                    cache_key,
                    summary.model_dump_json(),
                    ex=SUMMARY_CACHE_TTL,
                )
            except Exception as e:
                logger.warning("Failed to cache library summary in Redis: %s", e)

        return summary
