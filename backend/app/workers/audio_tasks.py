import asyncio
import logging
import uuid

from celery.exceptions import MaxRetriesExceededError

from app.core.config import get_settings
from app.services.audio_processing_service import AudioProcessingService
from app.workers.celery_app import celery_app

logger = logging.getLogger("hums.workers.audio")
settings = get_settings()


@celery_app.task(
    bind=True,
    name="app.workers.audio_tasks.process_audio_track",
    max_retries=3,
    default_retry_delay=15,
)
def process_audio_track(self, track_id_str: str) -> bool:
    """
    Celery background task for asynchronous audio transcoding, waveform extraction,
    and metadata persistence.
    """
    logger.info(
        f"Worker received process_audio_track task for track_id={track_id_str} (attempt {self.request.retries + 1})"
    )

    try:
        track_id = uuid.UUID(track_id_str)
    except ValueError:
        logger.error(f"Invalid UUID string passed to process_audio_track: {track_id_str}")
        return False

    service = AudioProcessingService()

    try:
        # Run async processing pipeline
        success = asyncio.run(service.process_track(track_id))
        return success
    except Exception as exc:
        logger.error(
            f"Unhandled exception in process_audio_track for {track_id}: {exc}",
            exc_info=True,
        )
        # Check if we should retry for transient network/infrastructure errors
        is_transient = any(
            keyword in str(exc).lower()
            for keyword in ["connection", "timeout", "network", "reset", "temporary"]
        )

        if is_transient and self.request.retries < self.max_retries:
            logger.warning(
                f"Retrying task for track {track_id} due to transient error (retry {self.request.retries + 1}/{self.max_retries})"
            )
            try:
                raise self.retry(exc=exc, countdown=15 * (2 ** self.request.retries))
            except MaxRetriesExceededError:
                logger.error(f"Max retries exceeded for track {track_id}")
                return False

        return False
