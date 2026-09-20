from fastapi import APIRouter, Depends, File, UploadFile, status

from app.core.dependencies import get_current_user, get_profile_service
from app.db.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.profile import ProfileResponse, ProfileUpdateRequest
from app.services.profile_service import ProfileService

router = APIRouter()


@router.get(
    "",
    response_model=ApiResponse[ProfileResponse],
    status_code=status.HTTP_200_OK,
    summary="Get current user profile",
    description="Returns the profile information for the currently authenticated user.",
)
async def get_profile(
    current_user: User = Depends(get_current_user),
    profile_service: ProfileService = Depends(get_profile_service),
) -> ApiResponse[ProfileResponse]:
    profile = await profile_service.get_profile(current_user)
    return ApiResponse(data=profile)


@router.patch(
    "",
    response_model=ApiResponse[ProfileResponse],
    status_code=status.HTTP_200_OK,
    summary="Update current user profile",
    description="Partially updates profile details (name, email, bio) for the authenticated user.",
)
async def update_profile(
    body: ProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    profile_service: ProfileService = Depends(get_profile_service),
) -> ApiResponse[ProfileResponse]:
    profile = await profile_service.update_profile(current_user, body)
    return ApiResponse(data=profile)


@router.post(
    "/avatar",
    response_model=ApiResponse[ProfileResponse],
    status_code=status.HTTP_200_OK,
    summary="Upload user avatar",
    description="Uploads and replaces the user's avatar image (JPEG, PNG, WebP up to 5MB).",
)
async def upload_avatar(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    profile_service: ProfileService = Depends(get_profile_service),
) -> ApiResponse[ProfileResponse]:
    profile = await profile_service.upload_avatar(current_user, file)
    return ApiResponse(data=profile)


@router.delete(
    "/avatar",
    response_model=ApiResponse[ProfileResponse],
    status_code=status.HTTP_200_OK,
    summary="Remove user avatar",
    description="Removes the user's avatar image from storage and resets avatar reference to null.",
)
async def remove_avatar(
    current_user: User = Depends(get_current_user),
    profile_service: ProfileService = Depends(get_profile_service),
) -> ApiResponse[ProfileResponse]:
    profile = await profile_service.remove_avatar(current_user)
    return ApiResponse(data=profile)
