import uuid
from typing import AsyncGenerator, Optional
from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import redis.asyncio as aioredis
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AuthenticationError
from app.core.security import decode_token
from app.db.database import get_db
from app.db.models.user import User
from app.repositories.audio_repository import (
    AudioFileRepository,
    ProcessingJobRepository,
    TrackRepository,
)
from app.repositories.creator_repository import CreatorRepository
from app.repositories.like_repository import LikeRepository
from app.repositories.playback_repository import PlaybackRepository
from app.repositories.playlist_repository import PlaylistRepository
from app.repositories.search_repository import SearchRepository
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
from app.ai.gemini_lyrics_client import GeminiLyricsClient
from app.repositories.lyrics_repository import LyricsRepository
from app.services.audio_service import AudioService
from app.services.auth_service import AuthService
from app.services.creator_service import CreatorService
from app.services.like_service import LikeService
from app.services.lyrics_service import LyricsService
from app.services.playback_service import PlaybackService
from app.services.playlist_service import PlaylistService
from app.services.profile_service import ProfileService
from app.services.search_service import SearchService
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


async def check_celery_broker_health() -> bool:
    """Verifies Celery Redis broker reachability."""
    try:
        client = aioredis.from_url(settings.REDIS_URL, socket_timeout=2.0)
        pong = await client.ping()
        await client.aclose()
        return bool(pong)
    except Exception:
        return False


async def check_storage_health() -> bool:
    """Verifies S3/MinIO object storage reachability."""
    import asyncio
    try:
        storage = S3StorageService()
        def _check():
            storage.s3_client.head_bucket(Bucket=settings.S3_BUCKET)
            return True
        return await asyncio.to_thread(_check)
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


def get_like_repository(session: AsyncSession = Depends(get_db)) -> LikeRepository:
    return LikeRepository(session)


def get_search_repository(session: AsyncSession = Depends(get_db)) -> SearchRepository:
    return SearchRepository(session)


def get_search_service(
    search_repo: SearchRepository = Depends(get_search_repository),
    storage_service: BaseStorageService = Depends(get_storage_service),
    like_repo: LikeRepository = Depends(get_like_repository),
) -> SearchService:
    return SearchService(search_repo, storage_service, like_repo)


def get_playback_repository(
    session: AsyncSession = Depends(get_db),
) -> PlaybackRepository:
    return PlaybackRepository(session)


def get_playback_service(
    session: AsyncSession = Depends(get_db),
) -> PlaybackService:
    return PlaybackService(session)


def get_notification_service(
    session: AsyncSession = Depends(get_db),
) -> "NotificationService":
    from app.services.notification_service import NotificationService

    return NotificationService(session=session)


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


def get_creator_repository(
    session: AsyncSession = Depends(get_db),
) -> CreatorRepository:
    return CreatorRepository(session)


async def get_creator_service(
    creator_repo: CreatorRepository = Depends(get_creator_repository),
    redis_client: aioredis.Redis = Depends(get_redis_client),
    storage_service: BaseStorageService = Depends(get_storage_service),
) -> CreatorService:
    return CreatorService(creator_repo, redis_client, storage_service)


async def get_like_service(
    like_repo: LikeRepository = Depends(get_like_repository),
    redis_client: aioredis.Redis = Depends(get_redis_client),
    playlist_repo: PlaylistRepository = Depends(get_playlist_repository),
    creator_repo: CreatorRepository = Depends(get_creator_repository),
) -> LikeService:
    return LikeService(like_repo, redis_client, playlist_repo, creator_repo)


def get_lyrics_repository(session: AsyncSession = Depends(get_db)) -> LyricsRepository:
    return LyricsRepository(session)


def get_gemini_lyrics_client() -> GeminiLyricsClient:
    return GeminiLyricsClient()


async def get_lyrics_service(
    lyrics_repo: LyricsRepository = Depends(get_lyrics_repository),
    track_repo: TrackRepository = Depends(get_track_repository),
    gemini_client: GeminiLyricsClient = Depends(get_gemini_lyrics_client),
    redis_client: aioredis.Redis = Depends(get_redis_client),
) -> LyricsService:
    return LyricsService(
        lyrics_repo=lyrics_repo,
        track_repo=track_repo,
        gemini_client=gemini_client,
        redis_client=redis_client,
    )


def get_recommendation_service(
    playlist_repo: PlaylistRepository = Depends(get_playlist_repository),
    track_repo: TrackRepository = Depends(get_track_repository),
    creator_repo: CreatorRepository = Depends(get_creator_repository),
    like_repo: LikeRepository = Depends(get_like_repository),
    rec_set_repo: RecommendationSetRepository = Depends(get_recommendation_set_repository),
    rec_item_repo: RecommendationItemRepository = Depends(get_recommendation_item_repository),
    gemini_client: GeminiRecommendationClient = Depends(get_gemini_recommendation_client),
    cache_service: RecommendationCacheService = Depends(get_recommendation_cache_service),
) -> RecommendationService:
    preference_service = UserPreferenceService(playlist_repo, track_repo, creator_repo, like_repo)
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
    except Exception:
        raise AuthenticationError(
            "Invalid or expired token",
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


async def get_optional_current_user(
    auth: Optional[HTTPAuthorizationCredentials] = Depends(security_scheme),
    user_repo: UserRepository = Depends(get_user_repository),
) -> Optional[User]:
    """Optionally extracts and validates authenticated user if Bearer token is provided."""
    if not auth or not auth.credentials:
        return None
    try:
        payload = decode_token(auth.credentials)
        if payload.get("type") != "access":
            return None
        user_id_str = payload.get("sub")
        if not user_id_str:
            return None
        user_id = uuid.UUID(user_id_str)
        user = await user_repo.get_by_id(user_id)
        if not user or not user.is_active:
            return None
        return user
    except Exception:
        return None

