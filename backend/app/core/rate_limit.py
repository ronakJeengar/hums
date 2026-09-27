import hashlib
import logging

import redis.asyncio as aioredis
from fastapi import Request, status

from app.core.config import get_settings
from app.core.errors import AppException

logger = logging.getLogger("hums.security.rate_limit")
settings = get_settings()


class RateLimitExceeded(AppException):
    """Exception raised when an endpoint rate limit is exceeded."""

    def __init__(self, retry_after: int, message: str | None = None):
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
    - Scopes client identification by Bearer token (if present) or Client IP.
    - Gracefully degrades (fails open) if Redis is temporarily unreachable.
    - Returns 429 Too Many Requests when limit is breached.
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
        except Exception as exc:  # noqa: BLE001
            # Graceful degradation: Log and fail open so Redis blips do not cause service denial
            logger.warning(
                f"Rate limiter failed to communicate with Redis (failing open): {exc}"
            )
            return

    def _extract_client_identifier(self, request: Request) -> str:
        """Determines the client identifier based on Auth header or IP."""
        auth_header = request.headers.get("authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header.split(" ", 1)[1].strip()
            if token:
                token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()[:16]
                return f"token:{token_hash}"

        forwarded_for = request.headers.get("x-forwarded-for")
        if forwarded_for:
            client_ip = forwarded_for.split(",")[0].strip()
        elif request.client:
            client_ip = request.client.host
        else:
            client_ip = "unknown_client"

        return f"ip:{client_ip}"
