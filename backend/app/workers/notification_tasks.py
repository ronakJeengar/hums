import asyncio
import logging
import uuid
from typing import Any, Dict, Optional

from celery.exceptions import MaxRetriesExceededError

from app.workers.celery_app import celery_app

logger = logging.getLogger("hums.workers.notifications")


@celery_app.task(
    bind=True,
    name="app.workers.notification_tasks.send_push_notification",
    max_retries=3,
    default_retry_delay=10,
)
def send_push_notification(
    self,
    user_id_str: str,
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None,
    notification_id_str: Optional[str] = None,
) -> bool:
    """
    Celery background task delivering push notifications to registered user devices.
    Executes asynchronous push provider delivery with exponential backoff on transient errors.
    """
    logger.info(
        f"Celery worker processing push notification for user_id={user_id_str} "
        f"(attempt {self.request.retries + 1}/{self.max_retries + 1})"
    )

    try:
        user_id = uuid.UUID(user_id_str)
    except ValueError:
        logger.error(f"Invalid UUID string passed to send_push_notification: {user_id_str}")
        return False

    # Deferred import to prevent circular dependency
    from app.services.notification_service import NotificationService

    service = NotificationService()

    try:
        result = asyncio.run(
            service.deliver_to_user_devices(
                user_id=user_id,
                title=title,
                body=body,
                data=data or {},
            )
        )

        if result.transient_error and self.request.retries < self.max_retries:
            countdown = 10 * (2 ** self.request.retries)
            logger.warning(
                f"Transient push error for user {user_id}. Retrying in {countdown}s "
                f"(retry {self.request.retries + 1}/{self.max_retries})"
            )
            try:
                raise self.retry(countdown=countdown)
            except MaxRetriesExceededError:
                logger.error(f"Max retries exceeded delivering push to user {user_id}")
                return False

        logger.info(
            f"Push notification dispatched for user {user_id}: "
            f"{result.success_count} succeeded, {result.failure_count} failed"
        )
        return True

    except Exception as exc:
        logger.error(f"Unexpected error in send_push_notification task: {exc}", exc_info=True)
        is_transient = any(
            kw in str(exc).lower()
            for kw in ["connection", "timeout", "network", "reset", "temporary", "unavailable"]
        )
        if is_transient and self.request.retries < self.max_retries:
            countdown = 10 * (2 ** self.request.retries)
            try:
                raise self.retry(exc=exc, countdown=countdown)
            except MaxRetriesExceededError:
                logger.error(f"Max retries exceeded for user {user_id}")
                return False
        return False


@celery_app.task(
    bind=True,
    name="app.workers.notification_tasks.fanout_creator_new_release",
    max_retries=3,
    default_retry_delay=15,
)
def fanout_creator_new_release(
    self,
    creator_id_str: str,
    track_id_str: str,
    track_title: str,
    creator_name: str,
) -> int:
    """
    Asynchronous fan-out notification delivery when a creator publishes a new track.
    Batches through followers and respects each follower's notification preferences.
    """
    try:
        creator_id = uuid.UUID(creator_id_str)
        track_id = uuid.UUID(track_id_str)
    except ValueError as e:
        logger.error(f"Invalid UUIDs in fanout_creator_new_release: {e}")
        return 0

    async def _fanout() -> int:
        from app.db.database import AsyncSessionLocal
        from app.repositories.creator_repository import CreatorRepository
        from app.schemas.notification import NotificationType
        from app.services.notification_service import NotificationService

        service = NotificationService()
        dispatched_count = 0

        async with AsyncSessionLocal() as session:
            creator_repo = CreatorRepository(session)
            follower_ids = await creator_repo.get_follower_user_ids(creator_id)

        for follower_id in follower_ids:
            try:
                await service.notify_user(
                    user_id=follower_id,
                    notification_type=NotificationType.NEW_RELEASE.value,
                    title=f"New Release from {creator_name}",
                    body=f"{creator_name} just released '{track_title}'.",
                    data={
                        "track_id": str(track_id),
                        "creator_id": str(creator_id),
                        "type": "new_release",
                    },
                    idempotency_key=f"release:{track_id}:{follower_id}",
                    dispatch_push=True,
                )
                dispatched_count += 1
            except Exception as e:
                logger.warning(f"Failed to dispatch new release notification to {follower_id}: {e}")

        return dispatched_count

    try:
        count = asyncio.run(_fanout())
        logger.info(f"Fan-out completed for creator {creator_id_str}: {count} followers notified")
        return count
    except Exception as exc:
        logger.error(f"Error during fanout_creator_new_release: {exc}", exc_info=True)
        if self.request.retries < self.max_retries:
            raise self.retry(exc=exc, countdown=15 * (2 ** self.request.retries))
        return 0
