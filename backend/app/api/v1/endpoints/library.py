from fastapi import APIRouter, Depends, Query, status

from app.core.dependencies import get_current_user, get_like_service
from app.db.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.library import LibrarySummaryResponse
from app.schemas.like import LikedTracksListResponse
from app.services.like_service import LikeService

router = APIRouter()


@router.get(
    "",
    response_model=ApiResponse[LibrarySummaryResponse],
    status_code=status.HTTP_200_OK,
    summary="Get personal library summary",
    description="Returns aggregate counts for liked tracks, playlists, followed creators, and recent liked tracks preview.",
)
async def get_library_summary(
    current_user: User = Depends(get_current_user),
    like_service: LikeService = Depends(get_like_service),
) -> ApiResponse[LibrarySummaryResponse]:
    summary = await like_service.get_library_summary(user_id=current_user.id)
    return ApiResponse(data=summary)


@router.get(
    "/liked-tracks",
    response_model=ApiResponse[LikedTracksListResponse],
    status_code=status.HTTP_200_OK,
    summary="Get user's liked tracks",
    description="Returns paginated list of audio tracks liked by the authenticated user, ordered by most recently liked.",
)
async def get_liked_tracks(
    page: int = Query(1, ge=1, description="Page number starting at 1"),
    size: int = Query(20, ge=1, le=100, description="Items per page"),
    current_user: User = Depends(get_current_user),
    like_service: LikeService = Depends(get_like_service),
) -> ApiResponse[LikedTracksListResponse]:
    result = await like_service.get_liked_tracks(
        user_id=current_user.id,
        page=page,
        size=size,
    )
    return ApiResponse(data=result)
