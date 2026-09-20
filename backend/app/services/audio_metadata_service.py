import json
import logging
import os
import subprocess
from dataclasses import dataclass
from typing import Optional

from app.core.config import get_settings
from app.core.errors import AppException

logger = logging.getLogger("hums.audio.metadata")
settings = get_settings()


@dataclass
class AudioMetadata:
    """Extracted audio file metadata."""
    duration_seconds: float
    sample_rate: int
    channels: int
    codec: str
    bitrate_kbps: int
    format_name: str


class AudioMetadataService:
    """Service for extracting audio metadata using ffprobe."""

    def __init__(self, ffprobe_path: Optional[str] = None):
        self.ffprobe_path = ffprobe_path or settings.FFPROBE_PATH

    def extract_metadata(self, input_path: str, timeout: int = 30) -> AudioMetadata:
        """
        Extracts duration, sample rate, channels, codec, and bitrate from an audio file using ffprobe.
        
        Args:
            input_path: Local filesystem path to the audio file.
            timeout: Subprocess execution timeout in seconds.

        Returns:
            AudioMetadata object with validated values.

        Raises:
            AppException: If ffprobe fails, times out, or output cannot be parsed.
        """
        if not os.path.isfile(input_path):
            raise AppException(
                f"Audio file does not exist at path: {input_path}",
                code="FILE_NOT_FOUND",
                status_code=404,
            )

        cmd = [
            self.ffprobe_path,
            "-v",
            "error",
            "-show_entries",
            "stream=codec_name,channels,sample_rate,bit_rate,duration:format=duration,bit_rate,format_name",
            "-of",
            "json",
            input_path,
        ]

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout,
                check=False,
            )
        except FileNotFoundError:
            logger.error(f"ffprobe binary not found at '{self.ffprobe_path}'")
            raise AppException(
                "Audio analysis tool (ffprobe) is not installed or accessible on this system.",
                code="FFPROBE_NOT_FOUND",
                status_code=500,
            )
        except subprocess.TimeoutExpired:
            logger.error(f"ffprobe timed out after {timeout} seconds for {input_path}")
            raise AppException(
                "Audio metadata extraction timed out.",
                code="FFPROBE_TIMEOUT",
                status_code=500,
            )
        except Exception as exc:
            logger.error(f"Unexpected error running ffprobe: {exc}")
            raise AppException(
                f"Failed to execute ffprobe: {str(exc)}",
                code="METADATA_EXTRACTION_FAILED",
                status_code=500,
            )

        if result.returncode != 0:
            err_msg = result.stderr.strip() or "Unknown ffprobe error"
            logger.error(f"ffprobe failed with return code {result.returncode}: {err_msg}")
            raise AppException(
                f"Failed to extract audio metadata: {err_msg}",
                code="METADATA_EXTRACTION_FAILED",
                status_code=422,
            )

        try:
            data = json.loads(result.stdout)
        except json.JSONDecodeError as exc:
            logger.error(f"Failed to decode ffprobe JSON output: {exc}")
            raise AppException(
                "ffprobe output was not valid JSON.",
                code="METADATA_PARSE_ERROR",
                status_code=500,
            )

        streams = data.get("streams", [])
        format_data = data.get("format", {})

        # Find first audio stream if available
        audio_stream = streams[0] if streams else {}

        # 1. Duration (stream duration preferred, format duration fallback)
        raw_duration = audio_stream.get("duration") or format_data.get("duration")
        try:
            duration = float(raw_duration) if raw_duration is not None else 0.0
        except (ValueError, TypeError):
            duration = 0.0

        if duration <= 0:
            logger.warning(f"Extracted zero or invalid duration ({raw_duration}) for {input_path}")

        # 2. Sample rate
        raw_sample_rate = audio_stream.get("sample_rate")
        try:
            sample_rate = int(raw_sample_rate) if raw_sample_rate else 44100
        except (ValueError, TypeError):
            sample_rate = 44100

        # 3. Channels
        raw_channels = audio_stream.get("channels")
        try:
            channels = int(raw_channels) if raw_channels else 2
        except (ValueError, TypeError):
            channels = 2

        # 4. Codec
        codec = audio_stream.get("codec_name") or "unknown"

        # 5. Bitrate (stream bitrate preferred, format bitrate fallback)
        raw_bitrate = audio_stream.get("bit_rate") or format_data.get("bit_rate")
        try:
            bitrate_bps = int(raw_bitrate) if raw_bitrate else 0
            bitrate_kbps = max(1, round(bitrate_bps / 1000)) if bitrate_bps else 128
        except (ValueError, TypeError):
            bitrate_kbps = 128

        # 6. Format name
        format_name = format_data.get("format_name") or "unknown"

        return AudioMetadata(
            duration_seconds=duration,
            sample_rate=sample_rate,
            channels=channels,
            codec=codec,
            bitrate_kbps=bitrate_kbps,
            format_name=format_name,
        )
