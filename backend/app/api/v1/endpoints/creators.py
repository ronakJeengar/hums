import uuid
from typing import Optional

from fastapi import APIRouter, Depends, Query, status

from app.core.dependencies import (
    get_creator_service,
    get_current_user,
    get_optional_current_user,
)
from app.db.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.creator import (
    CreatorDetailResponse,
    CreatorPublicProfile,
    FollowStatusResponse,
    FollowersListResponse,
    FollowingListResponse,
)
from app.services.creator_service import CreatorService

router = APIRouter()


@router.get(
    "",
    response_model=ApiResponse[list[CreatorPublicProfile]],
    status_code=status.HTTP_200_OK,
    summary="List popular creators",
    description="Returns a list of popular artists and creators for discovery.",
)
async def list_creators(
    skip: int = Query(0, ge=0, description="Pagination skip"),
    limit: int = Query(20, ge=1, le=50, description="Maximum items to return"),
    current_user: Optional[User] = Depends(get_optional_current_user),
    creator_service: CreatorService = Depends(get_creator_service),
) -> ApiResponse[list[CreatorPublicProfile]]:
    user_id = current_user.id if current_user else None
    items, _ = await creator_service.list_creators(skip=skip, limit=limit, current_user_id=user_id)
    return ApiResponse(data=items)


@router.get(
    "/following",
    response_model=ApiResponse[FollowingListResponse],
    status_code=status.HTTP_200_OK,
    summary="Get followed creators for current user",
    description="Returns paginated list of creators the authenticated user follows.",
)
async def get_my_following(
    page: int = Query(1, ge=1, description="Page number"),
    size: int = Query(20, ge=1, le=100, description="Page size"),
    current_user: User = Depends(get_current_user),
    creator_service: CreatorService = Depends(get_creator_service),
) -> ApiResponse[FollowingListResponse]:
    result = await creator_service.get_following(current_user.id, page=page, size=size)
    return ApiResponse(data=result)


@router.get(
    "/{creator_id}",
    response_model=ApiResponse[CreatorDetailResponse],
    status_code=status.HTTP_200_OK,
    summary="Get creator public profile",
    description="Returns public creator details, track aggregates, albums, and follow state.",
)
async def get_creator_profile(
    creator_id: uuid.UUID,
    current_user: Optional[User] = Depends(get_optional_current_user),
    creator_service: CreatorService = Depends(get_creator_service),
) -> ApiResponse[CreatorDetailResponse]:
    user_id = current_user.id if current_user else None
    creator = await creator_service.get_creator_by_id(creator_id, current_user_id=user_id)
    return ApiResponse(data=creator)


@router.post(
    "/{creator_id}/follow",
    response_model=ApiResponse[FollowStatusResponse],
    status_code=status.HTTP_200_OK,
    summary="Follow a creator",
    description="Follows the specified creator atomically. Idempotent.",
)
async def follow_creator(
    creator_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    creator_service: CreatorService = Depends(get_creator_service),
) -> ApiResponse[FollowStatusResponse]:
    result = await creator_service.follow(current_user.id, creator_id)
    return ApiResponse(data=result)


@router.delete(
    "/{creator_id}/follow",
    response_model=ApiResponse[FollowStatusResponse],
    status_code=status.HTTP_200_OK,
    summary="Unfollow a creator",
    description="Unfollows the specified creator atomically. Idempotent.",
)
async def unfollow_creator(
    creator_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    creator_service: CreatorService = Depends(get_creator_service),
) -> ApiResponse[FollowStatusResponse]:
    result = await creator_service.unfollow(current_user.id, creator_id)
    return ApiResponse(data=result)


@router.get(
    "/{creator_id}/follow-status",
    response_model=ApiResponse[FollowStatusResponse],
    status_code=status.HTTP_200_OK,
    summary="Get follow status for a creator",
    description="Returns whether the current user is following the creator and total follower count.",
)
async def get_follow_status(
    creator_id: uuid.UUID,
    current_user: Optional[User] = Depends(get_optional_current_user),
    creator_service: CreatorService = Depends(get_creator_service),
) -> ApiResponse[FollowStatusResponse]:
    user_id = current_user.id if current_user else None
    result = await creator_service.get_follow_status(creator_id, current_user_id=user_id)
    return ApiResponse(data=result)


@router.get(
    "/{creator_id}/followers",
    response_model=ApiResponse[FollowersListResponse],
    status_code=status.HTTP_200_OK,
    summary="Get creator followers",
    description="Returns paginated public list of users following this creator.",
)
async def get_creator_followers(
    creator_id: uuid.UUID,
    page: int = Query(1, ge=1, description="Page number"),
    size: int = Query(20, ge=1, le=100, description="Page size"),
    creator_service: CreatorService = Depends(get_creator_service),
) -> ApiResponse[FollowersListResponse]:
    result = await creator_service.get_followers(creator_id, page=page, size=size)
    return ApiResponse(data=result)
