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
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import BaseDBModel

if TYPE_CHECKING:
    from app.db.models.user import User


class SubscriptionPlan(BaseDBModel):
    """
    Configurable subscription plan catalog.
    Defines commercial plans (Free, Premium Monthly, Premium Yearly) and their metadata.
    """
    __tablename__ = "subscription_plans"

    code: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        index=True,
        nullable=False,
    )
    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )
    description: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )
    billing_interval: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="MONTH",  # "NONE", "MONTH", "YEAR"
    )
    price_cents: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=0,
    )
    currency: Mapped[str] = mapped_column(
        String(3),
        nullable=False,
        default="USD",
    )
    apple_product_id: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
        index=True,
    )
    google_product_id: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
        index=True,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )
    display_order: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )

    # Relationships
    user_subscriptions: Mapped[List["UserSubscription"]] = relationship(
        "UserSubscription",
        back_populates="plan",
        cascade="all, delete-orphan",
    )
    plan_entitlements: Mapped[List["PlanEntitlement"]] = relationship(
        "PlanEntitlement",
        back_populates="plan",
        cascade="all, delete-orphan",
    )


class Entitlement(BaseDBModel):
    """
    Abstract entitlement definition representing a specific platform privilege
    (e.g., PREMIUM_AUDIO_QUALITY, OFFLINE_DOWNLOADS, UNLIMITED_DOWNLOADS).
    """
    __tablename__ = "entitlements"

    code: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        index=True,
        nullable=False,
    )
    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )
    description: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )

    # Relationships
    plan_entitlements: Mapped[List["PlanEntitlement"]] = relationship(
        "PlanEntitlement",
        back_populates="entitlement",
        cascade="all, delete-orphan",
    )
    grants: Mapped[List["UserEntitlementGrant"]] = relationship(
        "UserEntitlementGrant",
        back_populates="entitlement",
        cascade="all, delete-orphan",
    )


class PlanEntitlement(BaseDBModel):
    """
    Junction mapping associating a subscription plan with the entitlements it grants.
    """
    __tablename__ = "plan_entitlements"
    __table_args__ = (
        UniqueConstraint("plan_id", "entitlement_id", name="uq_plan_entitlement"),
    )

    plan_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("subscription_plans.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    entitlement_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("entitlements.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Relationships
    plan: Mapped["SubscriptionPlan"] = relationship(
        "SubscriptionPlan",
        back_populates="plan_entitlements",
    )
    entitlement: Mapped["Entitlement"] = relationship(
        "Entitlement",
        back_populates="plan_entitlements",
    )


class UserSubscription(BaseDBModel):
    """
    Verified commercial subscription relationship for a user.
    Tracks status, billing provider, renewal period, and grace periods.
    """
    __tablename__ = "user_subscriptions"
    __table_args__ = (
        Index("ix_user_subs_user_status", "user_id", "status"),
        Index("ix_user_subs_current_period_end", "current_period_end"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    plan_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("subscription_plans.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    provider: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="apple",  # "apple", "google", "stripe", "mock"
    )
    provider_subscription_id: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        index=True,
    )
    provider_product_id: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
    )
    original_transaction_id: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        index=True,
    )
    latest_transaction_id: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="PENDING",
        index=True,
        # States: PENDING, ACTIVE, IN_GRACE_PERIOD, PAST_DUE, CANCELED, EXPIRED, REVOKED
    )
    current_period_start: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    current_period_end: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True,
    )
    cancel_at_period_end: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    grace_period_end: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    canceled_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relationships
    user: Mapped["User"] = relationship(
        "User",
        back_populates="subscriptions",
    )
    plan: Mapped["SubscriptionPlan"] = relationship(
        "SubscriptionPlan",
        back_populates="user_subscriptions",
    )
    entitlement_grants: Mapped[List["UserEntitlementGrant"]] = relationship(
        "UserEntitlementGrant",
        back_populates="source_subscription",
        cascade="all, delete-orphan",
    )


class UserEntitlementGrant(BaseDBModel):
    """
    Authoritative grant of an entitlement to a user with effective dates and revocation state.
    """
    __tablename__ = "user_entitlement_grants"
    __table_args__ = (
        Index("ix_user_entitlements_active", "user_id", "entitlement_id", "is_active"),
        Index("ix_user_entitlements_expiry", "user_id", "effective_end"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    entitlement_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("entitlements.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    source_subscription_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("user_subscriptions.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )
    effective_start: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    effective_end: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    revoked_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    revocation_reason: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
    )

    # Relationships
    user: Mapped["User"] = relationship(
        "User",
        back_populates="entitlement_grants",
    )
    entitlement: Mapped["Entitlement"] = relationship(
        "Entitlement",
        back_populates="grants",
    )
    source_subscription: Mapped[Optional["UserSubscription"]] = relationship(
        "UserSubscription",
        back_populates="entitlement_grants",
    )


class SubscriptionTransaction(BaseDBModel):
    """
    Verified store transaction ledger.
    Guarantees idempotency and prevents transaction replay / cross-account token reuse.
    """
    __tablename__ = "subscription_transactions"
    __table_args__ = (
        UniqueConstraint("provider", "transaction_id", name="uq_provider_transaction"),
        Index("ix_transactions_user_id", "user_id"),
        Index("ix_transactions_original_tx", "provider", "original_transaction_id"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    subscription_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("user_subscriptions.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    provider: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
    )
    transaction_id: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True,
    )
    original_transaction_id: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        index=True,
    )
    product_id: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )
    purchase_date: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    expires_date: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    environment: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="Production",
    )
    raw_data_hash: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
    )


class SubscriptionWebhookEvent(BaseDBModel):
    """
    Immutable ledger of provider webhook notifications.
    Deduplicates events and tracks asynchronous processing lifecycle.
    """
    __tablename__ = "subscription_webhook_events"
    __table_args__ = (
        UniqueConstraint("provider", "provider_event_id", name="uq_webhook_provider_event"),
        Index("ix_webhook_events_status", "status"),
    )

    provider: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        index=True,
    )
    provider_event_id: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )
    event_type: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )
    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="RECEIVED",  # "RECEIVED", "PROCESSED", "FAILED", "IGNORED"
    )
    payload_hash: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
    )
    error_message: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )
    processed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
