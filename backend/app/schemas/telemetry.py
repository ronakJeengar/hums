from typing import List, Optional
from pydantic import BaseModel, Field


class PlaybackTelemetryEvent(BaseModel):
    """Schema for reporting client playback telemetry events."""
    event_type: str = Field(
        ...,
        description="Event type: play_started, playback_error, buffering_started, buffering_recovered, track_completed, audio_load_failed",
    )
    track_type: Optional[str] = Field("track", max_length=50)
    error_category: Optional[str] = Field(None, max_length=100)
    http_status: Optional[int] = None
    platform: Optional[str] = Field("mobile", max_length=50)
    app_version: Optional[str] = Field("1.0.0", max_length=50)


class ClientErrorReport(BaseModel):
    """Schema for client-side crash/error reporting without PII."""
    error_type: str = Field(..., max_length=100)
    error_message: str = Field(..., max_length=500)
    screen: Optional[str] = Field(None, max_length=100)
    platform: Optional[str] = Field("mobile", max_length=50)
    app_version: Optional[str] = Field("1.0.0", max_length=50)


class TelemetryBatchRequest(BaseModel):
    """Batched payload for telemetry events to prevent high-frequency HTTP requests."""
    events: List[PlaybackTelemetryEvent] = Field(default_factory=list, max_length=50)
    errors: List[ClientErrorReport] = Field(default_factory=list, max_length=20)
