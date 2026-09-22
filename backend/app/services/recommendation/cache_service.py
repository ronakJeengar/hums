import json
import logging
from typing import Any, Dict, Optional
import uuid
import redis.asyncio as aioredis
from app.core.config import get_settings

logger = logging.getLogger("hums.recommendation.cache")
settings = get_settings()


class RecommendationCacheService:
    """Manages Redis caching, debouncing, and concurrency locks for recommendations."""

    def __init__(self, redis_client: Optional[aioredis.Redis] = None):
        self.redis = redis_client

    def _cache_key(self, user_id: uuid.UUID) -> str:
        return f"rec:user:{user_id}"

    def _debounce_key(self, user_id: uuid.UUID) -> str:
        return f"rec:debounce:{user_id}"

    def _lock_key(self, user_id: uuid.UUID) -> str:
        return f"rec:lock:{user_id}"

    async def get_cached(self, user_id: uuid.UUID) -> Optional[Dict[str, Any]]:
        """Retrieves cached recommendation payload from Redis if present."""
        if not self.redis:
            return None
        try:
            raw = await self.redis.get(self._cache_key(user_id))
            if raw:
                return json.loads(raw)
        except Exception as exc:
            logger.warning(f"Redis get failed for user {user_id}: {exc}")
        return None

    async def set_cached(
        self,
        user_id: uuid.UUID,
        data: Dict[str, Any],
        ttl_seconds: Optional[int] = None,
    ) -> bool:
        """Stores recommendation payload in Redis with configurable TTL."""
        if not self.redis:
            return False
        ttl = ttl_seconds or settings.RECOMMENDATION_CACHE_TTL_SECONDS
        try:
            await self.redis.set(
                self._cache_key(user_id),
                json.dumps(data),
                ex=ttl,
            )
            return True
        except Exception as exc:
            logger.warning(f"Redis set failed for user {user_id}: {exc}")
            return False

    async def invalidate(self, user_id: uuid.UUID) -> bool:
        """Invalidates cached recommendations for a user."""
        if not self.redis:
            return False
        try:
            await self.redis.delete(self._cache_key(user_id))
            return True
        except Exception as exc:
            logger.warning(f"Redis delete failed for user {user_id}: {exc}")
            return False

    async def is_debounced(self, user_id: uuid.UUID) -> bool:
        """Checks if a user recommendation refresh was triggered recently."""
        if not self.redis:
            return False
        try:
            exists = await self.redis.exists(self._debounce_key(user_id))
            return bool(exists)
        except Exception as exc:
            logger.warning(f"Redis debounce check failed for user {user_id}: {exc}")
            return False

    async def set_debounce(self, user_id: uuid.UUID, seconds: Optional[int] = None) -> None:
        """Sets a debounce cooldown window to prevent refresh storms."""
        if not self.redis:
            return
        ttl = seconds or settings.RECOMMENDATION_REFRESH_DEBOUNCE_SECONDS
        try:
            await self.redis.set(self._debounce_key(user_id), "1", ex=ttl)
        except Exception as exc:
            logger.warning(f"Redis set debounce failed for user {user_id}: {exc}")

    async def acquire_generation_lock(self, user_id: uuid.UUID, lock_ttl: int = 15) -> bool:
        """
        Attempts to acquire an atomic Redis lock for recommendation generation
        to coalesce multiple concurrent requests for the same user.
        """
        if not self.redis:
            return True
        try:
            acquired = await self.redis.set(
                self._lock_key(user_id),
                "1",
                nx=True,
                ex=lock_ttl,
            )
            return bool(acquired)
        except Exception as exc:
            logger.warning(f"Redis lock acquisition failed for user {user_id}: {exc}")
            return True

    async def release_generation_lock(self, user_id: uuid.UUID) -> None:
        """Releases the recommendation generation lock."""
        if not self.redis:
            return
        try:
            await self.redis.delete(self._lock_key(user_id))
        except Exception as exc:
            logger.warning(f"Redis lock release failed: {exc}")
