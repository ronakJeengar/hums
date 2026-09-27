import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status

from app.core.dependencies import get_optional_current_user, get_player_service
from app.core.errors import BadRequestError
from app.db.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.queue import TrackResolveResponse, UpNextResponse
from app.services.player_service import PlayerService

router = APIRouter()


@router.get(
    "/up-next",
    response_model=ApiResponse[UpNextResponse],
    status_code=status.HTTP_200_OK,
    summary="Get Smart Queue & Up Next candidates",
    description="Provides intelligent, continuous playback candidates based on currently playing track, user preferences, and platform discovery signals.",
)
async def get_up_next(
    current_track_id: Optional[uuid.UUID] = Query(None, description="UUID of the track currently being played"),
    limit: int = Query(10, ge=1, le=50, description="Number of up-next candidates to retrieve"),
    exclude_ids: Optional[str] = Query(None, description="Comma-separated track UUIDs to exclude from candidates"),
    current_user: Optional[User] = Depends(get_optional_current_user),
    player_service: PlayerService = Depends(get_player_service),
) -> ApiResponse[UpNextResponse]:
    parsed_exclude_ids: List[uuid.UUID] = []
    if exclude_ids:
        raw_parts = [p.strip() for p in exclude_ids.split(",") if p.strip()]
        if len(raw_parts) > 100:
            raise BadRequestError(
                "Cannot exclude more than 100 track IDs per request",
                code="EXCESSIVE_EXCLUSION_SIZE",
            )
        for part in raw_parts:
            try:
                parsed_exclude_ids.append(uuid.UUID(part))
            except ValueError:
                raise BadRequestError(
                    f"Invalid track UUID in exclude_ids: {part}",
                    code="INVALID_UUID",
                )

    up_next_data = await player_service.get_up_next(
        user=current_user,
        current_track_id=current_track_id,
        limit=limit,
        exclude_ids=parsed_exclude_ids,
    )
    return ApiResponse(data=up_next_data)


@router.get(
    "/resolve",
    response_model=ApiResponse[TrackResolveResponse],
    status_code=status.HTTP_200_OK,
    summary="Resolve batch track metadata for player queue",
    description="Resolves full playable metadata for a comma-separated list of track UUIDs.",
)
async def resolve_queue_tracks(
    track_ids: str = Query(..., description="Comma-separated track UUIDs to resolve"),
    player_service: PlayerService = Depends(get_player_service),
) -> ApiResponse[TrackResolveResponse]:
    raw_parts = [p.strip() for p in track_ids.split(",") if p.strip()]
    if not raw_parts:
        return ApiResponse(data=TrackResolveResponse(items=[]))

    if len(raw_parts) > 100:
        raise BadRequestError(
            "Cannot resolve more than 100 tracks per batch",
            code="EXCESSIVE_BATCH_SIZE",
        )

    parsed_ids: List[uuid.UUID] = []
    for part in raw_parts:
        try:
            parsed_ids.append(uuid.UUID(part))
        except ValueError:
            raise BadRequestError(
                f"Invalid track UUID format: {part}",
                code="INVALID_UUID",
            )

    resolved = await player_service.resolve_tracks(parsed_ids)
    return ApiResponse(data=resolved)
