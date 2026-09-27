import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING, Optional
from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import BaseDBModel

if TYPE_CHECKING:
    from app.db.models.audio import Track
    from app.db.models.user import User


class TrackPlaybackProgress(BaseDBModel):
    """Stores the current resume position and completion status of a track for a user.

    Enforces exactly one active progress record per (user_id, track_id).
    Used for cross-device resume and recently played history.
    """

    __tablename__ = "playback_progress"
    __table_args__ = (
        UniqueConstraint("user_id", "track_id", name="uq_playback_progress_user_track"),
        Index("ix_playback_progress_user_updated", "user_id", text("updated_at DESC")),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    track_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tracks.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    position_ms: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )
    duration_ms: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )
    completed: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    # Relationships
    user: Mapped["User"] = relationship(
        "User",
        backref="playback_progress_records",
    )
    track: Mapped["Track"] = relationship(
        "Track",
        backref="playback_progress_records",
    )

    @property
    def progress_percent(self) -> float:
        if not self.duration_ms or self.duration_ms <= 0:
            return 0.0
        return round(min(1.0, max(0.0, self.position_ms / self.duration_ms)), 4)


class PlaybackEvent(BaseDBModel):
    """Immutable audit and analytics log of playback lifecycle events.

    Uses client-generated event_id for guaranteed idempotent offline sync.
    Duplicate submissions with the same (user_id, event_id) are silently ignored.
    """

    __tablename__ = "playback_events"
    __table_args__ = (
        UniqueConstraint("user_id", "event_id", name="uq_playback_events_user_event_id"),
        Index("ix_playback_events_user_played_at", "user_id", text("played_at DESC")),
        Index("ix_playback_events_user_track", "user_id", "track_id"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    track_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tracks.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    event_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        index=True,
    )
    event_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )
    position_ms: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )
    duration_ms: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )
    source: Mapped[str] = mapped_column(
        String(50),
        default="player",
        nullable=False,
    )
    device_id: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
    )
    played_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    # Relationships
    user: Mapped["User"] = relationship(
        "User",
        backref="playback_events",
    )
    track: Mapped["Track"] = relationship(
        "Track",
        backref="playback_events",
    )
