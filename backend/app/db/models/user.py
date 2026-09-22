import uuid
from datetime import datetime
from typing import TYPE_CHECKING, List, Optional
from sqlalchemy import Boolean, DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import BaseDBModel

if TYPE_CHECKING:
    from app.db.models.audio import Track
    from app.db.models.recommendation import RecommendationSet


class User(BaseDBModel):
    """Core user account model."""
    __tablename__ = "users"

    email: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        index=True,
        nullable=False,
    )
    username: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        index=True,
        nullable=True,
    )
    hashed_password: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    full_name: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
    )
    avatar_url: Mapped[Optional[str]] = mapped_column(
        String(500),
        nullable=True,
    )
    bio: Mapped[Optional[str]] = mapped_column(
        String(500),
        nullable=True,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )
    is_verified: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    last_login_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relationships
    refresh_tokens: Mapped[List["RefreshToken"]] = relationship(
        "RefreshToken",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    password_reset_tokens: Mapped[List["PasswordResetToken"]] = relationship(
        "PasswordResetToken",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    tracks: Mapped[List["Track"]] = relationship(
        "Track",
        back_populates="owner",
        cascade="all, delete-orphan",
        order_by="Track.created_at.desc()",
    )
    recommendation_sets: Mapped[List["RecommendationSet"]] = relationship(
        "RecommendationSet",
        back_populates="user",
        cascade="all, delete-orphan",
        order_by="RecommendationSet.created_at.desc()",
    )

    @property
    def name(self) -> str:
        """Returns the user's display name or username."""
        return self.full_name or self.username or ""


class RefreshToken(BaseDBModel):
    """Secure refresh tokens for JWT session rotation."""
    __tablename__ = "refresh_tokens"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    token_hash: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        index=True,
        nullable=False,
    )
    device_info: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
    )
    ip_address: Mapped[Optional[str]] = mapped_column(
        String(45),
        nullable=True,
    )
    is_revoked: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    revoked_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True,
    )

    # Relationship to user
    user: Mapped["User"] = relationship(
        "User",
        back_populates="refresh_tokens",
    )


class PasswordResetToken(BaseDBModel):
    """Secure password reset tokens for single-use credential recovery."""
    __tablename__ = "password_reset_tokens"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    token_hash: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        index=True,
        nullable=False,
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True,
    )
    used_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relationship to user
    user: Mapped["User"] = relationship(
        "User",
        back_populates="password_reset_tokens",
    )
