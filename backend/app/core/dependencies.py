import uuid
from typing import AsyncGenerator
from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import redis.asyncio as aioredis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AuthenticationError
from app.core.security import decode_token
from app.db.database import get_db
from app.db.models.user import User
from app.repositories.user_repository import UserRepository
from app.services.user_service import UserService

settings = get_settings()
security_scheme = HTTPBearer(auto_error=False)


async def get_redis_client() -> AsyncGenerator[aioredis.Redis, None]:
    """Provides async Redis client instance."""
    client = aioredis.from_url(
        settings.REDIS_URL,
        encoding="utf-8",
        decode_responses=True,
    )
    try:
        yield client
    finally:
        await client.aclose()


async def check_redis_health() -> bool:
    """Verifies in-memory Redis connectivity with PING."""
    try:
        client = aioredis.from_url(settings.REDIS_URL, socket_timeout=2.0)
        pong = await client.ping()
        await client.aclose()
        return bool(pong)
    except Exception:
        return False


def get_user_repository(session: AsyncSession = Depends(get_db)) -> UserRepository:
    return UserRepository(session)


def get_user_service(user_repo: UserRepository = Depends(get_user_repository)) -> UserService:
    return UserService(user_repo)


async def get_current_user(
    auth: HTTPAuthorizationCredentials = Depends(security_scheme),
    user_service: UserService = Depends(get_user_service),
) -> User:
    """Extracts and validates authenticated user from JWT Bearer token."""
    if not auth or not auth.credentials:
        raise AuthenticationError("Authorization bearer token is missing")

    try:
        payload = decode_token(auth.credentials)
        if payload.get("type") != "access":
            raise AuthenticationError("Invalid token type. Expected access token.")
        user_id_str = payload.get("sub")
        if not user_id_str:
            raise AuthenticationError("Malformed token claims")
        user_id = uuid.UUID(user_id_str)
    except Exception as exc:
        raise AuthenticationError(f"Invalid or expired token: {str(exc)}")

    return await user_service.get_user_by_id(user_id)
