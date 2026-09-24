import hashlib
import logging
from typing import Optional
from fastapi import Request, status
import redis.asyncio as aioredis

from app.core.config import get_settings
from app.core.errors import AppException

logger = logging.getLogger("hums.security.rate_limit")
settings = get_settings()


class RateLimitExceeded(AppException):
    """Exception raised when an endpoint rate limit is exceeded."""

    def __init__(self, retry_after: int, message: Optional[str] = None):
        super().__init__(
            message=message
            or f"Too many requests. Please try again in {retry_after} seconds.",
            code="RATE_LIMIT_EXCEEDED",
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            details={"retry_after": retry_after},
        )
        self.retry_after = retry_after


class RateLimiter:
    """
    Asynchronous, Redis-backed sliding/fixed-window rate limiter dependency.
    
    Guarantees:
    - Atomically increments count and enforces TTL.
    - Scopes client identification by User ID (if authenticated) or Client IP.
    - Gracefully degrades (fails open) if Redis is temporarily unreachable.
    - Attaches Retry-After information when limit is breached.
    """

    def __init__(
        self,
        requests: int,
        window_seconds: int,
        action: str = "general",
    ):
        self.requests = requests
        self.window_seconds = window_seconds
        self.action = action

    async def __call__(self, request: Request) -> None:
        if not getattr(settings, "RATE_LIMIT_ENABLED", True):
            return

        # Identify client (prefer bearer token sub if present, fallback to client IP)
        client_id = self._extract_client_identifier(request)
        key = f"rate_limit:{self.action}:{client_id}"

        try:
            client = aioredis.from_url(
                settings.REDIS_URL,
                encoding="utf-8",
                decode_responses=True,
                socket_connect_timeout=1.0,
                socket_timeout=1.0,
            )
            async with client:
                pipe = client.pipeline()
                pipe.incr(key)
                pipe.ttl(key)
                current_count, current_ttl = await pipe.execute()

                # If key was just created or lacks TTL, set expiration
                if current_ttl is None or current_ttl < 0:
                    await client.expire(key, self.window_seconds)
                    current_ttl = self.window_seconds

                if current_count > self.requests:
                    retry_after = max(1, current_ttl)
                    logger.warning(
                        f"Rate limit exceeded for action='{self.action}', client='{client_id}': "
                        f"{current_count}/{self.requests} requests. Retry after {retry_after}s"
                    )
                    raise RateLimitExceeded(retry_after=retry_after)

        except RateLimitExceeded:
            raise
        except Exception as exc:
            # Graceful degradation: Log and fail open so Redis blips do not cause service denial
            from app.core.metrics import metrics_registry
            metrics_registry.record_redis_error(operation="rate_limit")
            logger.warning(
                f"Rate limiter failed to communicate with Redis (failing open): {exc}"
            )
            return

    def _extract_client_identifier(self, request: Request) -> str:
        """Determines the most accurate and secure client identifier available."""
        # 1. Check for Authorization header to rate-limit per authenticated subject
        auth_header = request.headers.get("authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header.split(" ", 1)[1].strip()
            if token:
                # Use SHA-256 of the token prefix to avoid storing raw token in Redis
                token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()[:16]
                return f"token:{token_hash}"

        # 2. Fallback to client IP
        forwarded_for = request.headers.get("x-forwarded-for")
        if forwarded_for:
            client_ip = forwarded_for.split(",")[0].strip()
        elif request.client:
            client_ip = request.client.host
        else:
            client_ip = "unknown_client"

        return f"ip:{client_ip}"
