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
from app.repositories.audio_repository import (
    AudioFileRepository,
    ProcessingJobRepository,
    TrackRepository,
)
from app.repositories.user_repository import (
    PasswordResetTokenRepository,
    RefreshTokenRepository,
    UserRepository,
)
from app.services.audio_service import AudioService
from app.services.auth_service import AuthService
from app.services.profile_service import ProfileService
from app.services.user_service import UserService
from app.utils.storage import BaseStorageService, S3StorageService

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


def get_refresh_token_repository(session: AsyncSession = Depends(get_db)) -> RefreshTokenRepository:
    return RefreshTokenRepository(session)


def get_password_reset_token_repository(
    session: AsyncSession = Depends(get_db),
) -> PasswordResetTokenRepository:
    return PasswordResetTokenRepository(session)


def get_user_service(user_repo: UserRepository = Depends(get_user_repository)) -> UserService:
    return UserService(user_repo)


def get_auth_service(
    user_repo: UserRepository = Depends(get_user_repository),
    refresh_token_repo: RefreshTokenRepository = Depends(get_refresh_token_repository),
    password_reset_token_repo: PasswordResetTokenRepository = Depends(
        get_password_reset_token_repository
    ),
) -> AuthService:
    return AuthService(user_repo, refresh_token_repo, password_reset_token_repo)


def get_storage_service() -> BaseStorageService:
    return S3StorageService()


def get_profile_service(
    user_repo: UserRepository = Depends(get_user_repository),
    storage_service: BaseStorageService = Depends(get_storage_service),
) -> ProfileService:
    return ProfileService(user_repo, storage_service)


def get_track_repository(session: AsyncSession = Depends(get_db)) -> TrackRepository:
    return TrackRepository(session)


def get_audio_file_repository(session: AsyncSession = Depends(get_db)) -> AudioFileRepository:
    return AudioFileRepository(session)


def get_processing_job_repository(
    session: AsyncSession = Depends(get_db),
) -> ProcessingJobRepository:
    return ProcessingJobRepository(session)


def get_audio_service(
    track_repo: TrackRepository = Depends(get_track_repository),
    audio_file_repo: AudioFileRepository = Depends(get_audio_file_repository),
    processing_job_repo: ProcessingJobRepository = Depends(get_processing_job_repository),
    storage_service: BaseStorageService = Depends(get_storage_service),
) -> AudioService:
    return AudioService(track_repo, audio_file_repo, processing_job_repo, storage_service)


async def get_current_user(
    auth: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme),
    user_repo: UserRepository = Depends(get_user_repository),
) -> User:
    """Extracts, decodes, and validates authenticated user from JWT Bearer token."""
    if not auth or not auth.credentials:
        raise AuthenticationError(
            "Authorization bearer token is missing",
            code="UNAUTHORIZED",
        )

    try:
        payload = decode_token(auth.credentials)
        if payload.get("type") != "access":
            raise AuthenticationError(
                "Invalid token type. Expected access token.",
                code="UNAUTHORIZED",
            )
        user_id_str = payload.get("sub")
        if not user_id_str:
            raise AuthenticationError("Malformed token claims", code="UNAUTHORIZED")
        user_id = uuid.UUID(user_id_str)
    except AuthenticationError:
        raise
    except Exception as exc:
        raise AuthenticationError(
            f"Invalid or expired token: {str(exc)}",
            code="UNAUTHORIZED",
        )

    user = await user_repo.get_by_id(user_id)
    if not user:
        raise AuthenticationError("User not found", code="UNAUTHORIZED")

    if not user.is_active:
        raise AuthenticationError(
            "User account is inactive",
            code="ACCOUNT_INACTIVE",
            status_code=status.HTTP_403_FORBIDDEN,
        )

    return user
