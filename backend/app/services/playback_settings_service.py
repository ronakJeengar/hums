import logging
import uuid
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import NotFoundError
from app.db.models.user import User
from app.repositories.user_repository import UserRepository
from app.schemas.playback_settings import (
    PlaybackSettingsResponse,
    PlaybackSettingsUpdateRequest,
)

logger = logging.getLogger("hums.playback.settings")


class PlaybackSettingsService:
    """Service managing user playback quality settings and data saver preferences."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.user_repo = UserRepository(session)

    async def get_playback_settings(self, user_id: uuid.UUID) -> PlaybackSettingsResponse:
        """Retrieves persistent playback quality preferences for a user."""
        user = await self.user_repo.get_by_id(user_id)
        if not user:
            raise NotFoundError("User not found", details={"user_id": str(user_id)})

        return PlaybackSettingsResponse(
            streaming_quality=user.preferred_streaming_quality or "AUTO",
            mobile_data_quality=user.preferred_mobile_quality or "LOW",
            wifi_quality=user.preferred_wifi_quality or "HIGH",
            download_quality=user.preferred_download_quality or "HIGH",
            data_saver_enabled=bool(user.data_saver_enabled),
        )

    async def update_playback_settings(
        self, user_id: uuid.UUID, data: PlaybackSettingsUpdateRequest
    ) -> PlaybackSettingsResponse:
        """Updates and persists playback quality preferences for a user."""
        user = await self.user_repo.get_by_id(user_id)
        if not user:
            raise NotFoundError("User not found", details={"user_id": str(user_id)})

        if data.streaming_quality is not None:
            user.preferred_streaming_quality = data.streaming_quality
        if data.mobile_data_quality is not None:
            user.preferred_mobile_quality = data.mobile_data_quality
        if data.wifi_quality is not None:
            user.preferred_wifi_quality = data.wifi_quality
        if data.download_quality is not None:
            user.preferred_download_quality = data.download_quality
        if data.data_saver_enabled is not None:
            user.data_saver_enabled = data.data_saver_enabled

        await self.session.commit()
        await self.session.refresh(user)

        logger.info(
            f"Updated playback settings for user {user_id}: "
            f"streaming={user.preferred_streaming_quality}, mobile={user.preferred_mobile_quality}, "
            f"wifi={user.preferred_wifi_quality}, download={user.preferred_download_quality}, "
            f"data_saver={user.data_saver_enabled}"
        )

        return PlaybackSettingsResponse(
            streaming_quality=user.preferred_streaming_quality or "AUTO",
            mobile_data_quality=user.preferred_mobile_quality or "LOW",
            wifi_quality=user.preferred_wifi_quality or "HIGH",
            download_quality=user.preferred_download_quality or "HIGH",
            data_saver_enabled=bool(user.data_saver_enabled),
        )
