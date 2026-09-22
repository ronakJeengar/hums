import uuid
from datetime import datetime
from typing import TYPE_CHECKING, List, Optional
from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import BaseDBModel

if TYPE_CHECKING:
    from app.db.models.user import User
    from app.db.models.audio import Track


class RecommendationSet(BaseDBModel):
    """Stores a generated set of recommendations for a user."""
    __tablename__ = "recommendation_sets"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    algorithm_version: Mapped[str] = mapped_column(
        String(50),
        default="v1-hybrid",
        nullable=False,
    )
    model_name: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
    )
    prompt_version: Mapped[Optional[str]] = mapped_column(
        String(50),
        nullable=True,
    )
    expires_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        index=True,
    )

    # Relationships
    user: Mapped["User"] = relationship(
        "User",
        back_populates="recommendation_sets",
    )
    items: Mapped[List["RecommendationItem"]] = relationship(
        "RecommendationItem",
        back_populates="recommendation_set",
        cascade="all, delete-orphan",
        order_by="RecommendationItem.position.asc()",
    )


class RecommendationItem(BaseDBModel):
    """An individual recommended track within a recommendation set."""
    __tablename__ = "recommendation_items"

    recommendation_set_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("recommendation_sets.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    track_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tracks.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    section: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        index=True,
    )
    position: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
        index=True,
    )
    score: Mapped[Optional[float]] = mapped_column(
        Float,
        nullable=True,
    )

    # Relationships
    recommendation_set: Mapped["RecommendationSet"] = relationship(
        "RecommendationSet",
        back_populates="items",
    )
    track: Mapped["Track"] = relationship(
        "Track",
        back_populates="recommendation_items",
    )

    __table_args__ = (
        UniqueConstraint(
            "recommendation_set_id",
            "section",
            "track_id",
            name="uq_rec_items_set_section_track",
        ),
    )
