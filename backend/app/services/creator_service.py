import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Any, List, Optional, Tuple

import redis.asyncio as aioredis

from app.core.config import get_settings
from app.core.errors import BadRequestError, NotFoundError
from app.db.models.creator import Creator
from app.db.models.user import User
from app.repositories.creator_repository import CreatorRepository
from app.schemas.audio import TrackResponse
from app.schemas.creator import (
    CreatorDetailResponse,
    CreatorPublicProfile,
    FollowStatusResponse,
    FollowerUserItem,
    FollowersListResponse,
    FollowingListResponse,
)
from app.schemas.playlist import PlaylistResponse
from app.schemas.search import SearchAlbumItem
from app.utils.storage import BaseStorageService

logger = logging.getLogger("hums.creator_service")
settings = get_settings()

CACHE_TTL_FOLLOW_STATUS = 300  # 5 minutes
CACHE_TTL_PROFILE = 120  # 2 minutes


class CreatorService:
    """
    Service orchestrating public creator profiles, follow/unfollow operations,
    caching with atomic invalidation, and content aggregation.
    """

    def __init__(
        self,
        creator_repository: CreatorRepository,
        redis_client: Optional[aioredis.Redis] = None,
        storage_service: Optional[BaseStorageService] = None,
    ):
        self.creator_repo = creator_repository
        self.redis = redis_client
        self.storage = storage_service

    def _follow_key(self, user_id: uuid.UUID, creator_id: uuid.UUID) -> str:
        return f"hums:user:{user_id}:following:{creator_id}"

    def _followers_count_key(self, creator_id: uuid.UUID) -> str:
        return f"hums:creator:{creator_id}:followers_count"

    def _profile_cache_key(self, creator_id: uuid.UUID) -> str:
        return f"hums:creator:{creator_id}:profile_summary"

    async def get_creator_by_id(
        self,
        creator_id: uuid.UUID,
        current_user_id: Optional[uuid.UUID] = None,
    ) -> CreatorDetailResponse:
        """
        Retrieves a comprehensive public creator profile and content aggregates.
        Guarantees zero exposure of private account information.
        """
        creator = await self.creator_repo.get_by_id(creator_id)
        if not creator:
            raise NotFoundError("Creator not found")

        # Determine follow status
        is_following = False
        if current_user_id:
            is_following = await self.check_is_following(current_user_id, creator_id)

        # Content aggregates
        popular_tracks_raw = await self.creator_repo.get_creator_tracks(creator, limit=10, popular=True)
        latest_tracks_raw = await self.creator_repo.get_creator_tracks(creator, limit=10, popular=False)
        albums_raw = await self.creator_repo.get_creator_albums(creator.name)
        playlists_raw = await self.creator_repo.get_creator_playlists(creator.user_id)

        popular_tracks = [TrackResponse.model_validate(t) for t in popular_tracks_raw]
        latest_tracks = [TrackResponse.model_validate(t) for t in latest_tracks_raw]
        albums = [SearchAlbumItem.model_validate(a) for a in albums_raw]
        playlists = [PlaylistResponse.model_validate(p) for p in playlists_raw]

        return CreatorDetailResponse(
            id=creator.id,
            name=creator.name,
            username=creator.username,
            bio=creator.bio,
            avatar_url=creator.avatar_url,
            cover_image_url=creator.cover_image_url,
            is_verified=creator.is_verified,
            followers_count=creator.followers_count,
            is_following=is_following if current_user_id else None,
            popular_tracks=popular_tracks,
            latest_tracks=latest_tracks,
            albums=albums,
            public_playlists=playlists,
            created_at=creator.created_at,
        )

    async def check_is_following(self, user_id: uuid.UUID, creator_id: uuid.UUID) -> bool:
        """Checks follow status with Redis caching."""
        cache_key = self._follow_key(user_id, creator_id)
        if self.redis:
            try:
                cached = await self.redis.get(cache_key)
                if cached is not None:
                    return cached == "1"
            except Exception as e:
                logger.warning(f"Redis get failed for follow status: {e}")

        is_following = await self.creator_repo.is_following(user_id, creator_id)

        if self.redis:
            try:
                await self.redis.set(cache_key, "1" if is_following else "0", ex=CACHE_TTL_FOLLOW_STATUS)
            except Exception as e:
                logger.warning(f"Redis set failed for follow status: {e}")

        return is_following

    async def get_follow_status(
        self,
        creator_id: uuid.UUID,
        current_user_id: Optional[uuid.UUID] = None,
    ) -> FollowStatusResponse:
        """Returns follow status and follower count for a creator."""
        creator = await self.creator_repo.get_by_id(creator_id)
        if not creator:
            raise NotFoundError("Creator not found")

        is_following = False
        if current_user_id:
            is_following = await self.check_is_following(current_user_id, creator_id)

        return FollowStatusResponse(
            creator_id=creator.id,
            is_following=is_following,
            followers_count=creator.followers_count,
        )

    async def follow(
        self,
        user_id: uuid.UUID,
        creator_id: uuid.UUID,
    ) -> FollowStatusResponse:
        """
        Follows a creator atomically and updates Redis caches.
        Prevents self-following if creator is the user.
        """
        creator = await self.creator_repo.get_by_id(creator_id)
        if not creator:
            raise NotFoundError("Creator not found")

        if creator.user_id and creator.user_id == user_id:
            raise BadRequestError("You cannot follow your own creator profile", code="SELF_FOLLOW_FORBIDDEN")

        was_newly_followed, count = await self.creator_repo.follow_creator(user_id, creator_id)

        # Invalidate / update Redis cache
        if self.redis:
            try:
                cache_key = self._follow_key(user_id, creator_id)
                await self.redis.set(cache_key, "1", ex=CACHE_TTL_FOLLOW_STATUS)
                await self.redis.set(self._followers_count_key(creator_id), str(count), ex=CACHE_TTL_FOLLOW_STATUS)
                await self.redis.delete(self._profile_cache_key(creator_id))
            except Exception as e:
                logger.warning(f"Redis cache update failed during follow: {e}")

        return FollowStatusResponse(
            creator_id=creator_id,
            is_following=True,
            followers_count=count,
        )

    async def unfollow(
        self,
        user_id: uuid.UUID,
        creator_id: uuid.UUID,
    ) -> FollowStatusResponse:
        """
        Unfollows a creator atomically and invalidates Redis caches.
        """
        creator = await self.creator_repo.get_by_id(creator_id)
        if not creator:
            raise NotFoundError("Creator not found")

        was_unfollowed, count = await self.creator_repo.unfollow_creator(user_id, creator_id)

        # Invalidate / update Redis cache
        if self.redis:
            try:
                cache_key = self._follow_key(user_id, creator_id)
                await self.redis.set(cache_key, "0", ex=CACHE_TTL_FOLLOW_STATUS)
                await self.redis.set(self._followers_count_key(creator_id), str(count), ex=CACHE_TTL_FOLLOW_STATUS)
                await self.redis.delete(self._profile_cache_key(creator_id))
            except Exception as e:
                logger.warning(f"Redis cache update failed during unfollow: {e}")

        return FollowStatusResponse(
            creator_id=creator_id,
            is_following=False,
            followers_count=count,
        )

    async def get_followers(
        self,
        creator_id: uuid.UUID,
        page: int = 1,
        size: int = 20,
    ) -> FollowersListResponse:
        """
        Retrieves paginated followers of a creator with public user attributes.
        """
        creator = await self.creator_repo.get_by_id(creator_id)
        if not creator:
            raise NotFoundError("Creator not found")

        page = max(1, page)
        size = max(1, min(size, 100))

        rows, total = await self.creator_repo.get_followers(creator_id, page=page, size=size)
        items: List[FollowerUserItem] = []
        for user, followed_at in rows:
            items.append(
                FollowerUserItem(
                    id=user.id,
                    name=user.name or user.username or "User",
                    username=user.username,
                    avatar_url=user.avatar_url,
                    followed_at=followed_at,
                )
            )

        has_more = (page * size) < total
        return FollowersListResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            has_more=has_more,
        )

    async def get_following(
        self,
        user_id: uuid.UUID,
        page: int = 1,
        size: int = 20,
    ) -> FollowingListResponse:
        """
        Retrieves paginated list of creators followed by the user.
        """
        page = max(1, page)
        size = max(1, min(size, 100))

        creators, total = await self.creator_repo.get_following(user_id, page=page, size=size)
        items: List[CreatorPublicProfile] = []
        for creator in creators:
            track_count = await self.creator_repo.get_creator_track_count(creator)
            items.append(
                CreatorPublicProfile(
                    id=creator.id,
                    name=creator.name,
                    username=creator.username,
                    bio=creator.bio,
                    avatar_url=creator.avatar_url,
                    cover_image_url=creator.cover_image_url,
                    is_verified=creator.is_verified,
                    followers_count=creator.followers_count,
                    is_following=True,
                    track_count=track_count,
                    created_at=creator.created_at,
                )
            )

        has_more = (page * size) < total
        return FollowingListResponse(
            items=items,
            total=total,
            page=page,
            size=size,
            has_more=has_more,
        )

    async def list_creators(
        self,
        skip: int = 0,
        limit: int = 20,
        current_user_id: Optional[uuid.UUID] = None,
    ) -> Tuple[List[CreatorPublicProfile], int]:
        """Lists popular creators with optional follow status for the current user."""
        limit = max(1, min(limit, 50))
        skip = max(0, skip)

        creators, total = await self.creator_repo.list_creators(skip=skip, limit=limit)
        creator_ids = [c.id for c in creators]

        following_map = {}
        if current_user_id and creator_ids:
            following_map = await self.creator_repo.is_following_batch(current_user_id, creator_ids)

        items: List[CreatorPublicProfile] = []
        for c in creators:
            is_f = following_map.get(c.id, False) if current_user_id else None
            items.append(
                CreatorPublicProfile(
                    id=c.id,
                    name=c.name,
                    username=c.username,
                    bio=c.bio,
                    avatar_url=c.avatar_url,
                    cover_image_url=c.cover_image_url,
                    is_verified=c.is_verified,
                    followers_count=c.followers_count,
                    is_following=is_f,
                    track_count=0,
                    created_at=c.created_at,
                )
            )

        return items, total
