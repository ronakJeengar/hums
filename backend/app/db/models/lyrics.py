import uuid
from datetime import datetime
from typing import TYPE_CHECKING, List, Optional
from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import BaseDBModel

if TYPE_CHECKING:
    from app.db.models.audio import Track


class LyricsStatus:
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"
    UNAVAILABLE = "UNAVAILABLE"


class LyricsSource:
    AI_GENERATED = "AI_GENERATED"
    UPLOADED = "UPLOADED"
    MANUAL = "MANUAL"


class Lyrics(BaseDBModel):
    """Authoritative song lyrics or transcript associated with a Track."""

    __tablename__ = "lyrics"
    __table_args__ = (
        Index("ix_lyrics_track_id", "track_id", unique=True),
        Index("ix_lyrics_status", "status"),
    )

    track_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tracks.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )
    status: Mapped[str] = mapped_column(
        String(50),
        default=LyricsStatus.PENDING,
        nullable=False,
    )
    language: Mapped[Optional[str]] = mapped_column(
        String(10),
        nullable=True,
    )
    text: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )
    source: Mapped[str] = mapped_column(
        String(50),
        default=LyricsSource.AI_GENERATED,
        nullable=False,
    )
    is_synchronized: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    model: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
    )
    version: Mapped[str] = mapped_column(
        String(20),
        default="v1",
        nullable=False,
    )
    error_message: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )

    # Relationships
    track: Mapped["Track"] = relationship(
        "Track",
        back_populates="lyrics",
    )
    lines: Mapped[List["LyricLine"]] = relationship(
        "LyricLine",
        back_populates="lyrics",
        cascade="all, delete-orphan",
        order_by="LyricLine.sequence.asc()",
    )


class LyricLine(BaseDBModel):
    """An individual timestamped line within synchronized lyrics."""

    __tablename__ = "lyric_lines"
    __table_args__ = (
        Index("ix_lyric_lines_lyrics_sequence", "lyrics_id", "sequence"),
    )

    lyrics_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("lyrics.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    sequence: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )
    start_ms: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )
    end_ms: Mapped[Optional[int]] = mapped_column(
        Integer,
        nullable=True,
    )
    text: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )

    # Relationship
    lyrics: Mapped["Lyrics"] = relationship(
        "Lyrics",
        back_populates="lines",
    )
