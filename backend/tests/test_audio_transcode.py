import json
import os
import subprocess
import tempfile
import uuid
from unittest.mock import MagicMock, patch

import pytest
from httpx import AsyncClient

from app.core.errors import AppException
from app.db.database import AsyncSessionLocal
from app.db.models.audio import AudioFile, AudioRendition, ProcessingJob, Track
from app.repositories.audio_repository import (
    AudioFileRepository,
    AudioRenditionRepository,
    ProcessingJobRepository,
    TrackRepository,
)
from app.services.audio_metadata_service import AudioMetadataService
from app.services.audio_processing_service import (
    AudioProcessingService,
    sanitize_error_message,
)
from app.services.audio_transcode_service import AudioTranscodeService
from app.services.waveform_service import WaveformService
from app.utils.storage import BaseStorageService
from app.workers.audio_tasks import process_audio_track


# --- Mock Storage Service for Tests ---
class MockInMemoryStorage(BaseStorageService):
    def __init__(self):
        self.files = {}

    async def upload_file(
        self, file_bytes: bytes, destination_key: str, content_type: str = "application/octet-stream"
    ) -> str:
        self.files[destination_key] = file_bytes
        return f"http://mock-storage/{destination_key}"

    async def upload_file_from_path(
        self, source_path: str, destination_key: str, content_type: str = "application/octet-stream"
    ) -> str:
        with open(source_path, "rb") as f:
            self.files[destination_key] = f.read()
        return f"http://mock-storage/{destination_key}"

    async def download_file(self, object_key: str) -> bytes:
        if object_key not in self.files:
            raise AppException("File not found in mock storage", code="FILE_NOT_FOUND", status_code=404)
        return self.files[object_key]

    async def download_file_to_path(self, object_key: str, destination_path: str) -> str:
        data = await self.download_file(object_key)
        os.makedirs(os.path.dirname(destination_path), exist_ok=True)
        with open(destination_path, "wb") as f:
            f.write(data)
        return destination_path

    async def delete_file(self, object_key: str) -> bool:
        self.files.pop(object_key, None)
        return True

    async def file_exists(self, object_key: str) -> bool:
        return object_key in self.files

    async def get_download_url(self, object_key: str, expires_in: int = 3600) -> str:
        return f"http://mock-storage/{object_key}"



@pytest.fixture
def mock_storage():
    return MockInMemoryStorage()


@pytest.fixture
async def user_auth(async_client: AsyncClient):
    """Registers and logs in a test user."""
    email = f"transcode_{uuid.uuid4().hex[:8]}@example.com"
    password = "SecurePassword123!"
    res = await async_client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": password, "name": "Audio Engineer"},
    )
    assert res.status_code == 201
    data = res.json()["data"]
    return {
        "headers": {"Authorization": f"Bearer {data['access_token']}"},
        "user_id": uuid.UUID(data["user"]["id"]),
    }


# ============================================================================
# 1. AudioMetadataService Unit Tests
# ============================================================================
class TestAudioMetadataService:
    def test_extract_metadata_success(self, tmp_path):
        dummy_file = tmp_path / "test.mp3"
        dummy_file.write_bytes(b"dummy audio content")

        mock_ffprobe_json = json.dumps(
            {
                "streams": [
                    {
                        "codec_name": "mp3",
                        "channels": 2,
                        "sample_rate": "44100",
                        "bit_rate": "320000",
                        "duration": "185.45",
                    }
                ],
                "format": {
                    "duration": "185.45",
                    "bit_rate": "320000",
                    "format_name": "mp3",
                },
            }
        )

        service = AudioMetadataService()
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0,
                stdout=mock_ffprobe_json,
                stderr="",
            )
            meta = service.extract_metadata(str(dummy_file))

            assert meta.duration_seconds == 185.45
            assert meta.sample_rate == 44100
            assert meta.channels == 2
            assert meta.codec == "mp3"
            assert meta.bitrate_kbps == 320
            assert meta.format_name == "mp3"

    def test_extract_metadata_missing_file_raises_404(self):
        service = AudioMetadataService()
        with pytest.raises(AppException) as exc_info:
            service.extract_metadata("/nonexistent/file.mp3")
        assert exc_info.value.status_code == 404
        assert exc_info.value.code == "FILE_NOT_FOUND"

    def test_extract_metadata_ffprobe_not_found(self, tmp_path):
        dummy_file = tmp_path / "test.mp3"
        dummy_file.write_bytes(b"data")

        service = AudioMetadataService(ffprobe_path="nonexistent_ffprobe_bin")
        with patch("subprocess.run", side_effect=FileNotFoundError):
            with pytest.raises(AppException) as exc_info:
                service.extract_metadata(str(dummy_file))
            assert exc_info.value.code == "FFPROBE_NOT_FOUND"

    def test_extract_metadata_timeout(self, tmp_path):
        dummy_file = tmp_path / "test.mp3"
        dummy_file.write_bytes(b"data")

        service = AudioMetadataService()
        with patch("subprocess.run", side_effect=subprocess.TimeoutExpired(cmd="ffprobe", timeout=30)):
            with pytest.raises(AppException) as exc_info:
                service.extract_metadata(str(dummy_file))
            assert exc_info.value.code == "FFPROBE_TIMEOUT"


# ============================================================================
# 2. WaveformService Unit Tests
# ============================================================================
class TestWaveformService:
    def test_generate_waveform_normalized_200_samples(self, tmp_path):
        dummy_file = tmp_path / "test.mp3"
        dummy_file.write_bytes(b"dummy audio content")

        # Generate fake 16-bit PCM: 1000 samples oscillating between -10000 and 10000
        import struct
        pcm_data = bytearray()
        for i in range(1000):
            val = int(10000 * (i % 2 * 2 - 1))
            pcm_data.extend(struct.pack("<h", val))

        service = WaveformService(sample_count=200)
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0,
                stdout=bytes(pcm_data),
                stderr=b"",
            )
            waveform = service.generate_waveform(str(dummy_file))

            assert len(waveform) == 200
            assert all(0.0 <= val <= 1.0 for val in waveform)
            assert max(waveform) == 1.0

    def test_generate_waveform_silent_audio(self, tmp_path):
        dummy_file = tmp_path / "silent.mp3"
        dummy_file.write_bytes(b"silent")

        import struct
        # 1000 samples of pure silence (0)
        pcm_data = struct.pack("<1000h", *([0] * 1000))

        service = WaveformService(sample_count=200)
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0,
                stdout=pcm_data,
                stderr=b"",
            )
            waveform = service.generate_waveform(str(dummy_file))

            assert len(waveform) == 200
            assert all(val == 0.0 for val in waveform)


# ============================================================================
# 3. AudioTranscodeService Unit Tests
# ============================================================================
class TestAudioTranscodeService:
    def test_transcode_rendition_success(self, tmp_path):
        input_file = tmp_path / "input.wav"
        input_file.write_bytes(b"fake wav data")
        output_file = tmp_path / "output.m4a"

        mock_meta = MagicMock(
            duration_seconds=120.0,
            sample_rate=44100,
            channels=2,
            codec="aac",
            bitrate_kbps=192,
            format_name="mov,mp4,m4a,3gp,3g2,mj2",
        )
        mock_meta_service = MagicMock()
        mock_meta_service.extract_metadata.return_value = mock_meta

        service = AudioTranscodeService(metadata_service=mock_meta_service)

        def mock_ffmpeg_run(*args, **kwargs):
            # Simulate output creation
            output_file.write_bytes(b"fake transcoded m4a content" * 100)
            return MagicMock(returncode=0, stdout="", stderr="")

        with patch("subprocess.run", side_effect=mock_ffmpeg_run):
            result = service.transcode_rendition(
                input_path=str(input_file),
                output_path=str(output_file),
                target_bitrate_kbps=192,
            )

            assert result.output_path == str(output_file)
            assert result.format == "m4a"
            assert result.codec == "aac"
            assert result.bitrate_kbps == 192
            assert result.duration_seconds == 120
            assert result.file_size_bytes > 0

    def test_transcode_ladder_generates_all_bitrates(self, tmp_path):
        input_file = tmp_path / "input.wav"
        input_file.write_bytes(b"fake wav data")
        output_dir = tmp_path / "ladder"

        service = AudioTranscodeService()

        def mock_transcode(input_path, output_path, target_bitrate_kbps, **kwargs):
            from app.services.audio_transcode_service import TranscodeResult
            return TranscodeResult(
                output_path=output_path,
                format="m4a",
                codec="aac",
                bitrate_kbps=target_bitrate_kbps,
                sample_rate=44100,
                channels=2,
                duration_seconds=90,
                file_size_bytes=50000,
            )

        with patch.object(service, "transcode_rendition", side_effect=mock_transcode):
            results = service.transcode_ladder(
                input_path=str(input_file),
                output_dir=str(output_dir),
                bitrates=[192, 128, 64],
            )

            assert len(results) == 3
            assert [r.bitrate_kbps for r in results] == [192, 128, 64]


# ============================================================================
# 4. AudioProcessingService & Celery Task End-to-End Pipeline Tests
# ============================================================================
class TestAudioProcessingPipeline:
    async def test_full_pipeline_success(self, user_auth, mock_storage):
        user_id = user_auth["user_id"]
        track_id = uuid.uuid4()
        file_uuid = uuid.uuid4()
        object_key = f"audio/original/{user_id}/{track_id}/{file_uuid}.mp3"

        # Populate mock storage with original audio
        mock_audio_content = b"ID3\x03\x00\x00\x00\x00\x00\x00" + b"\x00" * 500
        await mock_storage.upload_file(mock_audio_content, object_key)

        # Seed database records
        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            file_repo = AudioFileRepository(session)
            job_repo = ProcessingJobRepository(session)

            track = await track_repo.create(
                id=track_id,
                owner_id=user_id,
                title="Transcode Pipeline Test",
                status="UPLOADED",
            )
            await file_repo.create(
                id=file_uuid,
                track_id=track_id,
                object_key=object_key,
                storage_provider="s3",
                original_filename="test.mp3",
                mime_type="audio/mpeg",
                file_size_bytes=len(mock_audio_content),
            )
            await job_repo.create(
                track_id=track_id,
                job_type="AUDIO_TRANSCODE",
                status="PENDING",
                attempts=0,
            )
            await session.commit()

        # Mock metadata, waveform, and transcode services
        mock_meta_service = MagicMock()
        from app.services.audio_metadata_service import AudioMetadata
        mock_meta_service.extract_metadata.return_value = AudioMetadata(
            duration_seconds=210.4,
            sample_rate=44100,
            channels=2,
            codec="mp3",
            bitrate_kbps=320,
            format_name="mp3",
        )

        mock_waveform_service = MagicMock()
        mock_waveform_service.generate_waveform.return_value = [0.5] * 200
        mock_waveform_service.to_json.return_value = json.dumps([0.5] * 200)

        mock_transcode_service = MagicMock()
        from app.services.audio_transcode_service import TranscodeResult

        def fake_transcode(input_path, output_path, target_bitrate_kbps, **kwargs):
            # Create dummy file so upload succeeds
            with open(output_path, "wb") as f:
                f.write(b"fake-aac-m4a")
            return TranscodeResult(
                output_path=output_path,
                format="m4a",
                codec="aac",
                bitrate_kbps=target_bitrate_kbps,
                sample_rate=44100,
                channels=2,
                duration_seconds=210,
                file_size_bytes=12345,
            )

        mock_transcode_service.transcode_rendition.side_effect = fake_transcode

        pipeline = AudioProcessingService(
            storage_service=mock_storage,
            metadata_service=mock_meta_service,
            waveform_service=mock_waveform_service,
            transcode_service=mock_transcode_service,
        )

        success = await pipeline.process_track(track_id)
        assert success is True

        # Verify DB records after pipeline run
        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            rendition_repo = AudioRenditionRepository(session)
            job_repo = ProcessingJobRepository(session)

            updated_track = await track_repo.get_by_id_with_relations(track_id)
            assert updated_track.status == "READY"
            assert updated_track.duration_seconds == 210
            assert updated_track.waveform_key == f"audio/waveforms/{track_id}.json"

            # Check renditions
            renditions = await rendition_repo.get_by_track_id(track_id)
            assert len(renditions) >= 3
            bitrates = [r.bitrate_kbps for r in renditions]
            assert 192 in bitrates
            assert 128 in bitrates
            assert 64 in bitrates

            # Check job status
            job = await job_repo.get_latest_by_track_id(track_id)
            assert job.status == "COMPLETED"
            assert job.error_message is None

        # Verify storage contains waveform and processed renditions
        waveform_key = f"audio/waveforms/{track_id}.json"
        assert await mock_storage.file_exists(waveform_key)
        waveform_data = json.loads((await mock_storage.download_file(waveform_key)).decode("utf-8"))
        assert len(waveform_data) == 200

    async def test_pipeline_idempotency_when_already_ready(self, user_auth, mock_storage):
        user_id = user_auth["user_id"]
        track_id = uuid.uuid4()

        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            await track_repo.create(
                id=track_id,
                owner_id=user_id,
                title="Already Ready Track",
                status="READY",
            )
            await session.commit()

        pipeline = AudioProcessingService(storage_service=mock_storage)
        # Should be a clean no-op
        result = await pipeline.process_track(track_id)
        assert result is True

    async def test_pipeline_failure_sanitization_and_status(self, user_auth, mock_storage):
        user_id = user_auth["user_id"]
        track_id = uuid.uuid4()
        file_uuid = uuid.uuid4()
        object_key = f"audio/original/{user_id}/{track_id}/{file_uuid}.mp3"

        # Upload corrupt data to storage
        await mock_storage.upload_file(b"corrupt-data", object_key)

        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            file_repo = AudioFileRepository(session)
            job_repo = ProcessingJobRepository(session)

            await track_repo.create(
                id=track_id,
                owner_id=user_id,
                title="Corrupt Audio Track",
                status="UPLOADED",
            )
            await file_repo.create(
                id=file_uuid,
                track_id=track_id,
                object_key=object_key,
                storage_provider="s3",
                original_filename="corrupt.mp3",
                mime_type="audio/mpeg",
                file_size_bytes=12,
            )
            await job_repo.create(
                track_id=track_id,
                job_type="AUDIO_TRANSCODE",
                status="PENDING",
                attempts=0,
            )
            await session.commit()

        # Mock metadata service to simulate ffprobe failure with internal path in error
        mock_meta_service = MagicMock()
        mock_meta_service.extract_metadata.side_effect = AppException(
            "Invalid stream in /tmp/hums_transcode_123/original.mp3 header corrupt",
            code="METADATA_EXTRACTION_FAILED",
            status_code=422,
        )

        pipeline = AudioProcessingService(
            storage_service=mock_storage,
            metadata_service=mock_meta_service,
        )

        success = await pipeline.process_track(track_id)
        assert success is False

        # Verify DB updated to FAILED and error message sanitized
        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            job_repo = ProcessingJobRepository(session)

            track = await track_repo.get_by_id(track_id)
            assert track.status == "FAILED"

            job = await job_repo.get_latest_by_track_id(track_id)
            assert job.status == "FAILED"
            assert "/tmp/" not in job.error_message
            assert "[path]" in job.error_message or "corrupt" in job.error_message


# ============================================================================
# 5. API Endpoints for Waveform, Status, and Track Details
# ============================================================================
class TestAudioTranscodeEndpoints:
    async def test_get_waveform_endpoint(
        self, async_client: AsyncClient, user_auth, mock_storage
    ):
        user_id = user_auth["user_id"]
        headers = user_auth["headers"]
        track_id = uuid.uuid4()
        waveform_key = f"audio/waveforms/{track_id}.json"

        # Save waveform to storage
        samples = [round(i / 200.0, 4) for i in range(200)]
        await mock_storage.upload_file(json.dumps(samples).encode("utf-8"), waveform_key)

        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            await track_repo.create(
                id=track_id,
                owner_id=user_id,
                title="Waveform Track",
                waveform_key=waveform_key,
                status="READY",
            )
            await session.commit()

        # Override storage service dependency
        from app.core.dependencies import get_storage_service
        from app.main import app
        app.dependency_overrides[get_storage_service] = lambda: mock_storage

        try:
            response = await async_client.get(
                f"/api/v1/audio/tracks/{track_id}/waveform",
                headers=headers,
            )
            assert response.status_code == 200
            body = response.json()
            assert body["success"] is True
            assert body["data"]["track_id"] == str(track_id)
            assert len(body["data"]["samples"]) == 200
            assert body["data"]["samples"][0] == 0.0
            assert body["data"]["samples"][-1] == 0.995
        finally:
            app.dependency_overrides.pop(get_storage_service, None)

    async def test_track_details_includes_renditions(
        self, async_client: AsyncClient, user_auth
    ):
        user_id = user_auth["user_id"]
        headers = user_auth["headers"]
        track_id = uuid.uuid4()

        async with AsyncSessionLocal() as session:
            track_repo = TrackRepository(session)
            rendition_repo = AudioRenditionRepository(session)

            await track_repo.create(
                id=track_id,
                owner_id=user_id,
                title="Rendition Test Track",
                duration_seconds=180,
                status="READY",
            )
            await rendition_repo.create(
                track_id=track_id,
                storage_key=f"audio/processed/{track_id}/192k.m4a",
                storage_provider="s3",
                format="m4a",
                codec="aac",
                bitrate_kbps=192,
                sample_rate=44100,
                channels=2,
                duration_seconds=180,
                file_size_bytes=4500000,
            )
            await rendition_repo.create(
                track_id=track_id,
                storage_key=f"audio/processed/{track_id}/128k.m4a",
                storage_provider="s3",
                format="m4a",
                codec="aac",
                bitrate_kbps=128,
                sample_rate=44100,
                channels=2,
                duration_seconds=180,
                file_size_bytes=3000000,
            )
            await session.commit()

        response = await async_client.get(
            f"/api/v1/audio/tracks/{track_id}",
            headers=headers,
        )
        assert response.status_code == 200
        data = response.json()["data"]
        assert data["duration_seconds"] == 180
        assert len(data["renditions"]) == 2
        assert data["renditions"][0]["bitrate_kbps"] == 192
        assert data["renditions"][1]["bitrate_kbps"] == 128
