from fastapi import APIRouter, Depends, status

from app.core.dependencies import get_current_user
from app.db.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.user import UserRead

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
