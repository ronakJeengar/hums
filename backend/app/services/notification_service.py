import logging
import uuid
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.db.database import AsyncSessionLocal
from app.db.models.notification import Notification, NotificationPreference, UserDevice
from app.repositories.notification_repository import (
    NotificationPreferenceRepository,
    NotificationRepository,
    UserDeviceRepository,
)
from app.schemas.notification import NotificationPreferencesUpdate, NotificationType
from app.services.push import PushDeliveryResult, PushMessage, PushProvider, get_push_provider

logger = logging.getLogger("hums.services.notifications")
settings = get_settings()


class NotificationService:
    """
    Central business service for push notification dispatch, device lifecycle,
    preference management, and inbox read/unread history.
    """

    def __init__(
        self,
        session: Optional[AsyncSession] = None,
        push_provider: Optional[PushProvider] = None,
    ):
        self._session = session
        self._push_provider = push_provider

    @property
    def push_provider(self) -> PushProvider:
        if self._push_provider is not None:
            return self._push_provider
        return get_push_provider()

    async def _get_session(self) -> AsyncSession:
        """Returns existing session or creates a new one."""
        if self._session is not None:
            return self._session
        return AsyncSessionLocal()

    # ---------------------------------------------------------------------------
    # Device Registration Management
    # ---------------------------------------------------------------------------

    async def register_device(
        self,
        user_id: uuid.UUID,
        token: str,
        platform: str,
        device_name: Optional[str] = None,
        app_version: Optional[str] = None,
    ) -> UserDevice:
        """Registers or updates a device push token for a user."""
        if self._session:
            repo = UserDeviceRepository(self._session)
            device = await repo.register_or_update_device(
                user_id=user_id,
                token=token,
                platform=platform,
                device_name=device_name,
                app_version=app_version,
            )
            await self._session.commit()
            return device

        async with AsyncSessionLocal() as session:
            repo = UserDeviceRepository(session)
            device = await repo.register_or_update_device(
                user_id=user_id,
                token=token,
                platform=platform,
                device_name=device_name,
                app_version=app_version,
            )
            await session.commit()
            return device

    async def deactivate_device(self, device_id: uuid.UUID, user_id: uuid.UUID) -> bool:
        """Deactivates a device registration for a user."""
        if self._session:
            repo = UserDeviceRepository(self._session)
            success = await repo.deactivate_device(device_id, user_id)
            await self._session.commit()
            return success

        async with AsyncSessionLocal() as session:
            repo = UserDeviceRepository(session)
            success = await repo.deactivate_device(device_id, user_id)
            await session.commit()
            return success

    async def deactivate_by_token(self, token: str, user_id: uuid.UUID) -> bool:
        """Deactivates a device registration by token on logout."""
        if self._session:
            repo = UserDeviceRepository(self._session)
            success = await repo.deactivate_by_token(token, user_id)
            await self._session.commit()
            return success

        async with AsyncSessionLocal() as session:
            repo = UserDeviceRepository(session)
            success = await repo.deactivate_by_token(token, user_id)
            await session.commit()
            return success

    # ---------------------------------------------------------------------------
    # Preferences Management
    # ---------------------------------------------------------------------------

    async def get_preferences(self, user_id: uuid.UUID) -> NotificationPreference:
        """Retrieves or creates default notification preferences for a user."""
        if self._session:
            repo = NotificationPreferenceRepository(self._session)
            pref = await repo.get_or_create(user_id)
            await self._session.commit()
            return pref

        async with AsyncSessionLocal() as session:
            repo = NotificationPreferenceRepository(session)
            pref = await repo.get_or_create(user_id)
            await session.commit()
            return pref

    async def update_preferences(
        self, user_id: uuid.UUID, update_data: NotificationPreferencesUpdate
    ) -> NotificationPreference:
        """Updates user notification preferences."""
        update_dict = update_data.model_dump(exclude_unset=True)
        if self._session:
            repo = NotificationPreferenceRepository(self._session)
            pref = await repo.update_preferences(user_id, **update_dict)
            await self._session.commit()
            return pref

        async with AsyncSessionLocal() as session:
            repo = NotificationPreferenceRepository(session)
            pref = await repo.update_preferences(user_id, **update_dict)
            await session.commit()
            return pref

    # ---------------------------------------------------------------------------
    # Notification History & Read State
    # ---------------------------------------------------------------------------

    async def list_notifications(
        self,
        user_id: uuid.UUID,
        skip: int = 0,
        limit: int = 50,
        is_read: Optional[bool] = None,
    ) -> Tuple[List[Notification], int]:
        """Lists paginated notifications for the user."""
        if self._session:
            repo = NotificationRepository(self._session)
            return await repo.list_for_user(user_id, skip=skip, limit=limit, is_read=is_read)

        async with AsyncSessionLocal() as session:
            repo = NotificationRepository(session)
            return await repo.list_for_user(user_id, skip=skip, limit=limit, is_read=is_read)

    async def get_unread_count(self, user_id: uuid.UUID) -> int:
        """Returns the number of unread notifications for a user."""
        if self._session:
            repo = NotificationRepository(self._session)
            return await repo.get_unread_count(user_id)

        async with AsyncSessionLocal() as session:
            repo = NotificationRepository(session)
            return await repo.get_unread_count(user_id)

    async def mark_as_read(
        self, notification_id: uuid.UUID, user_id: uuid.UUID
    ) -> Optional[Notification]:
        """Marks a single notification as read."""
        if self._session:
            repo = NotificationRepository(self._session)
            notif = await repo.mark_as_read(notification_id, user_id)
            await self._session.commit()
            return notif

        async with AsyncSessionLocal() as session:
            repo = NotificationRepository(session)
            notif = await repo.mark_as_read(notification_id, user_id)
            await session.commit()
            return notif

    async def mark_all_as_read(self, user_id: uuid.UUID) -> int:
        """Marks all unread notifications for a user as read."""
        if self._session:
            repo = NotificationRepository(self._session)
            count = await repo.mark_all_as_read(user_id)
            await self._session.commit()
            return count

        async with AsyncSessionLocal() as session:
            repo = NotificationRepository(session)
            count = await repo.mark_all_as_read(user_id)
            await session.commit()
            return count

    # ---------------------------------------------------------------------------
    # Notification Creation & Async Celery Dispatch
    # ---------------------------------------------------------------------------

    def _is_push_allowed(
        self, pref: NotificationPreference, notification_type: str
    ) -> bool:
        """Determines whether a push notification should be dispatched based on user preferences."""
        if not pref.push_enabled or not settings.PUSH_ENABLED:
            return False

        type_lower = notification_type.upper()
        if type_lower == NotificationType.NEW_RELEASE.value:
            return pref.new_releases_enabled
        elif type_lower == NotificationType.PLAYLIST_UPDATE.value:
            return pref.playlist_updates_enabled
        elif type_lower in (
            NotificationType.UPLOAD_COMPLETE.value,
            NotificationType.TRANSCRIPTION_COMPLETE.value,
        ):
            return pref.processing_updates_enabled
        elif type_lower == NotificationType.RECOMMENDATION_READY.value:
            return pref.recommendations_enabled
        return True

    async def notify_user(
        self,
        user_id: uuid.UUID,
        notification_type: str,
        title: str,
        body: str,
        data: Optional[Dict[str, Any]] = None,
        idempotency_key: Optional[str] = None,
        dispatch_push: bool = True,
    ) -> Optional[Notification]:
        """
        Creates an inbox notification record and queues a Celery job to deliver
        push notifications to user devices if allowed by user preferences.
        """
        data_payload = data or {}

        async with AsyncSessionLocal() as session:
            notif_repo = NotificationRepository(session)
            pref_repo = NotificationPreferenceRepository(session)

            pref = await pref_repo.get_or_create(user_id)

            notification, created = await notif_repo.create_notification(
                user_id=user_id,
                type=notification_type,
                title=title,
                body=body,
                data=data_payload,
                idempotency_key=idempotency_key,
            )
            await session.commit()

            # If idempotency key matched an existing notification, do not re-dispatch
            if not created:
                logger.info(f"Duplicate notification with idempotency_key={idempotency_key} ignored")
                return notification

            # Check if push delivery is permitted
            should_push = dispatch_push and self._is_push_allowed(pref, notification_type)

            if should_push:
                self._queue_push_delivery(
                    user_id=user_id,
                    title=title,
                    body=body,
                    data=data_payload,
                    notification_id=notification.id,
                )

            return notification

    def _queue_push_delivery(
        self,
        user_id: uuid.UUID,
        title: str,
        body: str,
        data: Dict[str, Any],
        notification_id: uuid.UUID,
    ) -> None:
        """Dispatches asynchronous delivery job via Celery worker."""
        try:
            from app.workers.notification_tasks import send_push_notification

            send_push_notification.delay(
                user_id_str=str(user_id),
                title=title,
                body=body,
                data=data,
                notification_id_str=str(notification_id),
            )
            logger.info(f"Dispatched Celery push notification task for user {user_id}")
        except Exception as exc:
            # Fallback if Celery broker is unavailable in testing or local mode
            logger.warning(f"Could not enqueue Celery push task: {exc}")

    # ---------------------------------------------------------------------------
    # Physical Delivery Execution (Called by Celery Worker)
    # ---------------------------------------------------------------------------

    async def deliver_to_user_devices(
        self,
        user_id: uuid.UUID,
        title: str,
        body: str,
        data: Dict[str, Any],
    ) -> PushDeliveryResult:
        """
        Retrieves active devices for user and dispatches multicast push via the provider.
        Automatically deactivates invalid/unregistered tokens returned by provider.
        """
        async with AsyncSessionLocal() as session:
            device_repo = UserDeviceRepository(session)
            active_devices = await device_repo.get_active_devices_by_user_id(user_id)

            if not active_devices:
                logger.info(f"No active registered devices for user {user_id}")
                return PushDeliveryResult()

            tokens = [d.device_token for d in active_devices]
            str_data = {str(k): str(v) for k, v in data.items()}

            push_message = PushMessage(
                title=title,
                body=body,
                data=str_data,
            )

            result = await self.push_provider.send_multicast(tokens, push_message)

            # Auto-prune any invalidated tokens reported by FCM
            if result.invalid_tokens:
                deactivated = await device_repo.deactivate_tokens(result.invalid_tokens)
                await session.commit()
                logger.info(f"Automatically deactivated {deactivated} invalid device tokens")

            return result
