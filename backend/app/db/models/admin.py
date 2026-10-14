import uuid
from datetime import datetime
from typing import TYPE_CHECKING, Optional, Any
from sqlalchemy import (
    DateTime,
    ForeignKey,
    Index,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import BaseDBModel

if TYPE_CHECKING:
    from app.db.models.user import User


class CreatorApplication(BaseDBModel):
    """
    Submissions from listeners applying for verified creator privileges.
    Allows administrators and moderators to review, approve, or reject applicants.
    """
    __tablename__ = "creator_applications"
    __table_args__ = (
        Index("ix_creator_apps_status_created", "status", "created_at"),
        Index("ix_creator_apps_user_status", "user_id", "status"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    artist_name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    bio: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )
    genres: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
    )
    portfolio_url: Mapped[Optional[str]] = mapped_column(
        String(500),
        nullable=True,
    )
    status: Mapped[str] = mapped_column(
        String(50),
        default="PENDING",
        nullable=False,
        index=True,  # PENDING, APPROVED, REJECTED
    )
    reviewer_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    review_notes: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )
    reviewed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relationships
    user: Mapped["User"] = relationship(
        "User",
        foreign_keys=[user_id],
        backref="creator_applications",
    )
    reviewer: Mapped[Optional["User"]] = relationship(
        "User",
        foreign_keys=[reviewer_id],
    )


class ContentReport(BaseDBModel):
    """
    Reports submitted by listeners or creators against tracks, profiles, or users.
    Managed via the administrator/moderation review queue.
    """
    __tablename__ = "content_reports"
    __table_args__ = (
        Index("ix_content_reports_status_created", "status", "created_at"),
        Index("ix_content_reports_entity", "entity_type", "entity_id"),
    )

    reporter_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    entity_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        index=True,  # track, creator, user
    )
    entity_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        nullable=False,
        index=True,
    )
    reason: Mapped[str] = mapped_column(
        String(100),
        nullable=False,  # COPYRIGHT, INAPPROPRIATE, SPAM, HARASSMENT, OTHER
    )
    description: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )
    status: Mapped[str] = mapped_column(
        String(50),
        default="PENDING",
        nullable=False,
        index=True,  # PENDING, INVESTIGATING, RESOLVED, DISMISSED
    )
    moderator_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    resolution_notes: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )
    action_taken: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,  # NO_ACTION, TRACK_REMOVED, USER_WARNED, USER_SUSPENDED
    )
    resolved_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relationships
    reporter: Mapped["User"] = relationship(
        "User",
        foreign_keys=[reporter_id],
        backref="filed_reports",
    )
    moderator: Mapped[Optional["User"]] = relationship(
        "User",
        foreign_keys=[moderator_id],
    )


class AdminAuditLog(BaseDBModel):
    """
    Immutable ledger of administrative actions for compliance, observability, and auditing.
    Records actor, operation, target entity, timestamp, reason, and IP.
    """
    __tablename__ = "admin_audit_logs"
    __table_args__ = (
        Index("ix_admin_audit_logs_actor", "actor_id", "created_at"),
        Index("ix_admin_audit_logs_action", "action", "created_at"),
        Index("ix_admin_audit_logs_target", "target_type", "target_id"),
    )

    actor_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    actor_email: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    action: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        index=True,  # USER_SUSPEND, USER_ACTIVATE, USER_ROLE_CHANGE, TRACK_MODERATE, etc.
    )
    target_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,  # user, creator, track, report, creator_application
    )
    target_id: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    details: Mapped[Optional[Any]] = mapped_column(
        JSONB,
        nullable=True,
    )
    reason: Mapped[Optional[str]] = mapped_column(
        String(500),
        nullable=True,
    )
    ip_address: Mapped[Optional[str]] = mapped_column(
        String(45),
        nullable=True,
    )

    # Relationship
    actor: Mapped["User"] = relationship(
        "User",
        foreign_keys=[actor_id],
        backref="admin_audit_actions",
    )
