import logging
import os
import subprocess
from dataclasses import dataclass
from typing import List, Optional

from app.core.config import get_settings
from app.core.errors import AppException
from app.services.audio_metadata_service import AudioMetadataService

logger = logging.getLogger("hums.audio.transcode")
settings = get_settings()


@dataclass
class TranscodeResult:
    """Result of an audio transcode operation."""
    output_path: str
    format: str
    codec: str
    bitrate_kbps: int
    sample_rate: int
    channels: int
    duration_seconds: int
    file_size_bytes: int


class AudioTranscodeService:
    """Service for transcoding audio files to streaming-optimized AAC/M4A renditions using FFmpeg."""

    def __init__(
        self,
        ffmpeg_path: Optional[str] = None,
        metadata_service: Optional[AudioMetadataService] = None,
    ):
        self.ffmpeg_path = ffmpeg_path or settings.FFMPEG_PATH
        self.metadata_service = metadata_service or AudioMetadataService()

    def transcode_rendition(
        self,
        input_path: str,
        output_path: str,
        target_bitrate_kbps: int = 192,
        codec: Optional[str] = None,
        sample_rate: int = 44100,
        timeout: int = 300,
    ) -> TranscodeResult:
        """
        Transcodes an input audio file into an AAC rendition formatted in an M4A container
        with faststart streaming optimization.

        Args:
            input_path: Local filesystem path to source audio file.
            output_path: Local filesystem destination path for transcoded output.
            target_bitrate_kbps: Target audio bitrate in kbps (e.g. 64, 128, 192).
            codec: Audio codec to encode with (default: 'aac').
            sample_rate: Target sample rate in Hz (default: 44100).
            timeout: Subprocess execution timeout in seconds.

        Returns:
            TranscodeResult with metadata of generated file.

        Raises:
            AppException: If FFmpeg fails, times out, or output file is invalid.
        """
        if not os.path.isfile(input_path):
            raise AppException(
                f"Audio file does not exist at path: {input_path}",
                code="FILE_NOT_FOUND",
                status_code=404,
            )

        codec_name = codec or settings.AUDIO_CODEC
        bitrate_str = f"{target_bitrate_kbps}k"

        # Ensure output directory exists
        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        cmd = [
            self.ffmpeg_path,
            "-y",  # Overwrite output without asking
            "-i",
            input_path,
            "-vn",  # Exclude video / embedded cover art streams
            "-c:a",
            codec_name,
            "-b:a",
            bitrate_str,
            "-ar",
            str(sample_rate),
            "-movflags",
            "+faststart",  # Enable progressive streaming playback
            output_path,
        ]

        logger.info(
            f"Starting transcode for {input_path} -> {output_path} (bitrate={bitrate_str}, codec={codec_name})"
        )

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout,
                check=False,
            )
        except FileNotFoundError:
            logger.error(f"ffmpeg binary not found at '{self.ffmpeg_path}'")
            raise AppException(
                "Audio processing tool (ffmpeg) is not installed or accessible on this system.",
                code="FFMPEG_NOT_FOUND",
                status_code=500,
            )
        except subprocess.TimeoutExpired:
            logger.error(f"FFmpeg transcode timed out after {timeout}s for {input_path}")
            raise AppException(
                "Audio transcoding operation timed out.",
                code="TRANSCODE_TIMEOUT",
                status_code=500,
            )
        except Exception as exc:
            logger.error(f"Unexpected error running FFmpeg transcode: {exc}")
            raise AppException(
                f"Failed to execute FFmpeg transcode: {str(exc)}",
                code="TRANSCODE_FAILED",
                status_code=500,
            )

        if result.returncode != 0:
            err_msg = result.stderr.strip() or "Unknown ffmpeg error"
            logger.error(f"FFmpeg transcode failed with exit code {result.returncode}: {err_msg}")
            raise AppException(
                f"Audio transcode failed: {err_msg}",
                code="TRANSCODE_FAILED",
                status_code=422,
            )

        if not os.path.isfile(output_path) or os.path.getsize(output_path) == 0:
            raise AppException(
                "Transcoded output file was not created or is empty.",
                code="TRANSCODE_OUTPUT_EMPTY",
                status_code=500,
            )

        # Inspect generated output file
        file_size = os.path.getsize(output_path)
        try:
            out_meta = self.metadata_service.extract_metadata(output_path)
            duration = int(round(out_meta.duration_seconds))
            channels = out_meta.channels
            actual_sample_rate = out_meta.sample_rate
        except Exception as exc:
            logger.warning(f"Could not read output metadata via ffprobe: {exc}")
            duration = 0
            channels = 2
            actual_sample_rate = sample_rate

        return TranscodeResult(
            output_path=output_path,
            format="m4a",
            codec=codec_name,
            bitrate_kbps=target_bitrate_kbps,
            sample_rate=actual_sample_rate,
            channels=channels,
            duration_seconds=duration,
            file_size_bytes=file_size,
        )

    def transcode_ladder(
        self,
        input_path: str,
        output_dir: str,
        bitrates: Optional[List[int]] = None,
    ) -> List[TranscodeResult]:
        """
        Generates a standard multi-bitrate rendition ladder for streaming.
        Defaults to [192, 128, 64] kbps.
        """
        ladder_bitrates = bitrates or [192, 128, 64]
        results: List[TranscodeResult] = []

        for kbps in ladder_bitrates:
            out_file = os.path.join(output_dir, f"rendition_{kbps}k.m4a")
            result = self.transcode_rendition(
                input_path=input_path,
                output_path=out_file,
                target_bitrate_kbps=kbps,
            )
            results.append(result)

        return results
