import uuid
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class LyricLineItem(BaseModel):
    """Schema representing an individual timestamped line of synchronized lyrics."""

    model_config = ConfigDict(from_attributes=True)

    id: Optional[uuid.UUID] = None
    sequence: int = Field(..., ge=0, description="0-indexed line sequence order")
    start_ms: int = Field(..., ge=0, description="Start offset in milliseconds from track start")
    end_ms: Optional[int] = Field(None, ge=0, description="Optional end offset in milliseconds")
    text: str = Field(..., max_length=5000, description="Lyric line text content")


class LyricLineCreate(BaseModel):
    """Schema for supplying a synchronized lyric line upon creation."""

    sequence: int = Field(..., ge=0)
    start_ms: int = Field(..., ge=0)
    end_ms: Optional[int] = Field(None, ge=0)
    text: str = Field(..., min_length=1, max_length=5000)


class LyricsResponse(BaseModel):
    """Authoritative API response schema for track lyrics."""

    model_config = ConfigDict(from_attributes=True)

    id: Optional[uuid.UUID] = None
    track_id: uuid.UUID
    status: str = Field("UNAVAILABLE", description="PENDING, PROCESSING, COMPLETED, FAILED, UNAVAILABLE")
    language: Optional[str] = Field(None, max_length=10)
    source: str = Field("AI_GENERATED", description="AI_GENERATED, UPLOADED, MANUAL")
    is_synchronized: bool = False
    text: Optional[str] = Field(None, max_length=100000, description="Complete plain text lyrics")
    lines: List[LyricLineItem] = Field(default_factory=list, description="Ordered timestamped lines")
    model: Optional[str] = None
    version: Optional[str] = "v1"
    error_message: Optional[str] = None
    updated_at: Optional[datetime] = None


class LyricsCreateRequest(BaseModel):
    """Request payload for manually creating or updating lyrics."""

    text: Optional[str] = Field(None, max_length=100000)
    language: Optional[str] = Field(None, max_length=10)
    is_synchronized: bool = False
    lines: Optional[List[LyricLineCreate]] = Field(None, max_length=2000)


class LyricsGenerateResponse(BaseModel):
    """Response when background lyrics generation is triggered."""

    track_id: uuid.UUID
    status: str
    message: str
