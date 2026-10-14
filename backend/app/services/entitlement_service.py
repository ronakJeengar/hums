import json
import uuid
from typing import List, Optional, Set
import redis.asyncio as aioredis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import ForbiddenError
from app.core.logging import get_logger
from app.core.metrics import metrics_registry
from app.repositories.subscription_repository import SubscriptionRepository
from app.schemas.subscription import UserEntitlementsResponse

logger = get_logger(__name__)


class EntitlementService:
    """
    Centralized authority for checking, resolving, and evaluating premium entitlements.
    
    Guarantees:
    - Authoritative server-side evaluation.
    - Automatic request-time expiry verification (UTC).
    - Fast in-memory caching via Redis with bounded TTL.
    - Explicit cache invalidation on subscription mutations.
    - Low-cardinality observability tracking for authorization denials.
    """

    def __init__(
        self,
        db_session: AsyncSession,
        redis_client: Optional[aioredis.Redis] = None,
    ):
        self.db_session = db_session
        self.redis = redis_client
        self.repo = SubscriptionRepository(db_session)
        self.settings = get_settings()

    def _cache_key(self, user_id: uuid.UUID) -> str:
        return f"entitlements:user:{str(user_id)}"

    async def get_user_entitlements(self, user_id: uuid.UUID) -> Set[str]:
        """
        Retrieves all active entitlement codes for the specified user.
        Checks Redis cache first; falls back to authoritative database query on miss.
        """
        cache_key = self._cache_key(user_id)

        # 1. Check Redis Cache
        if self.redis:
            try:
                cached = await self.redis.get(cache_key)
                if cached is not None:
                    metrics_registry.record_redis_hit("entitlements")
                    return set(json.loads(cached))
                metrics_registry.record_redis_miss("entitlements")
            except Exception as e:
                logger.warning(f"Redis error reading entitlements cache: {e}")

        # 2. Query Authoritative Database
        active_codes = await self.repo.get_active_entitlement_codes(user_id)

        # 3. Cache Result in Redis
        if self.redis:
            try:
                await self.redis.set(
                    cache_key,
                    json.dumps(list(active_codes)),
                    ex=self.settings.ENTITLEMENT_CACHE_TTL_SECONDS,
                )
            except Exception as e:
                logger.warning(f"Redis error setting entitlements cache: {e}")

        return active_codes

    async def has_entitlement(self, user_id: uuid.UUID, entitlement_code: str) -> bool:
        """Checks whether user currently holds a specific entitlement."""
        entitlements = await self.get_user_entitlements(user_id)
        return entitlement_code in entitlements

    async def require_entitlement(
        self,
        user_id: uuid.UUID,
        entitlement_code: str,
        error_message: Optional[str] = None,
    ) -> None:
        """
        Enforces that the user has the specified entitlement.
        Raises HTTP 403 Forbidden with ENTITLEMENT_REQUIRED error code if absent.
        """
        has_access = await self.has_entitlement(user_id, entitlement_code)
        if not has_access:
            metrics_registry.record_entitlement_denial(entitlement_code)
            logger.info(
                "Entitlement authorization denied",
                extra={"user_id": str(user_id), "entitlement": entitlement_code},
            )
            msg = error_message or f"Action requires the '{entitlement_code}' entitlement."
            raise ForbiddenError(msg, code="ENTITLEMENT_REQUIRED")

    async def is_premium(self, user_id: uuid.UUID) -> bool:
        """Evaluates whether the user is in an active premium tier."""
        entitlements = await self.get_user_entitlements(user_id)
        return len(entitlements) > 0

    async def get_user_tier(self, user_id: uuid.UUID) -> str:
        """Returns the user's primary commercial tier ('PREMIUM' or 'FREE')."""
        return "PREMIUM" if await self.is_premium(user_id) else "FREE"

    async def get_user_entitlements_summary(
        self, user_id: uuid.UUID
    ) -> UserEntitlementsResponse:
        """Constructs a consolidated entitlement summary for mobile clients."""
        active_sub = await self.repo.get_active_subscription(user_id)
        entitlements = await self.get_user_entitlements(user_id)
        is_prem = len(entitlements) > 0

        expires_at = None
        if active_sub:
            expires_at = (
                active_sub.grace_period_end
                if active_sub.status == "IN_GRACE_PERIOD" and active_sub.grace_period_end
                else active_sub.current_period_end
            )

        return UserEntitlementsResponse(
            entitlements=sorted(list(entitlements)),
            is_premium=is_prem,
            tier="PREMIUM" if is_prem else "FREE",
            expires_at=expires_at,
        )

    async def invalidate_user_entitlements(self, user_id: uuid.UUID) -> None:
        """Purges cached entitlements from Redis upon subscription lifecycle changes."""
        if self.redis:
            try:
                await self.redis.delete(self._cache_key(user_id))
            except Exception as e:
                logger.warning(f"Redis error invalidating entitlements cache: {e}")
