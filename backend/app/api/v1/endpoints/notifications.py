import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status

from app.core.dependencies import get_current_user, get_notification_service
from app.db.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.notification import (
    DeviceRegistrationRequest,
    DeviceResponse,
    NotificationItemResponse,
    NotificationListResponse,
    NotificationPreferencesResponse,
    NotificationPreferencesUpdate,
    ReadAllResponse,
    UnreadCountResponse,
)
from app.services.notification_service import NotificationService

router = APIRouter()


# ---------------------------------------------------------------------------
# Device Registration Endpoints
# ---------------------------------------------------------------------------

@router.post(
    "/devices",
    response_model=ApiResponse[DeviceResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Register device push token",
    description="Registers or updates a device push notification token for the current user.",
)
async def register_device(
    body: DeviceRegistrationRequest,
    current_user: User = Depends(get_current_user),
    service: NotificationService = Depends(get_notification_service),
) -> ApiResponse[DeviceResponse]:
    device = await service.register_device(
        user_id=current_user.id,
        token=body.token,
        platform=body.platform.value,
        device_name=body.device_name,
        app_version=body.app_version,
    )
    return ApiResponse(data=DeviceResponse.model_validate(device))


@router.delete(
    "/devices/{device_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Deactivate device by ID",
    description="Deactivates a specific device push registration owned by the user.",
)
async def deactivate_device(
    device_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    service: NotificationService = Depends(get_notification_service),
) -> Response:
    success = await service.deactivate_device(device_id=device_id, user_id=current_user.id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device registration not found",
        )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete(
    "/devices",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Deactivate device by token",
    description="Deactivates a device registration by push token (e.g. upon user logout).",
)
async def deactivate_device_by_token(
    token: str = Query(..., min_length=5, description="Push device token to deactivate"),
    current_user: User = Depends(get_current_user),
    service: NotificationService = Depends(get_notification_service),
) -> Response:
    await service.deactivate_by_token(token=token, user_id=current_user.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ---------------------------------------------------------------------------
# Notification Preferences Endpoints
# ---------------------------------------------------------------------------

@router.get(
    "/preferences",
    response_model=ApiResponse[NotificationPreferencesResponse],
    status_code=status.HTTP_200_OK,
    summary="Get notification preferences",
    description="Returns user preferences for push notifications and categories.",
)
async def get_preferences(
    current_user: User = Depends(get_current_user),
    service: NotificationService = Depends(get_notification_service),
) -> ApiResponse[NotificationPreferencesResponse]:
    pref = await service.get_preferences(user_id=current_user.id)
    return ApiResponse(data=NotificationPreferencesResponse.model_validate(pref))


@router.put(
    "/preferences",
    response_model=ApiResponse[NotificationPreferencesResponse],
    status_code=status.HTTP_200_OK,
    summary="Update notification preferences",
    description="Updates user notification preferences and category toggles.",
)
async def update_preferences(
    body: NotificationPreferencesUpdate,
    current_user: User = Depends(get_current_user),
    service: NotificationService = Depends(get_notification_service),
) -> ApiResponse[NotificationPreferencesResponse]:
    pref = await service.update_preferences(user_id=current_user.id, update_data=body)
    return ApiResponse(data=NotificationPreferencesResponse.model_validate(pref))


# ---------------------------------------------------------------------------
# Notification History & Read State Endpoints
# ---------------------------------------------------------------------------

@router.get(
    "",
    response_model=ApiResponse[NotificationListResponse],
    status_code=status.HTTP_200_OK,
    summary="List notifications",
    description="Returns paginated notifications for the current user.",
)
async def list_notifications(
    skip: int = Query(0, ge=0, description="Offset for pagination"),
    limit: int = Query(50, ge=1, le=100, description="Page limit"),
    is_read: Optional[bool] = Query(None, description="Filter by read status"),
    current_user: User = Depends(get_current_user),
    service: NotificationService = Depends(get_notification_service),
) -> ApiResponse[NotificationListResponse]:
    items, total = await service.list_notifications(
        user_id=current_user.id,
        skip=skip,
        limit=limit,
        is_read=is_read,
    )
    res_items = [NotificationItemResponse.model_validate(item) for item in items]
    return ApiResponse(
        data=NotificationListResponse(
            items=res_items,
            total=total,
            skip=skip,
            limit=limit,
        )
    )


@router.get(
    "/unread-count",
    response_model=ApiResponse[UnreadCountResponse],
    status_code=status.HTTP_200_OK,
    summary="Get unread notification count",
    description="Returns the total count of unread notifications for badge display.",
)
async def get_unread_count(
    current_user: User = Depends(get_current_user),
    service: NotificationService = Depends(get_notification_service),
) -> ApiResponse[UnreadCountResponse]:
    count = await service.get_unread_count(user_id=current_user.id)
    return ApiResponse(data=UnreadCountResponse(unread_count=count))


@router.patch(
    "/{notification_id}/read",
    response_model=ApiResponse[NotificationItemResponse],
    status_code=status.HTTP_200_OK,
    summary="Mark notification as read",
    description="Marks a specific notification as read.",
)
async def mark_notification_as_read(
    notification_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    service: NotificationService = Depends(get_notification_service),
) -> ApiResponse[NotificationItemResponse]:
    notification = await service.mark_as_read(
        notification_id=notification_id,
        user_id=current_user.id,
    )
    if not notification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found",
        )
    return ApiResponse(data=NotificationItemResponse.model_validate(notification))


@router.post(
    "/read-all",
    response_model=ApiResponse[ReadAllResponse],
    status_code=status.HTTP_200_OK,
    summary="Mark all notifications as read",
    description="Marks all unread notifications for the user as read in bulk.",
)
async def mark_all_as_read(
    current_user: User = Depends(get_current_user),
    service: NotificationService = Depends(get_notification_service),
) -> ApiResponse[ReadAllResponse]:
    marked_count = await service.mark_all_as_read(user_id=current_user.id)
    return ApiResponse(data=ReadAllResponse(marked_count=marked_count))
