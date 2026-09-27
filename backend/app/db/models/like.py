import uuid
from datetime import datetime
from typing import TYPE_CHECKING
from sqlalchemy import (
    DateTime,
    ForeignKey,
    Index,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import BaseDBModel

if TYPE_CHECKING:
    from app.db.models.user import User
    from app.db.models.audio import Track


class UserTrackLike(BaseDBModel):
    """Represents a user liking an audio track in their personal library."""

    __tablename__ = "user_track_likes"
    __table_args__ = (
        UniqueConstraint("user_id", "track_id", name="uq_user_track_likes_user_track"),
        Index("ix_user_track_likes_user_created", "user_id", text("created_at DESC")),
        Index("ix_user_track_likes_track_created", "track_id", text("created_at DESC")),
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

    # Relationships
    user: Mapped["User"] = relationship(
        "User",
        back_populates="track_likes",
    )
    track: Mapped["Track"] = relationship(
        "Track",
        back_populates="likes",
    )
