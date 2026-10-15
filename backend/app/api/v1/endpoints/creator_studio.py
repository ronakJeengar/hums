import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional
from fastapi import APIRouter, Depends, File, Query, UploadFile, status

from app.core.config import get_settings
from app.core.dependencies import (
    get_creator_studio_service,
    get_current_user,
    require_creator_role,
)
from app.core.errors import BadRequestError
from app.db.models.user import User
from app.schemas.admin import (
    CreateCreatorApplicationRequest,
    CreatorApplicationItem,
)
from app.schemas.common import ApiResponse
from app.schemas.creator_studio import (
    BulkTrackActionResult,
    CreatorAnalyticsResponse,
    CreatorBulkTrackActionRequest,
    CreatorDashboardStats,
    CreatorStudioProfile,
    CreatorTrackDetail,
    CreatorTrackItem,
    SetPublishingRequest,
    TrackArtworkUploadResponse,
    UpdateCreatorProfileRequest,
    UpdateTrackRequest,
)
from app.services.creator_studio_service import CreatorStudioService
from app.utils.upload import read_upload_file_bounded

settings = get_settings()

router = APIRouter(prefix="/creator-studio", tags=["Creator Studio"])
applications_router = APIRouter(prefix="/creator-applications", tags=["Creator Applications"])


# ============================================================================
# 1. Studio Dashboard
# ============================================================================

@router.get(
    "/dashboard",
    response_model=ApiResponse[CreatorDashboardStats],
    status_code=status.HTTP_200_OK,
    summary="Get creator overview dashboard statistics",
)
async def get_dashboard(
    current_user: User = Depends(require_creator_role),
    studio_service: CreatorStudioService = Depends(get_creator_studio_service),
) -> ApiResponse[CreatorDashboardStats]:
    """Retrieves track stats, play totals, followers, and top/recent uploads."""
    stats = await studio_service.get_dashboard(current_user.id)
    return ApiResponse(data=stats)


# ============================================================================
# 2. Track Management
# ============================================================================

@router.get(
    "/tracks",
    response_model=ApiResponse[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="List tracks owned by current creator",
)
async def list_tracks(
    page: int = Query(1, ge=1),
    size: int = Query(20, ge=1, le=100),
    status_filter: Optional[str] = Query(None, alias="status"),
    search: Optional[str] = Query(None),
    is_published: Optional[bool] = Query(None),
    genre: Optional[str] = Query(None),
    date_from: Optional[datetime] = Query(None),
    date_to: Optional[datetime] = Query(None),
    sort_by: str = Query("created_at", pattern="^(created_at|title|duration_seconds|play_count)$"),
    sort_order: str = Query("desc", pattern="^(asc|desc)$"),
    current_user: User = Depends(require_creator_role),
    studio_service: CreatorStudioService = Depends(get_creator_studio_service),
) -> ApiResponse[Dict[str, Any]]:
    """Paginated list of tracks with play/like counts and status."""
    items, total = await studio_service.list_tracks(
        user_id=current_user.id,
        page=page,
        size=size,
        status=status_filter,
        search=search,
        is_published=is_published,
        genre=genre,
        date_from=date_from,
        date_to=date_to,
        sort_by=sort_by,
        sort_order=sort_order,
    )
    return ApiResponse(
        data={
            "items": [t.model_dump() for t in items],
            "total": total,
            "page": page,
            "size": size,
            "total_pages": (total + size - 1) // size if total > 0 else 1,
        }
    )


@router.get(
    "/tracks/{track_id}",
    response_model=ApiResponse[CreatorTrackDetail],
    status_code=status.HTTP_200_OK,
    summary="Get creator track details with audio renditions and processing jobs",
)
async def get_track_detail(
    track_id: uuid.UUID,
    current_user: User = Depends(require_creator_role),
    studio_service: CreatorStudioService = Depends(get_creator_studio_service),
) -> ApiResponse[CreatorTrackDetail]:
    """Retrieves full track details including audio files, renditions, and background jobs."""
    detail = await studio_service.get_track_detail(
        user_id=current_user.id,
        track_id=track_id,
    )
    return ApiResponse(data=detail)


@router.patch(
    "/tracks/{track_id}",
    response_model=ApiResponse[CreatorTrackItem],
    status_code=status.HTTP_200_OK,
    summary="Update track metadata",
)
async def update_track(
    track_id: uuid.UUID,
    payload: UpdateTrackRequest,
    current_user: User = Depends(require_creator_role),
    studio_service: CreatorStudioService = Depends(get_creator_studio_service),
) -> ApiResponse[CreatorTrackItem]:
    """Updates title, album, genre, or description for a creator-owned track."""
    update_dict = payload.model_dump(exclude_unset=True)
    item = await studio_service.update_track(
        user_id=current_user.id,
        track_id=track_id,
        update_data=update_dict,
    )
    return ApiResponse(data=item)


@router.patch(
    "/tracks/{track_id}/publishing",
    response_model=ApiResponse[CreatorTrackItem],
    status_code=status.HTTP_200_OK,
    summary="Set track publishing status",
)
async def set_publishing(
    track_id: uuid.UUID,
    payload: SetPublishingRequest,
    current_user: User = Depends(require_creator_role),
    studio_service: CreatorStudioService = Depends(get_creator_studio_service),
) -> ApiResponse[CreatorTrackItem]:
    """Publishes or unpublishes a creator track. Track must be READY to publish."""
    item = await studio_service.set_publishing(
        user_id=current_user.id,
        track_id=track_id,
        is_published=payload.is_published,
    )
    return ApiResponse(data=item)


@router.post(
    "/tracks/{track_id}/artwork",
    response_model=ApiResponse[TrackArtworkUploadResponse],
    status_code=status.HTTP_200_OK,
    summary="Upload track artwork",
)
async def upload_artwork(
    track_id: uuid.UUID,
    file: UploadFile = File(...),
    current_user: User = Depends(require_creator_role),
    studio_service: CreatorStudioService = Depends(get_creator_studio_service),
) -> ApiResponse[TrackArtworkUploadResponse]:
    """Uploads and associates cover artwork for an owned track."""
    max_bytes = settings.MAX_AVATAR_SIZE_MB * 1024 * 1024
    content = await read_upload_file_bounded(file, max_bytes=max_bytes)
    res = await studio_service.upload_artwork(
        user_id=current_user.id,
        track_id=track_id,
        file_bytes=content,
        filename=file.filename or "artwork.jpg",
        content_type=file.content_type or "",
    )
    return ApiResponse(data=TrackArtworkUploadResponse.model_validate(res))


@router.post(
    "/tracks/{track_id}/retry",
    response_model=ApiResponse[Dict[str, str]],
    status_code=status.HTTP_200_OK,
    summary="Retry transcoding for a failed track",
)
async def retry_track_processing(
    track_id: uuid.UUID,
    current_user: User = Depends(require_creator_role),
    studio_service: CreatorStudioService = Depends(get_creator_studio_service),
) -> ApiResponse[Dict[str, str]]:
    """Triggers Celery transcode re-processing for an owned failed track."""
    result = await studio_service.retry_processing(
        user_id=current_user.id,
        track_id=track_id,
    )
    return ApiResponse(data=result)


@router.post(
    "/tracks/bulk-action",
    response_model=ApiResponse[BulkTrackActionResult],
    status_code=status.HTTP_200_OK,
    summary="Execute bulk action on creator tracks",
)
async def bulk_action(
    payload: CreatorBulkTrackActionRequest,
    current_user: User = Depends(require_creator_role),
    studio_service: CreatorStudioService = Depends(get_creator_studio_service),
) -> ApiResponse[BulkTrackActionResult]:
    """Executes bulk publish, unpublish, retry, or metadata update on creator-owned tracks."""
    bulk_data = dict(payload.data or {})
    for field in ("genre", "title", "artist_name", "album_name", "description"):
        val = getattr(payload, field, None)
        if val is not None:
            bulk_data[field] = val

    result = await studio_service.bulk_action(
        user_id=current_user.id,
        action=payload.action,
        track_ids=payload.track_ids,
        data=bulk_data,
    )
    return ApiResponse(data=result)


# ============================================================================
# 3. Creator Analytics
# ============================================================================

@router.get(
    "/analytics",
    response_model=ApiResponse[CreatorAnalyticsResponse],
    status_code=status.HTTP_200_OK,
    summary="Get creator listening analytics",
)
async def get_analytics(
    period: str = Query("30d", pattern="^(7d|30d|90d)$"),
    current_user: User = Depends(require_creator_role),
    studio_service: CreatorStudioService = Depends(get_creator_studio_service),
) -> ApiResponse[CreatorAnalyticsResponse]:
    """Returns plays timeline, unique listeners, and top tracks aggregated from playback events."""
    analytics = await studio_service.get_analytics(
        user_id=current_user.id,
        period=period,
    )
    return ApiResponse(data=analytics)


# ============================================================================
# 4. Creator Profile
# ============================================================================

@router.get(
    "/profile",
    response_model=ApiResponse[CreatorStudioProfile],
    status_code=status.HTTP_200_OK,
    summary="Get studio profile for authenticated creator",
)
async def get_profile(
    current_user: User = Depends(require_creator_role),
    studio_service: CreatorStudioService = Depends(get_creator_studio_service),
) -> ApiResponse[CreatorStudioProfile]:
    """Returns profile details, follower counts, and verification badge status."""
    profile = await studio_service.get_profile(current_user.id)
    return ApiResponse(data=profile)


@router.patch(
    "/profile",
    response_model=ApiResponse[CreatorStudioProfile],
    status_code=status.HTTP_200_OK,
    summary="Update studio profile information",
)
async def update_profile(
    payload: UpdateCreatorProfileRequest,
    current_user: User = Depends(require_creator_role),
    studio_service: CreatorStudioService = Depends(get_creator_studio_service),
) -> ApiResponse[CreatorStudioProfile]:
    """Updates artist public name, bio, avatar, or cover artwork."""
    profile = await studio_service.update_profile(
        user_id=current_user.id,
        name=payload.name,
        bio=payload.bio,
        avatar_url=payload.avatar_url,
        cover_image_url=payload.cover_image_url,
    )
    return ApiResponse(data=profile)


# ============================================================================
# 5. Creator Applications (Listener Self-Service)
# ============================================================================

@applications_router.post(
    "",
    response_model=ApiResponse[CreatorApplicationItem],
    status_code=status.HTTP_201_CREATED,
    summary="Submit application to join Creator Program",
)
async def submit_creator_application(
    payload: CreateCreatorApplicationRequest,
    current_user: User = Depends(get_current_user),
    studio_service: CreatorStudioService = Depends(get_creator_studio_service),
) -> ApiResponse[CreatorApplicationItem]:
    """Submits listener application to become an artist/creator on Hums."""
    app = await studio_service.submit_application(
        user_id=current_user.id,
        artist_name=payload.artist_name,
        bio=payload.bio,
        genres=payload.genres,
        portfolio_url=payload.portfolio_url,
    )
    return ApiResponse(
        data=CreatorApplicationItem(
            id=app.id,
            user_id=app.user_id,
            user_email=current_user.email,
            user_name=current_user.name,
            artist_name=app.artist_name,
            bio=app.bio,
            genres=app.genres,
            portfolio_url=app.portfolio_url,
            status=app.status,
            reviewer_id=app.reviewer_id,
            review_notes=app.review_notes,
            created_at=app.created_at,
            reviewed_at=app.reviewed_at,
        )
    )


@applications_router.get(
    "/me",
    response_model=ApiResponse[Optional[CreatorApplicationItem]],
    status_code=status.HTTP_200_OK,
    summary="Check authenticated user's creator application status",
)
async def get_my_creator_application(
    current_user: User = Depends(get_current_user),
    studio_service: CreatorStudioService = Depends(get_creator_studio_service),
) -> ApiResponse[Optional[CreatorApplicationItem]]:
    """Returns the latest application submitted by the logged in user, if any."""
    app = await studio_service.get_my_application(current_user.id)
    if not app:
        return ApiResponse(data=None)

    return ApiResponse(
        data=CreatorApplicationItem(
            id=app.id,
            user_id=app.user_id,
            user_email=current_user.email,
            user_name=current_user.name,
            artist_name=app.artist_name,
            bio=app.bio,
            genres=app.genres,
            portfolio_url=app.portfolio_url,
            status=app.status,
            reviewer_id=app.reviewer_id,
            review_notes=app.review_notes,
            created_at=app.created_at,
            reviewed_at=app.reviewed_at,
        )
    )
