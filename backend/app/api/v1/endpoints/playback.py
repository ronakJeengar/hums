import uuid
from typing import List, Optional, Union
from fastapi import APIRouter, Depends, Query, status
from app.core.dependencies import get_current_user, get_playback_service
from app.core.errors import BadRequestError
from app.core.rate_limit import RateLimiter
from app.db.models.user import User
from app.schemas.common import ApiResponse, MessageData
from app.schemas.playback import (
    ListeningHistoryListResponse,
    PlaybackBatchEventsRequest,
    PlaybackBatchProgressResponse,
    PlaybackEventCreateRequest,
    PlaybackEventsIngestResponse,
    PlaybackProgressResponse,
    PlaybackProgressUpdateRequest,
)
from app.services.playback_service import PlaybackService

router = APIRouter()
history_alias_router = APIRouter()


@router.post(
    "/events",
    response_model=ApiResponse[PlaybackEventsIngestResponse],
    status_code=status.HTTP_200_OK,
    summary="Ingest Playback Events",
    description="Idempotently ingests single or batched playback lifecycle events (e.g. from player checkpoints or offline sync).",
    dependencies=[Depends(RateLimiter(requests=120, window_seconds=60, action="playback_events"))],
)
async def ingest_playback_events(
    payload: Union[PlaybackBatchEventsRequest, PlaybackEventCreateRequest],
    current_user: User = Depends(get_current_user),
    playback_service: PlaybackService = Depends(get_playback_service),
) -> ApiResponse[PlaybackEventsIngestResponse]:
    if isinstance(payload, PlaybackBatchEventsRequest):
        res = await playback_service.record_events_batch(
            user_id=current_user.id, batch=payload
        )
    else:
        res = await playback_service.record_event(
            user_id=current_user.id, event=payload
        )
    return ApiResponse(data=res)


@router.get(
    "/history",
    response_model=ApiResponse[ListeningHistoryListResponse],
    status_code=status.HTTP_200_OK,
    summary="Get User Listening History",
    description="Returns the paginated recently played tracks for the authenticated user, ordered newest first with resume positions.",
)
async def get_listening_history(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    playback_service: PlaybackService = Depends(get_playback_service),
) -> ApiResponse[ListeningHistoryListResponse]:
    history = await playback_service.get_history(
        user_id=current_user.id, skip=skip, limit=limit
    )
    return ApiResponse(data=history)


@router.delete(
    "/history",
    response_model=ApiResponse[MessageData],
    status_code=status.HTTP_200_OK,
    summary="Clear Listening History",
    description="Clears all tracks from the user's active listening history.",
)
async def clear_listening_history(
    current_user: User = Depends(get_current_user),
    playback_service: PlaybackService = Depends(get_playback_service),
) -> ApiResponse[MessageData]:
    count = await playback_service.clear_history(user_id=current_user.id)
    return ApiResponse(data=MessageData(message=f"Cleared {count} items from listening history"))


@router.delete(
    "/history/{track_id}",
    response_model=ApiResponse[MessageData],
    status_code=status.HTTP_200_OK,
    summary="Remove Track from Listening History",
    description="Removes a specific track from the user's listening history.",
)
async def delete_history_item(
    track_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    playback_service: PlaybackService = Depends(get_playback_service),
) -> ApiResponse[MessageData]:
    deleted = await playback_service.delete_history_item(
        user_id=current_user.id, track_id=track_id
    )
    if not deleted:
        return ApiResponse(data=MessageData(message="Track not found in listening history"))
    return ApiResponse(data=MessageData(message="Track removed from listening history"))


@router.get(
    "/progress/{track_id}",
    response_model=ApiResponse[PlaybackProgressResponse],
    status_code=status.HTTP_200_OK,
    summary="Get Track Playback Progress",
    description="Retrieves the saved playback position, duration, and completion status for a track.",
)
async def get_track_progress(
    track_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    playback_service: PlaybackService = Depends(get_playback_service),
) -> ApiResponse[PlaybackProgressResponse]:
    progress = await playback_service.get_progress(
        user_id=current_user.id, track_id=track_id
    )
    return ApiResponse(data=progress)


@router.get(
    "/progress",
    response_model=ApiResponse[PlaybackBatchProgressResponse],
    status_code=status.HTTP_200_OK,
    summary="Batch Lookup Track Progress",
    description="Retrieves playback resume positions for a comma-separated list of track UUIDs.",
)
async def get_batch_track_progress(
    track_ids: Optional[str] = Query(None, description="Comma-separated track UUIDs"),
    current_user: User = Depends(get_current_user),
    playback_service: PlaybackService = Depends(get_playback_service),
) -> ApiResponse[PlaybackBatchProgressResponse]:
    if not track_ids:
        return ApiResponse(data=PlaybackBatchProgressResponse(items=[]))

    parsed_ids: List[uuid.UUID] = []
    for raw_id in track_ids.split(","):
        cleaned = raw_id.strip()
        if cleaned:
            try:
                parsed_ids.append(uuid.UUID(cleaned))
            except ValueError:
                raise BadRequestError(
                    f"Invalid track UUID format: {cleaned}",
                    code="INVALID_UUID",
                )

    if len(parsed_ids) > 100:
        raise BadRequestError(
            "Cannot query more than 100 track progress states per request",
            code="EXCESSIVE_BATCH_SIZE",
        )

    res = await playback_service.get_progress_batch(
        user_id=current_user.id, track_ids=parsed_ids
    )
    return ApiResponse(data=res)


@router.put(
    "/progress/{track_id}",
    response_model=ApiResponse[PlaybackProgressResponse],
    status_code=status.HTTP_200_OK,
    summary="Update Track Playback Progress",
    description="Direct checkpoint update of playback position and completion status.",
    dependencies=[Depends(RateLimiter(requests=120, window_seconds=60, action="playback_progress_update"))],
)
async def update_track_progress(
    track_id: uuid.UUID,
    payload: PlaybackProgressUpdateRequest,
    current_user: User = Depends(get_current_user),
    playback_service: PlaybackService = Depends(get_playback_service),
) -> ApiResponse[PlaybackProgressResponse]:
    progress = await playback_service.update_progress(
        user_id=current_user.id,
        track_id=track_id,
        payload=payload,
    )
    return ApiResponse(data=progress)


# ==========================================
# History Aliases (/api/v1/history)
# ==========================================
history_alias_router.add_api_route(
    "/history",
    get_listening_history,
    methods=["GET"],
    response_model=ApiResponse[ListeningHistoryListResponse],
    summary="Get User Listening History (Alias)",
    tags=["history"],
)
history_alias_router.add_api_route(
    "/history",
    clear_listening_history,
    methods=["DELETE"],
    response_model=ApiResponse[MessageData],
    summary="Clear Listening History (Alias)",
    tags=["history"],
)
history_alias_router.add_api_route(
    "/history/{track_id}",
    delete_history_item,
    methods=["DELETE"],
    response_model=ApiResponse[MessageData],
    summary="Remove Track from Listening History (Alias)",
    tags=["history"],
)
