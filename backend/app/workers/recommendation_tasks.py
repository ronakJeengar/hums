import asyncio
import logging
import uuid
import redis.asyncio as aioredis

from app.core.config import get_settings
from app.db.database import AsyncSessionLocal
from app.repositories.audio_repository import TrackRepository
from app.repositories.playlist_repository import PlaylistRepository
from app.repositories.recommendation_repository import (
    RecommendationItemRepository,
    RecommendationSetRepository,
)
from app.repositories.user_repository import UserRepository
from app.ai.gemini_recommendation_client import GeminiRecommendationClient
from app.services.recommendation.cache_service import RecommendationCacheService
from app.services.recommendation.candidate_service import CandidateGenerationService
from app.services.recommendation.diversity_service import DiversityService
from app.services.recommendation.ranking_service import RankingService
from app.services.recommendation.user_preference_service import UserPreferenceService
from app.services.recommendation_service import RecommendationService
from app.workers.celery_app import celery_app

logger = logging.getLogger("hums.workers.recommendations")
settings = get_settings()


async def _async_generate_recommendations(user_id: uuid.UUID) -> bool:
    """Async worker function running within an isolated DB session."""
    redis_client = aioredis.from_url(
        settings.REDIS_URL,
        encoding="utf-8",
        decode_responses=True,
    )
    try:
        async with AsyncSessionLocal() as session:
            user_repo = UserRepository(session)
            user = await user_repo.get_by_id(user_id)
            if not user:
                logger.warning(f"User {user_id} not found for recommendation job")
                return False

            track_repo = TrackRepository(session)
            playlist_repo = PlaylistRepository(session)
            rec_set_repo = RecommendationSetRepository(session)
            rec_item_repo = RecommendationItemRepository(session)

            pref_service = UserPreferenceService(playlist_repo, track_repo)
            candidate_service = CandidateGenerationService(track_repo)
            ranking_service = RankingService()
            diversity_service = DiversityService()
            gemini_client = GeminiRecommendationClient()
            cache_service = RecommendationCacheService(redis_client)

            rec_service = RecommendationService(
                preference_service=pref_service,
                candidate_service=candidate_service,
                ranking_service=ranking_service,
                diversity_service=diversity_service,
                gemini_client=gemini_client,
                cache_service=cache_service,
                rec_set_repo=rec_set_repo,
                rec_item_repo=rec_item_repo,
                track_repo=track_repo,
            )

            await rec_service.get_recommendations(user, refresh=True)
            await session.commit()
            logger.info(f"Background recommendations generated successfully for user {user_id}")
            return True
    finally:
        await redis_client.aclose()


@celery_app.task(
    bind=True,
    name="app.workers.recommendation_tasks.generate_user_recommendations",
    max_retries=2,
    default_retry_delay=10,
)
def generate_user_recommendations(self, user_id_str: str) -> bool:
    """
    Celery background task for asynchronous user recommendation generation
    and cache warming.
    """
    logger.info(
        f"Worker received recommendation generation task for user_id={user_id_str} "
        f"(attempt {self.request.retries + 1})"
    )

    try:
        user_id = uuid.UUID(user_id_str)
    except ValueError:
        logger.error(f"Invalid UUID string passed to recommendation task: {user_id_str}")
        return False

    try:
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = None

        if loop and loop.is_running():
            import concurrent.futures

            with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
                future = executor.submit(
                    asyncio.run, _async_generate_recommendations(user_id)
                )
                return future.result()
        else:
            return asyncio.run(_async_generate_recommendations(user_id))
    except Exception as exc:
        logger.error(
            f"Error during recommendation generation task for {user_id}: {exc}",
            exc_info=True,
        )
        if hasattr(self, "request") and self.request.retries < self.max_retries:
            raise self.retry(exc=exc, countdown=10 * (2 ** self.request.retries))
        return False
