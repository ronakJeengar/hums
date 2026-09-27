import uuid
from fastapi import APIRouter, Depends, status

from app.core.dependencies import get_current_user, get_like_service
from app.core.rate_limit import RateLimiter
from app.db.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.like import LikeStatusResponse
from app.services.like_service import LikeService

router = APIRouter()


@router.post(
    "/{track_id}/like",
    response_model=ApiResponse[LikeStatusResponse],
    status_code=status.HTTP_200_OK,
    summary="Like a track",
    description="Likes an audio track idempotently and increments the server-side like counter.",
    dependencies=[Depends(RateLimiter(requests=60, window_seconds=60, action="track_like"))],
)
async def like_track(
    track_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    like_service: LikeService = Depends(get_like_service),
) -> ApiResponse[LikeStatusResponse]:
    result = await like_service.like_track(
        user_id=current_user.id,
        track_id=track_id,
    )
    return ApiResponse(data=result)


@router.delete(
    "/{track_id}/like",
    response_model=ApiResponse[LikeStatusResponse],
    status_code=status.HTTP_200_OK,
    summary="Unlike a track",
    description="Removes like on an audio track idempotently and decrements the server-side like counter without going negative.",
    dependencies=[Depends(RateLimiter(requests=60, window_seconds=60, action="track_like"))],
)
async def unlike_track(
    track_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    like_service: LikeService = Depends(get_like_service),
) -> ApiResponse[LikeStatusResponse]:
    result = await like_service.unlike_track(
        user_id=current_user.id,
        track_id=track_id,
    )
    return ApiResponse(data=result)


@router.get(
    "/{track_id}/like-status",
    response_model=ApiResponse[LikeStatusResponse],
    status_code=status.HTTP_200_OK,
    summary="Get track like status",
    description="Returns whether the authenticated user has liked the track, along with authoritative like count.",
)
async def get_like_status(
    track_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    like_service: LikeService = Depends(get_like_service),
) -> ApiResponse[LikeStatusResponse]:
    result = await like_service.get_like_status(
        user_id=current_user.id,
        track_id=track_id,
    )
    return ApiResponse(data=result)
