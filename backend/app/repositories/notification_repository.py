import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models.notification import Notification, NotificationPreference, UserDevice
from app.repositories.base import BaseRepository


class UserDeviceRepository(BaseRepository[UserDevice]):
    """Repository handling user push notification device registrations."""

    def __init__(self, session: AsyncSession):
        super().__init__(UserDevice, session)

    async def register_or_update_device(
        self,
        user_id: uuid.UUID,
        token: str,
        platform: str,
        device_name: Optional[str] = None,
        app_version: Optional[str] = None,
    ) -> UserDevice:
        """
        Registers a new device token or updates an existing token registration.
        If the token exists, associates it with the current user, marks it active,
        and refreshes last_seen_at and metadata.
        """
        stmt = select(UserDevice).where(UserDevice.device_token == token)
        result = await self.session.execute(stmt)
        device = result.scalar_one_or_none()

        now = datetime.now(timezone.utc)
        if device:
            device.user_id = user_id
            device.platform = platform
            if device_name is not None:
                device.device_name = device_name
            if app_version is not None:
                device.app_version = app_version
            device.is_active = True
            device.last_seen_at = now
            await self.session.flush()
            await self.session.refresh(device)
            return device

        # Create new device record
        return await self.create(
            user_id=user_id,
            device_token=token,
            platform=platform,
            device_name=device_name,
            app_version=app_version,
            is_active=True,
            last_seen_at=now,
        )

    async def get_by_id_and_user(self, device_id: uuid.UUID, user_id: uuid.UUID) -> Optional[UserDevice]:
        """Retrieves a device record scoped to a specific user."""
        stmt = select(UserDevice).where(
            UserDevice.id == device_id,
            UserDevice.user_id == user_id,
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_active_devices_by_user_id(self, user_id: uuid.UUID) -> List[UserDevice]:
        """Retrieves all active registered devices for a user."""
        stmt = select(UserDevice).where(
            UserDevice.user_id == user_id,
            UserDevice.is_active.is_(True),
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def deactivate_device(self, device_id: uuid.UUID, user_id: uuid.UUID) -> bool:
        """Deactivates a specific device owned by the user."""
        stmt = (
            update(UserDevice)
            .where(
                UserDevice.id == device_id,
                UserDevice.user_id == user_id,
            )
            .values(is_active=False)
        )
        result = await self.session.execute(stmt)
        await self.session.flush()
        return result.rowcount > 0

    async def deactivate_by_token(self, token: str, user_id: uuid.UUID) -> bool:
        """Deactivates a device by token for the given user (e.g. on logout)."""
        stmt = (
            update(UserDevice)
            .where(
                UserDevice.device_token == token,
                UserDevice.user_id == user_id,
            )
            .values(is_active=False)
        )
        result = await self.session.execute(stmt)
        await self.session.flush()
        return result.rowcount > 0

    async def deactivate_tokens(self, tokens: List[str]) -> int:
        """Bulk deactivates invalid/unregistered tokens returned by push provider."""
        if not tokens:
            return 0
        stmt = (
            update(UserDevice)
            .where(UserDevice.device_token.in_(tokens))
            .values(is_active=False)
        )
        result = await self.session.execute(stmt)
        await self.session.flush()
        return result.rowcount


class NotificationPreferenceRepository(BaseRepository[NotificationPreference]):
    """Repository handling user notification preferences."""

    def __init__(self, session: AsyncSession):
        super().__init__(NotificationPreference, session)

    async def get_by_user_id(self, user_id: uuid.UUID) -> Optional[NotificationPreference]:
        """Fetches preferences for the given user."""
        stmt = select(NotificationPreference).where(NotificationPreference.user_id == user_id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_or_create(self, user_id: uuid.UUID) -> NotificationPreference:
        """Fetches preferences or initializes them with default enabled values."""
        pref = await self.get_by_user_id(user_id)
        if pref:
            return pref

        return await self.create(
            user_id=user_id,
            push_enabled=True,
            new_releases_enabled=True,
            playlist_updates_enabled=True,
            recommendations_enabled=True,
            processing_updates_enabled=True,
        )

    async def update_preferences(self, user_id: uuid.UUID, **kwargs: Any) -> NotificationPreference:
        """Updates user preferences, creating defaults first if none exist."""
        pref = await self.get_or_create(user_id)
        for key, value in kwargs.items():
            if value is not None and hasattr(pref, key):
                setattr(pref, key, value)
        await self.session.flush()
        await self.session.refresh(pref)
        return pref


class NotificationRepository(BaseRepository[Notification]):
    """Repository handling notification history, read states, and unread counts."""

    def __init__(self, session: AsyncSession):
        super().__init__(Notification, session)

    async def create_notification(
        self,
        user_id: uuid.UUID,
        type: str,
        title: str,
        body: str,
        data: Optional[Dict[str, Any]] = None,
        idempotency_key: Optional[str] = None,
    ) -> Tuple[Notification, bool]:
        """
        Creates a notification. If an idempotency_key is provided and a record
        already exists with that key, returns the existing record (created=False).
        Otherwise creates a new notification (created=True).
        """
        if idempotency_key:
            stmt = select(Notification).where(Notification.idempotency_key == idempotency_key)
            result = await self.session.execute(stmt)
            existing = result.scalar_one_or_none()
            if existing:
                return existing, False

        notification = await self.create(
            user_id=user_id,
            type=type,
            title=title,
            body=body,
            data=data or {},
            is_read=False,
            idempotency_key=idempotency_key,
        )
        return notification, True

    async def get_by_id_and_user(self, notification_id: uuid.UUID, user_id: uuid.UUID) -> Optional[Notification]:
        """Retrieves a notification record scoped to a specific user."""
        stmt = select(Notification).where(
            Notification.id == notification_id,
            Notification.user_id == user_id,
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def list_for_user(
        self,
        user_id: uuid.UUID,
        skip: int = 0,
        limit: int = 50,
        is_read: Optional[bool] = None,
    ) -> Tuple[List[Notification], int]:
        """Retrieves paginated notifications and total count for a user."""
        base_where = [Notification.user_id == user_id]
        if is_read is not None:
            base_where.append(Notification.is_read == is_read)

        count_stmt = select(func.count(Notification.id)).where(*base_where)
        count_res = await self.session.execute(count_stmt)
        total = count_res.scalar_one()

        items_stmt = (
            select(Notification)
            .where(*base_where)
            .order_by(Notification.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        items_res = await self.session.execute(items_stmt)
        items = list(items_res.scalars().all())

        return items, total

    async def get_unread_count(self, user_id: uuid.UUID) -> int:
        """Fast count query for unread notifications for a user."""
        stmt = select(func.count(Notification.id)).where(
            Notification.user_id == user_id,
            Notification.is_read.is_(False),
        )
        result = await self.session.execute(stmt)
        return result.scalar_one()

    async def mark_as_read(self, notification_id: uuid.UUID, user_id: uuid.UUID) -> Optional[Notification]:
        """Marks a single user notification as read."""
        notification = await self.get_by_id_and_user(notification_id, user_id)
        if not notification:
            return None

        if not notification.is_read:
            notification.is_read = True
            notification.read_at = datetime.now(timezone.utc)
            await self.session.flush()
            await self.session.refresh(notification)

        return notification

    async def mark_all_as_read(self, user_id: uuid.UUID) -> int:
        """Marks all unread notifications for a user as read in bulk."""
        now = datetime.now(timezone.utc)
        stmt = (
            update(Notification)
            .where(
                Notification.user_id == user_id,
                Notification.is_read.is_(False),
            )
            .values(is_read=True, read_at=now)
        )
        result = await self.session.execute(stmt)
        await self.session.flush()
        return result.rowcount
