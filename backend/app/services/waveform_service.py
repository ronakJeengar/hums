import json
import logging
import math
import os
import struct
import subprocess
from typing import List, Optional

from app.core.config import get_settings
from app.core.errors import AppException

logger = logging.getLogger("hums.audio.waveform")
settings = get_settings()


class WaveformService:
    """Service for extracting audio amplitude samples and generating normalized waveforms."""

    def __init__(
        self,
        ffmpeg_path: Optional[str] = None,
        sample_count: Optional[int] = None,
    ):
        self.ffmpeg_path = ffmpeg_path or settings.FFMPEG_PATH
        self.sample_count = sample_count or settings.WAVEFORM_SAMPLE_COUNT

    def generate_waveform(
        self, input_path: str, timeout: int = 60
    ) -> List[float]:
        """
        Extracts PCM samples from audio file and computes normalized amplitude waveform points.

        Args:
            input_path: Local filesystem path to the audio file.
            timeout: Subprocess execution timeout in seconds.

        Returns:
            A list of floats with length equal to `self.sample_count` (default 200),
            where each value is normalized between 0.0 and 1.0.

        Raises:
            AppException: If FFmpeg fails, times out, or output cannot be processed.
        """
        if not os.path.isfile(input_path):
            raise AppException(
                f"Audio file does not exist at path: {input_path}",
                code="FILE_NOT_FOUND",
                status_code=404,
            )

        # Downsample to 8kHz mono 16-bit signed LE PCM via stdout
        cmd = [
            self.ffmpeg_path,
            "-v",
            "error",
            "-i",
            input_path,
            "-ac",
            "1",
            "-ar",
            "8000",
            "-f",
            "s16le",
            "-",
        ]

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
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
            logger.error(f"FFmpeg waveform generation timed out after {timeout}s for {input_path}")
            raise AppException(
                "Waveform generation timed out.",
                code="WAVEFORM_TIMEOUT",
                status_code=500,
            )
        except Exception as exc:
            logger.error(f"Unexpected error running FFmpeg for waveform: {exc}")
            raise AppException(
                f"Failed to execute FFmpeg for waveform: {str(exc)}",
                code="WAVEFORM_GENERATION_FAILED",
                status_code=500,
            )

        if result.returncode != 0:
            err_msg = result.stderr.decode("utf-8", errors="replace").strip() or "Unknown ffmpeg error"
            logger.error(f"FFmpeg waveform extraction failed: {err_msg}")
            raise AppException(
                f"Failed to generate waveform: {err_msg}",
                code="WAVEFORM_GENERATION_FAILED",
                status_code=422,
            )

        raw_pcm = result.stdout
        total_samples = len(raw_pcm) // 2  # 16-bit = 2 bytes per sample

        if total_samples == 0:
            logger.warning(f"No PCM samples extracted from {input_path}, returning zero waveform.")
            return [0.0] * self.sample_count

        # Unpack 16-bit signed integers
        # struct.iter_unpack is memory-efficient
        samples = [
            abs(s[0]) for s in struct.iter_unpack("<h", raw_pcm[: total_samples * 2])
        ]

        # Compute amplitude per bucket
        bucket_size = len(samples) / float(self.sample_count)
        raw_buckets: List[float] = []

        for i in range(self.sample_count):
            start_idx = int(i * bucket_size)
            end_idx = int((i + 1) * bucket_size)
            chunk = samples[start_idx:end_idx]
            if chunk:
                # RMS amplitude for smooth visual representation
                rms = math.sqrt(sum(s * s for s in chunk) / len(chunk))
                raw_buckets.append(rms)
            else:
                raw_buckets.append(0.0)

        # Normalize to [0.0, 1.0]
        max_amplitude = max(raw_buckets) if raw_buckets else 0.0
        if max_amplitude > 0:
            normalized = [round(val / max_amplitude, 4) for val in raw_buckets]
        else:
            normalized = [0.0] * self.sample_count

        # Ensure exact count
        if len(normalized) < self.sample_count:
            normalized.extend([0.0] * (self.sample_count - len(normalized)))
        elif len(normalized) > self.sample_count:
            normalized = normalized[: self.sample_count]

        return normalized

    def to_json(self, waveform: List[float]) -> str:
        """Serializes waveform points to JSON string."""
        return json.dumps(waveform)
