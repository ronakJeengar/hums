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
from app.repositories.playlist_repository import PlaylistRepository
from app.repositories.recommendation_repository import (
    RecommendationItemRepository,
    RecommendationSetRepository,
)
from app.repositories.user_repository import (
    PasswordResetTokenRepository,
    RefreshTokenRepository,
    UserRepository,
)
from app.ai.gemini_recommendation_client import GeminiRecommendationClient
from app.services.audio_service import AudioService
from app.services.auth_service import AuthService
from app.services.playlist_service import PlaylistService
from app.services.profile_service import ProfileService
from app.services.recommendation.cache_service import RecommendationCacheService
from app.services.recommendation.candidate_service import CandidateGenerationService
from app.services.recommendation.diversity_service import DiversityService
from app.services.recommendation.ranking_service import RankingService
from app.services.recommendation.user_preference_service import UserPreferenceService
from app.services.recommendation_service import RecommendationService
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


def get_playlist_repository(
    session: AsyncSession = Depends(get_db),
) -> PlaylistRepository:
    return PlaylistRepository(session)


def get_playlist_service(
    playlist_repo: PlaylistRepository = Depends(get_playlist_repository),
    track_repo: TrackRepository = Depends(get_track_repository),
    storage_service: BaseStorageService = Depends(get_storage_service),
) -> PlaylistService:
    return PlaylistService(playlist_repo, track_repo, storage_service)


def get_recommendation_set_repository(
    session: AsyncSession = Depends(get_db),
) -> RecommendationSetRepository:
    return RecommendationSetRepository(session)


def get_recommendation_item_repository(
    session: AsyncSession = Depends(get_db),
) -> RecommendationItemRepository:
    return RecommendationItemRepository(session)


def get_gemini_recommendation_client() -> GeminiRecommendationClient:
    return GeminiRecommendationClient()


async def get_recommendation_cache_service(
    redis_client: aioredis.Redis = Depends(get_redis_client),
) -> RecommendationCacheService:
    return RecommendationCacheService(redis_client)


def get_recommendation_service(
    playlist_repo: PlaylistRepository = Depends(get_playlist_repository),
    track_repo: TrackRepository = Depends(get_track_repository),
    rec_set_repo: RecommendationSetRepository = Depends(get_recommendation_set_repository),
    rec_item_repo: RecommendationItemRepository = Depends(get_recommendation_item_repository),
    gemini_client: GeminiRecommendationClient = Depends(get_gemini_recommendation_client),
    cache_service: RecommendationCacheService = Depends(get_recommendation_cache_service),
) -> RecommendationService:
    preference_service = UserPreferenceService(playlist_repo, track_repo)
    candidate_service = CandidateGenerationService(track_repo)
    ranking_service = RankingService()
    diversity_service = DiversityService()

    return RecommendationService(
        preference_service=preference_service,
        candidate_service=candidate_service,
        ranking_service=ranking_service,
        diversity_service=diversity_service,
        gemini_client=gemini_client,
        cache_service=cache_service,
        rec_set_repo=rec_set_repo,
        rec_item_repo=rec_item_repo,
        track_repo=track_repo,
    )


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
