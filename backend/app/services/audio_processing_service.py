import logging
import os
import tempfile
import uuid
from typing import List, Optional

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppException
from app.db.database import AsyncSessionLocal
from app.db.models.audio import AudioRendition, ProcessingJob, Track
from app.repositories.audio_repository import (
    AudioFileRepository,
    AudioRenditionRepository,
    ProcessingJobRepository,
    TrackRepository,
)
from app.services.audio_metadata_service import AudioMetadata, AudioMetadataService
from app.services.audio_transcode_service import (
    AudioTranscodeService,
    TranscodeResult,
)
from app.services.waveform_service import WaveformService
from app.utils.storage import BaseStorageService, S3StorageService

logger = logging.getLogger("hums.audio.pipeline")
settings = get_settings()


def sanitize_error_message(exc: Exception) -> str:
    """Sanitizes error messages for user-facing exposure without leaking internal paths or secrets."""
    if isinstance(exc, AppException):
        msg = exc.message
    else:
        msg = str(exc)

    # Strip out any potential absolute paths
    parts = msg.split()
    sanitized_parts = []
    for part in parts:
        if "/" in part and (part.startswith("/tmp") or part.startswith("/var") or part.startswith("/Users") or part.startswith("/app")):
            sanitized_parts.append("[path]")
        else:
            sanitized_parts.append(part)

    clean_msg = " ".join(sanitized_parts)
    if len(clean_msg) > 300:
        clean_msg = clean_msg[:297] + "..."
    return clean_msg or "An error occurred during audio processing."


class AudioProcessingService:
    """
    Coordinates asynchronous audio processing pipeline:
    1. Atomic claim & concurrency check
    2. Download source file from object storage
    3. Metadata extraction (ffprobe)
    4. Waveform generation (ffmpeg PCM sampling)
    5. Audio transcoding to AAC/M4A ladder (ffmpeg)
    6. Upload processed assets to object storage
    7. Database persistence with short transaction boundaries
    8. Guaranteed temp-file cleanup in finally blocks
    """

    def __init__(
        self,
        storage_service: Optional[BaseStorageService] = None,
        metadata_service: Optional[AudioMetadataService] = None,
        waveform_service: Optional[WaveformService] = None,
        transcode_service: Optional[AudioTranscodeService] = None,
    ):
        self.storage_service = storage_service or S3StorageService()
        self.metadata_service = metadata_service or AudioMetadataService()
        self.waveform_service = waveform_service or WaveformService()
        self.transcode_service = transcode_service or AudioTranscodeService(
            metadata_service=self.metadata_service
        )

    async def process_track(self, track_id: uuid.UUID) -> bool:
        """
        Executes the complete audio transcoding pipeline for a single track.

        Returns True if processing succeeded, False if failed or skipped.
        """
        logger.info(f"Initiating audio processing for track {track_id}")

        # --- Phase 1: Atomic Claim & State Validation ---
        claimed_job: Optional[ProcessingJob] = None
        orig_object_key: Optional[str] = None
        orig_filename: Optional[str] = None

        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            audio_file_repo = AudioFileRepository(session)
            job_repo = ProcessingJobRepository(session)

            track = await track_repo.get_by_id(track_id)
            if not track:
                logger.error(f"Track {track_id} not found in database.")
                return False

            if track.status == "READY":
                logger.info(f"Track {track_id} is already READY. Skipping.")
                return True

            claimed_job = await job_repo.claim_job_for_processing(track_id)
            if not claimed_job:
                latest = await job_repo.get_latest_by_track_id(track_id)
                if latest and latest.status == "COMPLETED":
                    logger.info(f"Track {track_id} processing job is already COMPLETED.")
                    return True
                logger.warning(
                    f"Could not claim processing job for track {track_id} (current status: {latest.status if latest else 'None'}). Another worker may be processing."
                )
                return False

            # Update track status to PROCESSING
            await track_repo.update_status(track, "PROCESSING")
            await session.commit()

            # Retrieve original audio file reference
            orig_file = await audio_file_repo.get_original_by_track_id(track_id)
            if not orig_file:
                logger.error(f"No original audio file record found for track {track_id}")
                await self._mark_job_failed(track_id, "No original audio file found.")
                return False

            orig_object_key = orig_file.object_key
            orig_filename = orig_file.original_filename

        # --- Phase 2: Processing with Temp Directory & FFmpeg ---
        with tempfile.TemporaryDirectory(prefix=f"hums_transcode_{track_id}_") as temp_dir:
            try:
                # 1. Download original audio file
                _, ext = os.path.splitext(orig_filename)
                local_orig_path = os.path.join(temp_dir, f"original{ext or '.audio'}")

                logger.info(f"Downloading original audio {orig_object_key} to {local_orig_path}")
                await self.storage_service.download_file_to_path(
                    object_key=orig_object_key,
                    destination_path=local_orig_path,
                )

                # 2. Extract metadata
                logger.info(f"Extracting metadata with ffprobe for track {track_id}")
                metadata: AudioMetadata = self.metadata_service.extract_metadata(local_orig_path)
                duration_sec = int(round(metadata.duration_seconds))

                # 3. Generate waveform
                logger.info(f"Generating waveform for track {track_id}")
                waveform_samples: List[float] = self.waveform_service.generate_waveform(local_orig_path)
                waveform_json: str = self.waveform_service.to_json(waveform_samples)

                waveform_key = f"audio/waveforms/{track_id}.json"
                await self.storage_service.upload_file(
                    file_bytes=waveform_json.encode("utf-8"),
                    destination_key=waveform_key,
                    content_type="application/json",
                )

                # 4. Transcode renditions (standard ladder: 192k, 128k, 64k)
                # If target bitrate is configured, ensure it is included
                target_bitrates = [192, 128, 64]
                configured_bitrate_str = settings.AUDIO_BITRATE.lower().rstrip("k")
                try:
                    configured_bitrate = int(configured_bitrate_str)
                    if configured_bitrate not in target_bitrates:
                        target_bitrates.insert(0, configured_bitrate)
                except ValueError:
                    pass

                rendition_records_data = []
                for kbps in target_bitrates:
                    rendition_id = uuid.uuid4()
                    rendition_local_path = os.path.join(temp_dir, f"rendition_{kbps}k.m4a")
                    rendition_s3_key = f"audio/processed/{track_id}/{rendition_id}.m4a"

                    logger.info(f"Transcoding {kbps}k rendition for track {track_id}")
                    transcode_res: TranscodeResult = self.transcode_service.transcode_rendition(
                        input_path=local_orig_path,
                        output_path=rendition_local_path,
                        target_bitrate_kbps=kbps,
                        codec="aac",
                        sample_rate=metadata.sample_rate or 44100,
                    )

                    logger.info(f"Uploading rendition {rendition_s3_key}")
                    await self.storage_service.upload_file_from_path(
                        source_path=transcode_res.output_path,
                        destination_key=rendition_s3_key,
                        content_type="audio/mp4",
                    )

                    rendition_records_data.append(
                        {
                            "id": rendition_id,
                            "track_id": track_id,
                            "storage_key": rendition_s3_key,
                            "storage_provider": "s3",
                            "format": transcode_res.format,
                            "codec": transcode_res.codec,
                            "bitrate_kbps": transcode_res.bitrate_kbps,
                            "sample_rate": transcode_res.sample_rate,
                            "channels": transcode_res.channels,
                            "duration_seconds": transcode_res.duration_seconds or duration_sec,
                            "file_size_bytes": transcode_res.file_size_bytes,
                        }
                    )

                # --- Phase 3: Persist Completion in DB ---
                async with AsyncSessionLocal() as session:
                    track_repo = TrackRepository(session)
                    rendition_repo = AudioRenditionRepository(session)
                    job_repo = ProcessingJobRepository(session)

                    track = await track_repo.get_by_id(track_id)
                    if track:
                        await track_repo.update_metadata(
                            track=track,
                            duration_seconds=duration_sec,
                            waveform_key=waveform_key,
                            status="READY",
                        )

                    for rdata in rendition_records_data:
                        await rendition_repo.create(**rdata)

                    latest_job = await job_repo.get_latest_by_track_id(track_id)
                    if latest_job:
                        await job_repo.update_status(
                            job=latest_job,
                            status="COMPLETED",
                            error_message=None,
                        )

                    await session.commit()

                logger.info(
                    f"Successfully processed track {track_id}: duration={duration_sec}s, renditions={len(rendition_records_data)}"
                )
                return True

            except Exception as exc:
                logger.error(f"Error processing track {track_id}: {exc}", exc_info=True)
                sanitized_err = sanitize_error_message(exc)
                await self._mark_job_failed(track_id, sanitized_err)
                return False

    async def _mark_job_failed(self, track_id: uuid.UUID, error_message: str):
        """Marks track and job as FAILED with a sanitized error message."""
        try:
            async with AsyncSessionLocal() as session:
                track_repo = TrackRepository(session)
                job_repo = ProcessingJobRepository(session)

                track = await track_repo.get_by_id(track_id)
                if track:
                    await track_repo.update_status(track, "FAILED")

                latest_job = await job_repo.get_latest_by_track_id(track_id)
                if latest_job:
                    await job_repo.update_status(
                        job=latest_job,
                        status="FAILED",
                        error_message=error_message,
                    )
                await session.commit()
        except Exception as db_exc:
            logger.error(f"Failed to record failure state in database for track {track_id}: {db_exc}")
