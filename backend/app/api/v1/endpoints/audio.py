import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, Query, UploadFile, status
from app.core.dependencies import get_current_user, get_audio_service
from app.db.models.user import User
from app.schemas.audio import (
    ProcessingJobResponse,
    TrackResponse,
    TrackStatusResponse,
    WaveformResponse,
)
from app.schemas.common import ApiResponse
from app.services.audio_service import AudioService

router = APIRouter()


@router.post(
    "/upload",
    response_model=ApiResponse[TrackResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Upload audio track",
    description="Validates and uploads an audio file (MP3, WAV, FLAC, M4A, AAC, OGG up to 100MB) with metadata and queues processing.",
)
async def upload_audio(
    file: UploadFile = File(...),
    title: str = Form(...),
    description: Optional[str] = Form(None),
    artist_name: Optional[str] = Form(None),
    album_name: Optional[str] = Form(None),
    genre: Optional[str] = Form(None),
    current_user: User = Depends(get_current_user),
    audio_service: AudioService = Depends(get_audio_service),
) -> ApiResponse[TrackResponse]:
    content = await file.read()
    track = await audio_service.upload_audio(
        user_id=current_user.id,
        file_bytes=content,
        filename=file.filename or "track.mp3",
        content_type=file.content_type or "audio/mpeg",
        title=title,
        description=description,
        artist_name=artist_name,
        album_name=album_name,
        genre=genre,
    )
    return ApiResponse(data=TrackResponse.model_validate(track))


@router.get(
    "/tracks",
    response_model=ApiResponse[List[TrackResponse]],
    status_code=status.HTTP_200_OK,
    summary="List uploaded tracks",
    description="Returns a paginated list of audio tracks uploaded by the currently authenticated user.",
)
async def list_tracks(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    audio_service: AudioService = Depends(get_audio_service),
) -> ApiResponse[List[TrackResponse]]:
    tracks = await audio_service.list_user_tracks(
        user_id=current_user.id, skip=skip, limit=limit
    )
    return ApiResponse(data=[TrackResponse.model_validate(t) for t in tracks])


@router.get(
    "/tracks/{track_id}",
    response_model=ApiResponse[TrackResponse],
    status_code=status.HTTP_200_OK,
    summary="Get track details",
    description="Retrieves track metadata, audio files, and processing jobs for a track owned by the user.",
)
async def get_track(
    track_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    audio_service: AudioService = Depends(get_audio_service),
) -> ApiResponse[TrackResponse]:
    track = await audio_service.get_user_track(
        track_id=track_id, user_id=current_user.id
    )
    return ApiResponse(data=TrackResponse.model_validate(track))


@router.get(
    "/tracks/{track_id}/status",
    response_model=ApiResponse[TrackStatusResponse],
    status_code=status.HTTP_200_OK,
    summary="Get track processing status",
    description="Retrieves the upload and asynchronous processing status for a track.",
)
async def get_track_status(
    track_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    audio_service: AudioService = Depends(get_audio_service),
) -> ApiResponse[TrackStatusResponse]:
    track_status = await audio_service.get_track_status(
        track_id=track_id, user_id=current_user.id
    )
    return ApiResponse(data=track_status)


@router.get(
    "/tracks/{track_id}/waveform",
    response_model=ApiResponse[WaveformResponse],
    status_code=status.HTTP_200_OK,
    summary="Get track waveform",
    description="Retrieves the 200 normalized amplitude points for a processed audio track.",
)
async def get_track_waveform(
    track_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    audio_service: AudioService = Depends(get_audio_service),
) -> ApiResponse[WaveformResponse]:
    samples = await audio_service.get_track_waveform(
        track_id=track_id, user_id=current_user.id
    )
    return ApiResponse(data=WaveformResponse(track_id=track_id, samples=samples))


@router.get(
    "/jobs/{job_id}",
    response_model=ApiResponse[ProcessingJobResponse],
    status_code=status.HTTP_200_OK,
    summary="Get processing job status",
    description="Retrieves processing job status, attempts, and error details for a job owned by the user.",
)
async def get_processing_job(
    job_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    audio_service: AudioService = Depends(get_audio_service),
) -> ApiResponse[ProcessingJobResponse]:
    job = await audio_service.get_processing_job(
        job_id=job_id, user_id=current_user.id
    )
    return ApiResponse(data=ProcessingJobResponse.model_validate(job))

