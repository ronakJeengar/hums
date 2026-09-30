from fastapi import APIRouter, Depends, status

from app.core.dependencies import get_current_user, get_playback_settings_service
from app.core.rate_limit import RateLimiter
from app.db.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.playback_settings import (
    PlaybackSettingsResponse,
    PlaybackSettingsUpdateRequest,
)
from app.services.playback_settings_service import PlaybackSettingsService

router = APIRouter()


@router.get(
    "/playback",
    response_model=ApiResponse[PlaybackSettingsResponse],
    status_code=status.HTTP_200_OK,
    summary="Get user playback quality settings",
    description="Retrieves audio quality streaming, mobile data, Wi-Fi, download preferences, and Data Saver mode.",
)
async def get_playback_settings(
    current_user: User = Depends(get_current_user),
    service: PlaybackSettingsService = Depends(get_playback_settings_service),
) -> ApiResponse[PlaybackSettingsResponse]:
    settings_data = await service.get_playback_settings(current_user.id)
    return ApiResponse(data=settings_data)


@router.put(
    "/playback",
    response_model=ApiResponse[PlaybackSettingsResponse],
    status_code=status.HTTP_200_OK,
    summary="Update user playback quality settings",
    description="Updates audio quality streaming, mobile data, Wi-Fi, download preferences, and Data Saver mode.",
    dependencies=[Depends(RateLimiter(requests=30, window_seconds=60, action="update_playback_settings"))],
)
async def update_playback_settings(
    body: PlaybackSettingsUpdateRequest,
    current_user: User = Depends(get_current_user),
    service: PlaybackSettingsService = Depends(get_playback_settings_service),
) -> ApiResponse[PlaybackSettingsResponse]:
    updated_settings = await service.update_playback_settings(current_user.id, body)
    return ApiResponse(data=updated_settings)
