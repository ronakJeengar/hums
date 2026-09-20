import logging
import os
import uuid
from typing import List, Optional, Tuple
from app.core.config import get_settings
from app.core.errors import AppException, BadRequestError, NotFoundError
from app.db.models.audio import AudioFile, ProcessingJob, Track
from app.repositories.audio_repository import (
    AudioFileRepository,
    ProcessingJobRepository,
    TrackRepository,
)
from app.schemas.audio import TrackStatusResponse
from app.utils.storage import BaseStorageService

logger = logging.getLogger("hums.audio")
settings = get_settings()


def detect_and_validate_audio(
    content: bytes,
    filename: Optional[str] = None,
    declared_mime: Optional[str] = None,
) -> Tuple[str, str]:
    """
    Validates audio file size, MIME type, and magic bytes / audio headers.
    Returns canonical extension (without leading dot) and detected MIME type.
    """
    max_bytes = settings.MAX_AUDIO_SIZE_MB * 1024 * 1024
    if len(content) > max_bytes:
        raise BadRequestError(
            f"Audio file exceeds maximum allowed size of {settings.MAX_AUDIO_SIZE_MB}MB.",
            code="AUDIO_TOO_LARGE",
        )
    if len(content) < 100:
        raise BadRequestError(
            "Audio file is too small or empty.",
            code="INVALID_AUDIO_FILE",
        )

    # Magic bytes check
    canonical_ext: Optional[str] = None
    detected_mime: Optional[str] = None

    # 1. MP3 check:
    # ID3v2 tag starts with 'ID3'
    # MPEG sync words: 0xFF followed by 0xFB, 0xF3, 0xF2, 0xFA, 0xE3
    if content[:3] == b"ID3" or (len(content) >= 2 and content[0] == 0xFF and (content[1] & 0xE0) == 0xE0):
        canonical_ext = "mp3"
        detected_mime = "audio/mpeg"
    elif b"ID3" in content[:64]:
        canonical_ext = "mp3"
        detected_mime = "audio/mpeg"

    # 2. WAV check: RIFF....WAVE
    elif content[:4] == b"RIFF" and len(content) >= 12 and content[8:12] == b"WAVE":
        canonical_ext = "wav"
        detected_mime = "audio/wav"

    # 3. FLAC check: 'fLaC'
    elif content[:4] == b"fLaC":
        canonical_ext = "flac"
        detected_mime = "audio/flac"

    # 4. OGG check: 'OggS'
    elif content[:4] == b"OggS":
        canonical_ext = "ogg"
        detected_mime = "audio/ogg"

    # 5. MP4 / M4A container check: bytes 4-8 == 'ftyp'
    elif len(content) >= 8 and content[4:8] == b"ftyp":
        canonical_ext = "m4a"
        detected_mime = "audio/mp4"

    # 6. Raw AAC ADTS syncword check: 0xFFF1 or 0xFFF9
    elif len(content) >= 2 and content[:2] in (b"\xff\xf1", b"\xff\xf9"):
        canonical_ext = "aac"
        detected_mime = "audio/aac"

    # Fallback validation: if declared_mime or filename extension matches allowed audio types
    # and first 1024 bytes contain an audio sync or header
    if not canonical_ext:
        ext = os.path.splitext(filename or "")[1].lower().lstrip(".")
        if ext in ("mp3", "wav", "flac", "ogg", "m4a", "aac"):
            # Check if any MPEG sync word appears within the first 1024 bytes
            found_sync = False
            for i in range(min(len(content) - 1, 1024)):
                if content[i] == 0xFF and (content[i + 1] & 0xE0) == 0xE0:
                    found_sync = True
                    break
            if found_sync:
                canonical_ext = ext if ext in ("mp3", "aac") else "mp3"
                detected_mime = "audio/mpeg" if canonical_ext == "mp3" else "audio/aac"

    if not canonical_ext or not detected_mime:
        raise BadRequestError(
            "Uploaded file is not a valid audio file or format is unsupported. Allowed formats: MP3, WAV, FLAC, M4A, AAC, OGG.",
            code="INVALID_AUDIO_FORMAT",
        )

    if detected_mime not in settings.ALLOWED_AUDIO_MIME_TYPES:
        raise BadRequestError(
            f"MIME type '{detected_mime}' is not permitted.",
            code="INVALID_AUDIO_FORMAT",
        )

    return canonical_ext, detected_mime


class AudioService:
    """Service managing audio track uploads, metadata persistence, and processing jobs."""

    def __init__(
        self,
        track_repo: TrackRepository,
        audio_file_repo: AudioFileRepository,
        processing_job_repo: ProcessingJobRepository,
        storage_service: BaseStorageService,
    ):
        self.track_repo = track_repo
        self.audio_file_repo = audio_file_repo
        self.processing_job_repo = processing_job_repo
        self.storage_service = storage_service

    async def upload_audio(
        self,
        user_id: uuid.UUID,
        file_bytes: bytes,
        filename: str,
        content_type: str,
        title: str,
        description: Optional[str] = None,
        artist_name: Optional[str] = None,
        album_name: Optional[str] = None,
        genre: Optional[str] = None,
    ) -> Track:
        """
        Validates, uploads, and registers an audio track and its initial processing job.
        """
        if not title or not title.strip():
            raise BadRequestError("Track title is required.", code="INVALID_TRACK_DATA")

        clean_title = title.strip()
        if len(clean_title) > 255:
            raise BadRequestError(
                "Track title cannot exceed 255 characters.",
                code="INVALID_TRACK_DATA",
            )

        canonical_ext, detected_mime = detect_and_validate_audio(
            file_bytes, filename, content_type
        )

        track_id = uuid.uuid4()
        file_uuid = uuid.uuid4()
        # Storage key convention: audio/original/{user_id}/{track_id}/{file_uuid}.{ext}
        object_key = f"audio/original/{user_id}/{track_id}/{file_uuid}.{canonical_ext}"

        # Upload binary stream to object storage
        try:
            await self.storage_service.upload_file(
                file_bytes=file_bytes,
                destination_key=object_key,
                content_type=detected_mime,
            )
        except Exception as exc:
            logger.error(f"Failed to upload audio to object storage: {exc}")
            raise AppException(
                "Failed to store audio file in object storage.",
                code="STORAGE_ERROR",
                status_code=500,
            )

        # Create database records transactionally
        try:
            track = await self.track_repo.create(
                id=track_id,
                owner_id=user_id,
                title=clean_title,
                description=description.strip() if description and description.strip() else None,
                artist_name=artist_name.strip() if artist_name and artist_name.strip() else None,
                album_name=album_name.strip() if album_name and album_name.strip() else None,
                genre=genre.strip() if genre and genre.strip() else None,
                status="UPLOADED",
            )
            await self.audio_file_repo.create(
                id=file_uuid,
                track_id=track_id,
                object_key=object_key,
                storage_provider="s3",
                original_filename=os.path.basename(filename or f"track.{canonical_ext}"),
                mime_type=detected_mime,
                file_size_bytes=len(file_bytes),
            )
            await self.processing_job_repo.create(
                track_id=track_id,
                job_type="AUDIO_TRANSCODE",
                status="PENDING",
                attempts=0,
            )

            refreshed_track = await self.track_repo.get_by_id_with_relations(track_id)

            # Dispatch Celery background processing task
            try:
                from app.workers.audio_tasks import process_audio_track
                process_audio_track.delay(str(track_id))
                logger.info(f"Enqueued background processing task for track {track_id}")
            except Exception as queue_exc:
                logger.warning(
                    f"Could not enqueue background processing task for track {track_id}: {queue_exc}"
                )

            return refreshed_track or track
        except Exception as exc:
            logger.error(f"Database error while saving track: {exc}", exc_info=True)
            # Cleanup uploaded storage object to prevent orphan files
            await self.storage_service.delete_file(object_key)
            raise

    async def list_user_tracks(
        self, user_id: uuid.UUID, skip: int = 0, limit: int = 50
    ) -> List[Track]:
        """Retrieves all tracks owned by the specified user."""
        return await self.track_repo.list_by_owner(user_id, skip=skip, limit=limit)

    async def get_user_track(self, track_id: uuid.UUID, user_id: uuid.UUID) -> Track:
        """Retrieves a track by ID, enforcing user ownership."""
        track = await self.track_repo.get_by_id_and_owner(track_id, user_id)
        if not track:
            raise NotFoundError("Track not found", details={"track_id": str(track_id)})
        return track

    async def get_processing_job(
        self, job_id: uuid.UUID, user_id: uuid.UUID
    ) -> ProcessingJob:
        """Retrieves a processing job by ID, verifying track ownership."""
        job = await self.processing_job_repo.get_by_id_with_track(job_id)
        if not job or not job.track or job.track.owner_id != user_id:
            raise NotFoundError(
                "Processing job not found", details={"job_id": str(job_id)}
            )
        return job

    async def get_track_status(
        self, track_id: uuid.UUID, user_id: uuid.UUID
    ) -> TrackStatusResponse:
        """Returns the processing and upload status of a track."""
        track = await self.get_user_track(track_id, user_id)
        latest_job = track.processing_jobs[0] if track.processing_jobs else None

        return TrackStatusResponse(
            track_id=track.id,
            title=track.title,
            status=track.status,
            duration_seconds=track.duration_seconds,
            waveform_key=track.waveform_key,
            processing_job_id=latest_job.id if latest_job else None,
            processing_status=latest_job.status if latest_job else None,
            error_message=latest_job.error_message if latest_job else None,
            updated_at=track.updated_at,
        )

    async def get_track_waveform(
        self, track_id: uuid.UUID, user_id: uuid.UUID
    ) -> List[float]:
        """Retrieves normalized waveform sample points for a track."""
        import json
        track = await self.get_user_track(track_id, user_id)
        if not track.waveform_key:
            return []

        try:
            waveform_bytes = await self.storage_service.download_file(track.waveform_key)
            return json.loads(waveform_bytes.decode("utf-8"))
        except Exception as exc:
            logger.warning(f"Failed to load waveform for track {track_id}: {exc}")
            return []

