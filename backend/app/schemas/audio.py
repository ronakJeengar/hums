import uuid
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class AudioFileResponse(BaseModel):
    """Audio file asset metadata response schema."""
    id: uuid.UUID
    track_id: uuid.UUID
    object_key: str
    storage_provider: str
    original_filename: str
    mime_type: str
    file_size_bytes: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ProcessingJobResponse(BaseModel):
    """Asynchronous media processing job response schema."""
    id: uuid.UUID
    track_id: uuid.UUID
    job_type: str
    status: str
    attempts: int
    error_message: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TrackResponse(BaseModel):
    """Complete audio track response schema with associated files and jobs."""
    id: uuid.UUID
    owner_id: uuid.UUID
    title: str
    description: Optional[str] = None
    artist_name: Optional[str] = None
    album_name: Optional[str] = None
    genre: Optional[str] = None
    duration_seconds: Optional[int] = None
    status: str
    created_at: datetime
    updated_at: datetime
    audio_files: List[AudioFileResponse] = []
    processing_jobs: List[ProcessingJobResponse] = []

    model_config = ConfigDict(from_attributes=True)


class TrackStatusResponse(BaseModel):
    """Lightweight track upload and processing status response schema."""
    track_id: uuid.UUID
    title: str
    status: str
    processing_job_id: Optional[uuid.UUID] = None
    processing_status: Optional[str] = None
    error_message: Optional[str] = None
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
