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


class AudioRenditionResponse(BaseModel):
    """Processed audio rendition response schema."""
    id: uuid.UUID
    track_id: uuid.UUID
    storage_key: str
    storage_provider: str
    format: str
    codec: str
    bitrate_kbps: int
    sample_rate: Optional[int] = None
    channels: Optional[int] = None
    duration_seconds: Optional[int] = None
    file_size_bytes: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TrackResponse(BaseModel):
    """Complete audio track response schema with associated files, renditions, and jobs."""
    id: uuid.UUID
    owner_id: uuid.UUID
    title: str
    description: Optional[str] = None
    artist_name: Optional[str] = None
    album_name: Optional[str] = None
    genre: Optional[str] = None
    duration_seconds: Optional[int] = None
    waveform_key: Optional[str] = None
    status: str
    created_at: datetime
    updated_at: datetime
    audio_files: List[AudioFileResponse] = []
    processing_jobs: List[ProcessingJobResponse] = []
    renditions: List[AudioRenditionResponse] = []

    model_config = ConfigDict(from_attributes=True)


class TrackStatusResponse(BaseModel):
    """Lightweight track upload and processing status response schema."""
    track_id: uuid.UUID
    title: str
    status: str
    duration_seconds: Optional[int] = None
    waveform_key: Optional[str] = None
    processing_job_id: Optional[uuid.UUID] = None
    processing_status: Optional[str] = None
    error_message: Optional[str] = None
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class WaveformResponse(BaseModel):
    """Normalized waveform data response schema."""
    track_id: uuid.UUID
    samples: List[float] = Field(..., description="Array of normalized amplitude floats [0.0, 1.0]")

    model_config = ConfigDict(from_attributes=True)


class AudioPlaybackSourceResponse(BaseModel):
    """Playable audio rendition source details."""
    url: str
    format: str
    codec: str
    bitrate_kbps: int
    duration_seconds: Optional[int] = None
    file_size_bytes: int


class TrackPlaybackResponse(BaseModel):
    """Complete playback source response for player consumption."""
    track_id: uuid.UUID
    title: str
    artist_name: Optional[str] = None
    album_name: Optional[str] = None
    genre: Optional[str] = None
    duration_seconds: Optional[int] = None
    status: str
    audio: AudioPlaybackSourceResponse
    waveform_samples: List[float] = []

    model_config = ConfigDict(from_attributes=True)


class TrackDownloadResponse(BaseModel):
    """Authorized track download resource response."""
    track_id: uuid.UUID
    title: str
    artist_name: Optional[str] = None
    album_name: Optional[str] = None
    genre: Optional[str] = None
    duration_seconds: Optional[int] = None
    status: str
    format: str
    codec: str
    bitrate_kbps: int
    file_size_bytes: int
    download_url: str
    expires_at: datetime
    waveform_samples: List[float] = []

    model_config = ConfigDict(from_attributes=True)



