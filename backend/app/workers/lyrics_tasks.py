import asyncio
import logging
import uuid

from celery.exceptions import MaxRetriesExceededError

from app.db.database import AsyncSessionLocal
from app.repositories.audio_repository import TrackRepository
from app.repositories.lyrics_repository import LyricsRepository
from app.services.lyrics_service import LyricsService
from app.workers.celery_app import celery_app

logger = logging.getLogger("hums.workers.lyrics")


@celery_app.task(
    bind=True,
    name="app.workers.lyrics_tasks.generate_track_lyrics",
    max_retries=3,
    default_retry_delay=15,
)
def generate_track_lyrics(self, track_id_str: str) -> bool:
    """
    Celery background task for asynchronous AI lyrics extraction,
    timestamp synchronization, and persistence.
    """
    logger.info(
        f"Worker received generate_track_lyrics task for track_id={track_id_str} (attempt {self.request.retries + 1})"
    )

    try:
        track_id = uuid.UUID(track_id_str)
    except ValueError:
        logger.error(f"Invalid UUID string passed to generate_track_lyrics: {track_id_str}")
        return False

    async def _run() -> bool:
        async with AsyncSessionLocal() as session:
            lyrics_repo = LyricsRepository(session)
            track_repo = TrackRepository(session)
            service = LyricsService(lyrics_repo=lyrics_repo, track_repo=track_repo)
            try:
                await service.generate_lyrics(track_id)
                await session.commit()
                return True
            except Exception as e:
                await session.rollback()
                logger.error(f"Error during lyrics generation for track {track_id}: {e}", exc_info=True)
                raise e

    try:
        return asyncio.run(_run())
    except Exception as exc:
        is_transient = any(
            keyword in str(exc).lower()
            for keyword in ["connection", "timeout", "network", "reset", "temporary", "429", "rate limit"]
        )

        if is_transient and self.request.retries < self.max_retries:
            logger.warning(
                f"Retrying lyrics generation for track {track_id} (retry {self.request.retries + 1}/{self.max_retries})"
            )
            try:
                raise self.retry(exc=exc, countdown=15 * (2 ** self.request.retries))
            except MaxRetriesExceededError:
                logger.error(f"Max retries exceeded for lyrics generation on track {track_id}")
                return False

        return False
