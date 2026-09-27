import uuid
import logging
from fastapi import APIRouter, Depends, status

from app.core.dependencies import get_current_user, get_lyrics_service, get_optional_current_user
from app.core.rate_limit import RateLimiter
from app.db.models.user import User
from app.schemas.common import ApiResponse
from app.schemas.lyrics import (
    LyricsCreateRequest,
    LyricsGenerateResponse,
    LyricsResponse,
)
from app.services.lyrics_service import LyricsService
from app.workers.lyrics_tasks import generate_track_lyrics

logger = logging.getLogger("hums.endpoints.lyrics")

router = APIRouter()


@router.get(
    "/{track_id}/lyrics",
    response_model=ApiResponse[LyricsResponse],
    status_code=status.HTTP_200_OK,
    summary="Get track lyrics",
    description="Retrieves plain or synchronized lyrics for a track. Results are cached in Redis.",
    dependencies=[Depends(RateLimiter(requests=60, window_seconds=60, action="get_lyrics"))],
)
async def get_track_lyrics(
    track_id: uuid.UUID,
    lyrics_service: LyricsService = Depends(get_lyrics_service),
    current_user: User | None = Depends(get_optional_current_user),
) -> ApiResponse[LyricsResponse]:
    lyrics_response = await lyrics_service.get_lyrics(track_id)
    return ApiResponse(data=lyrics_response)


@router.post(
    "/{track_id}/lyrics/generate",
    response_model=ApiResponse[LyricsGenerateResponse],
    status_code=status.HTTP_202_ACCEPTED,
    summary="Trigger AI lyrics generation",
    description="Enqueues asynchronous AI lyrics generation for a track via background Celery worker.",
    dependencies=[Depends(RateLimiter(requests=5, window_seconds=60, action="generate_lyrics"))],
)
async def generate_lyrics(
    track_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    lyrics_service: LyricsService = Depends(get_lyrics_service),
) -> ApiResponse[LyricsGenerateResponse]:
    # Enqueue background Celery task
    generate_track_lyrics.delay(str(track_id))
    return ApiResponse(
        data=LyricsGenerateResponse(
            track_id=track_id,
            status="PROCESSING",
            message="Lyrics generation queued",
        )
    )


@router.post(
    "/{track_id}/lyrics",
    response_model=ApiResponse[LyricsResponse],
    status_code=status.HTTP_200_OK,
    summary="Upload or update track lyrics",
    description="Allows track owners to upload plain or synchronized lyrics with timestamps.",
    dependencies=[Depends(RateLimiter(requests=10, window_seconds=60, action="upload_lyrics"))],
)
async def upload_lyrics(
    track_id: uuid.UUID,
    request: LyricsCreateRequest,
    current_user: User = Depends(get_current_user),
    lyrics_service: LyricsService = Depends(get_lyrics_service),
) -> ApiResponse[LyricsResponse]:
    lyrics_response = await lyrics_service.save_manual_lyrics(
        track_id=track_id,
        user_id=current_user.id,
        request=request,
    )
    return ApiResponse(data=lyrics_response)
