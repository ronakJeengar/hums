import uuid
from datetime import datetime
from typing import TYPE_CHECKING, List, Optional
from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import BaseDBModel

if TYPE_CHECKING:
    from app.db.models.user import User


class Track(BaseDBModel):
    """Core audio track model representing an uploaded song, episode, or audio piece."""
    __tablename__ = "tracks"

    owner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    description: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )
    artist_name: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
    )
    album_name: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
    )
    genre: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
    )
    duration_seconds: Mapped[Optional[int]] = mapped_column(
        Integer,
        nullable=True,
    )
    status: Mapped[str] = mapped_column(
        String(50),
        default="UPLOADED",
        nullable=False,
        index=True,
    )

    # Relationships
    owner: Mapped["User"] = relationship(
        "User",
        back_populates="tracks",
    )
    audio_files: Mapped[List["AudioFile"]] = relationship(
        "AudioFile",
        back_populates="track",
        cascade="all, delete-orphan",
        order_by="AudioFile.created_at.desc()",
    )
    processing_jobs: Mapped[List["ProcessingJob"]] = relationship(
        "ProcessingJob",
        back_populates="track",
        cascade="all, delete-orphan",
        order_by="ProcessingJob.created_at.desc()",
    )


class AudioFile(BaseDBModel):
    """Raw and processed audio files stored in object storage."""
    __tablename__ = "audio_files"

    track_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tracks.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    object_key: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
        index=True,
    )
    storage_provider: Mapped[str] = mapped_column(
        String(50),
        default="s3",
        nullable=False,
    )
    original_filename: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    mime_type: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )
    file_size_bytes: Mapped[int] = mapped_column(
        BigInteger,
        nullable=False,
    )

    # Relationship
    track: Mapped["Track"] = relationship(
        "Track",
        back_populates="audio_files",
    )


class ProcessingJob(BaseDBModel):
    """Asynchronous media processing job tracking for Celery / FFmpeg transcoding."""
    __tablename__ = "processing_jobs"

    track_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tracks.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    job_type: Mapped[str] = mapped_column(
        String(50),
        default="AUDIO_TRANSCODE",
        nullable=False,
    )
    status: Mapped[str] = mapped_column(
        String(50),
        default="PENDING",
        nullable=False,
        index=True,
    )
    attempts: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )
    error_message: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )

    # Relationship
    track: Mapped["Track"] = relationship(
        "Track",
        back_populates="processing_jobs",
    )
