from fastapi import APIRouter, Depends, Query, status

from app.core.dependencies import get_creator_service, get_current_user
from app.db.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.creator import FollowingListResponse
from app.schemas.user import UserRead
from app.services.creator_service import CreatorService

router = APIRouter(prefix="/users", tags=["Users"])


@router.get(
    "/me",
    response_model=ApiResponse[UserRead],
    status_code=status.HTTP_200_OK,
    summary="Fetch current authenticated user profile",
)
async def get_my_profile(
    current_user: User = Depends(get_current_user),
) -> ApiResponse[UserRead]:
    """Returns safe user identity information for the bearer token."""
    return ApiResponse(data=UserRead.model_validate(current_user))


@router.get(
    "/me/following",
    response_model=ApiResponse[FollowingListResponse],
    status_code=status.HTTP_200_OK,
    summary="Fetch creators followed by the authenticated user",
)
async def get_my_following_alias(
    page: int = Query(1, ge=1, description="Page number"),
    size: int = Query(20, ge=1, le=100, description="Page size"),
    current_user: User = Depends(get_current_user),
    creator_service: CreatorService = Depends(get_creator_service),
) -> ApiResponse[FollowingListResponse]:
    """Returns paginated creators followed by the authenticated user."""
    result = await creator_service.get_following(current_user.id, page=page, size=size)
    return ApiResponse(data=result)
