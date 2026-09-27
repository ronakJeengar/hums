import uuid
from datetime import datetime
from typing import TYPE_CHECKING, List, Optional

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Index, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import BaseDBModel

if TYPE_CHECKING:
    from app.db.models.user import User
    from app.db.models.audio import Track


class Creator(BaseDBModel):
    """
    Public creator and artist entity profile.
    Separates general user account identities from public artist profiles.
    Can be linked to an onboarded Hums user (user_id) or catalog artist entity.
    """
    __tablename__ = "creators"

    user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        unique=True,
        nullable=True,
        index=True,
    )
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True,
    )
    username: Mapped[Optional[str]] = mapped_column(
        String(100),
        unique=True,
        nullable=True,
        index=True,
    )
    bio: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )
    avatar_url: Mapped[Optional[str]] = mapped_column(
        String(500),
        nullable=True,
    )
    cover_image_url: Mapped[Optional[str]] = mapped_column(
        String(500),
        nullable=True,
    )
    is_verified: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    followers_count: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )

    # Relationships
    user: Mapped[Optional["User"]] = relationship(
        "User",
        back_populates="creator_profile",
    )
    followers: Mapped[List["CreatorFollower"]] = relationship(
        "CreatorFollower",
        back_populates="creator",
        cascade="all, delete-orphan",
        order_by="CreatorFollower.created_at.desc()",
    )

    __table_args__ = (
        CheckConstraint("followers_count >= 0", name="chk_creators_followers_count_nonnegative"),
        Index("ix_creators_name_lower", func.lower(name)),
    )


class CreatorFollower(BaseDBModel):
    """
    Represents a user following a creator.
    Enforces uniqueness so a user can never follow the same creator twice.
    """
    __tablename__ = "creator_followers"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    creator_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("creators.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Relationships
    user: Mapped["User"] = relationship("User")
    creator: Mapped["Creator"] = relationship("Creator", back_populates="followers")

    __table_args__ = (
        Index("uq_creator_followers_user_creator", "user_id", "creator_id", unique=True),
        Index("ix_creator_followers_creator_created_at", "creator_id", "created_at"),
        Index("ix_creator_followers_user_created_at", "user_id", "created_at"),
    )
