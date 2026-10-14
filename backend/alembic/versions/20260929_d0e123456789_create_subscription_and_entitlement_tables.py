"""create_subscription_and_entitlement_tables

Revision ID: d0e123456789
Revises: c9f012345678
Create Date: 2026-09-29 10:00:00.000000+00:00

"""

import uuid
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID


# revision identifiers, used by Alembic.
revision: str = "d0e123456789"
down_revision: Union[str, None] = "c9f012345678"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. subscription_plans
    op.create_table(
        "subscription_plans",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, server_default=sa.text("gen_random_uuid()")),
        sa.Column("code", sa.String(length=50), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("billing_interval", sa.String(length=20), server_default="MONTH", nullable=False),
        sa.Column("price_cents", sa.Integer(), server_default="0", nullable=False),
        sa.Column("currency", sa.String(length=3), server_default="USD", nullable=False),
        sa.Column("apple_product_id", sa.String(length=100), nullable=True),
        sa.Column("google_product_id", sa.String(length=100), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.Column("display_order", sa.Integer(), server_default="0", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_subscription_plans_id", "subscription_plans", ["id"])
    op.create_index("ix_subscription_plans_code", "subscription_plans", ["code"], unique=True)
    op.create_index("ix_subscription_plans_apple_product_id", "subscription_plans", ["apple_product_id"])
    op.create_index("ix_subscription_plans_google_product_id", "subscription_plans", ["google_product_id"])

    # 2. entitlements
    op.create_table(
        "entitlements",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, server_default=sa.text("gen_random_uuid()")),
        sa.Column("code", sa.String(length=50), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_entitlements_id", "entitlements", ["id"])
    op.create_index("ix_entitlements_code", "entitlements", ["code"], unique=True)

    # 3. plan_entitlements
    op.create_table(
        "plan_entitlements",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, server_default=sa.text("gen_random_uuid()")),
        sa.Column("plan_id", UUID(as_uuid=True), sa.ForeignKey("subscription_plans.id", ondelete="CASCADE"), nullable=False),
        sa.Column("entitlement_id", UUID(as_uuid=True), sa.ForeignKey("entitlements.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("plan_id", "entitlement_id", name="uq_plan_entitlement"),
    )
    op.create_index("ix_plan_entitlements_id", "plan_entitlements", ["id"])
    op.create_index("ix_plan_entitlements_plan_id", "plan_entitlements", ["plan_id"])
    op.create_index("ix_plan_entitlements_entitlement_id", "plan_entitlements", ["entitlement_id"])

    # 4. user_subscriptions
    op.create_table(
        "user_subscriptions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("plan_id", UUID(as_uuid=True), sa.ForeignKey("subscription_plans.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("provider", sa.String(length=30), server_default="apple", nullable=False),
        sa.Column("provider_subscription_id", sa.String(length=255), nullable=True),
        sa.Column("provider_product_id", sa.String(length=100), nullable=True),
        sa.Column("original_transaction_id", sa.String(length=255), nullable=True),
        sa.Column("latest_transaction_id", sa.String(length=255), nullable=True),
        sa.Column("status", sa.String(length=30), server_default="PENDING", nullable=False),
        sa.Column("current_period_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("current_period_end", sa.DateTime(timezone=True), nullable=False),
        sa.Column("cancel_at_period_end", sa.Boolean(), server_default="false", nullable=False),
        sa.Column("grace_period_end", sa.DateTime(timezone=True), nullable=True),
        sa.Column("canceled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_user_subscriptions_id", "user_subscriptions", ["id"])
    op.create_index("ix_user_subscriptions_user_id", "user_subscriptions", ["user_id"])
    op.create_index("ix_user_subscriptions_plan_id", "user_subscriptions", ["plan_id"])
    op.create_index("ix_user_subscriptions_status", "user_subscriptions", ["status"])
    op.create_index("ix_user_subscriptions_original_tx", "user_subscriptions", ["original_transaction_id"])
    op.create_index("ix_user_subscriptions_latest_tx", "user_subscriptions", ["latest_transaction_id"])
    op.create_index("ix_user_subs_user_status", "user_subscriptions", ["user_id", "status"])
    op.create_index("ix_user_subs_current_period_end", "user_subscriptions", ["current_period_end"])

    # 5. user_entitlement_grants
    op.create_table(
        "user_entitlement_grants",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("entitlement_id", UUID(as_uuid=True), sa.ForeignKey("entitlements.id", ondelete="CASCADE"), nullable=False),
        sa.Column("source_subscription_id", UUID(as_uuid=True), sa.ForeignKey("user_subscriptions.id", ondelete="CASCADE"), nullable=True),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.Column("effective_start", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("effective_end", sa.DateTime(timezone=True), nullable=True),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("revocation_reason", sa.String(length=255), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_user_entitlement_grants_id", "user_entitlement_grants", ["id"])
    op.create_index("ix_user_entitlement_grants_user_id", "user_entitlement_grants", ["user_id"])
    op.create_index("ix_user_entitlement_grants_entitlement_id", "user_entitlement_grants", ["entitlement_id"])
    op.create_index("ix_user_entitlement_grants_sub_id", "user_entitlement_grants", ["source_subscription_id"])
    op.create_index("ix_user_entitlements_active", "user_entitlement_grants", ["user_id", "entitlement_id", "is_active"])
    op.create_index("ix_user_entitlements_expiry", "user_entitlement_grants", ["user_id", "effective_end"])

    # 6. subscription_transactions
    op.create_table(
        "subscription_transactions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("subscription_id", UUID(as_uuid=True), sa.ForeignKey("user_subscriptions.id", ondelete="SET NULL"), nullable=True),
        sa.Column("provider", sa.String(length=30), nullable=False),
        sa.Column("transaction_id", sa.String(length=255), nullable=False),
        sa.Column("original_transaction_id", sa.String(length=255), nullable=True),
        sa.Column("product_id", sa.String(length=100), nullable=False),
        sa.Column("purchase_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("environment", sa.String(length=20), server_default="Production", nullable=False),
        sa.Column("raw_data_hash", sa.String(length=64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("provider", "transaction_id", name="uq_provider_transaction"),
    )
    op.create_index("ix_subscription_transactions_id", "subscription_transactions", ["id"])
    op.create_index("ix_subscription_transactions_user_id", "subscription_transactions", ["user_id"])
    op.create_index("ix_subscription_transactions_tx_id", "subscription_transactions", ["transaction_id"])
    op.create_index("ix_subscription_transactions_orig_tx_id", "subscription_transactions", ["provider", "original_transaction_id"])

    # 7. subscription_webhook_events
    op.create_table(
        "subscription_webhook_events",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, server_default=sa.text("gen_random_uuid()")),
        sa.Column("provider", sa.String(length=30), nullable=False),
        sa.Column("provider_event_id", sa.String(length=255), nullable=False),
        sa.Column("event_type", sa.String(length=100), nullable=False),
        sa.Column("status", sa.String(length=30), server_default="RECEIVED", nullable=False),
        sa.Column("payload_hash", sa.String(length=64), nullable=False),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("provider", "provider_event_id", name="uq_webhook_provider_event"),
    )
    op.create_index("ix_subscription_webhook_events_id", "subscription_webhook_events", ["id"])
    op.create_index("ix_subscription_webhook_events_provider", "subscription_webhook_events", ["provider"])
    op.create_index("ix_subscription_webhook_events_status", "subscription_webhook_events", ["status"])

    # Seed Default Entitlements and Plans
    seed_entitlements_and_plans()


def seed_entitlements_and_plans() -> None:
    # Stable UUIDs for idempotent seeding
    ent_audio_id = uuid.UUID("11111111-1111-1111-1111-111111111101")
    ent_offline_id = uuid.UUID("11111111-1111-1111-1111-111111111102")
    ent_unlimited_id = uuid.UUID("11111111-1111-1111-1111-111111111103")

    plan_free_id = uuid.UUID("22222222-2222-2222-2222-222222222201")
    plan_monthly_id = uuid.UUID("22222222-2222-2222-2222-222222222202")
    plan_yearly_id = uuid.UUID("22222222-2222-2222-2222-222222222203")

    op.bulk_insert(
        sa.table(
            "entitlements",
            sa.column("id", UUID(as_uuid=True)),
            sa.column("code", sa.String),
            sa.column("name", sa.String),
            sa.column("description", sa.Text),
        ),
        [
            {
                "id": ent_audio_id,
                "code": "PREMIUM_AUDIO_QUALITY",
                "name": "High Fidelity Audio",
                "description": "Access to studio-grade 192 kbps AAC audio streams and renditions.",
            },
            {
                "id": ent_offline_id,
                "code": "OFFLINE_DOWNLOADS",
                "name": "Offline Playback",
                "description": "Download audio tracks to local mobile storage for offline listening.",
            },
            {
                "id": ent_unlimited_id,
                "code": "UNLIMITED_DOWNLOADS",
                "name": "Unlimited Storage",
                "description": "No caps on offline download capacity or simultaneous track storage.",
            },
        ],
    )

    op.bulk_insert(
        sa.table(
            "subscription_plans",
            sa.column("id", UUID(as_uuid=True)),
            sa.column("code", sa.String),
            sa.column("name", sa.String),
            sa.column("description", sa.Text),
            sa.column("billing_interval", sa.String),
            sa.column("price_cents", sa.Integer),
            sa.column("currency", sa.String),
            sa.column("apple_product_id", sa.String),
            sa.column("google_product_id", sa.String),
            sa.column("is_active", sa.Boolean),
            sa.column("display_order", sa.Integer),
        ),
        [
            {
                "id": plan_free_id,
                "code": "FREE",
                "name": "Hums Free",
                "description": "Standard audio fidelity (up to 128 kbps), streaming discovery, and playlist creation.",
                "billing_interval": "NONE",
                "price_cents": 0,
                "currency": "USD",
                "apple_product_id": None,
                "google_product_id": None,
                "is_active": True,
                "display_order": 1,
            },
            {
                "id": plan_monthly_id,
                "code": "PREMIUM_MONTHLY",
                "name": "Hums Premium Monthly",
                "description": "High fidelity audio (192 kbps AAC), offline downloads, unlimited playlists, and zero ads.",
                "billing_interval": "MONTH",
                "price_cents": 999,
                "currency": "USD",
                "apple_product_id": "app.hums.premium.monthly",
                "google_product_id": "app.hums.premium.monthly",
                "is_active": True,
                "display_order": 2,
            },
            {
                "id": plan_yearly_id,
                "code": "PREMIUM_YEARLY",
                "name": "Hums Premium Annual",
                "description": "All Premium features with 2 months free ($99.99/year billed annually).",
                "billing_interval": "YEAR",
                "price_cents": 9999,
                "currency": "USD",
                "apple_product_id": "app.hums.premium.yearly",
                "google_product_id": "app.hums.premium.yearly",
                "is_active": True,
                "display_order": 3,
            },
        ],
    )

    op.bulk_insert(
        sa.table(
            "plan_entitlements",
            sa.column("id", UUID(as_uuid=True)),
            sa.column("plan_id", UUID(as_uuid=True)),
            sa.column("entitlement_id", UUID(as_uuid=True)),
        ),
        [
            # Monthly plan grants
            {"id": uuid.uuid4(), "plan_id": plan_monthly_id, "entitlement_id": ent_audio_id},
            {"id": uuid.uuid4(), "plan_id": plan_monthly_id, "entitlement_id": ent_offline_id},
            {"id": uuid.uuid4(), "plan_id": plan_monthly_id, "entitlement_id": ent_unlimited_id},
            # Yearly plan grants
            {"id": uuid.uuid4(), "plan_id": plan_yearly_id, "entitlement_id": ent_audio_id},
            {"id": uuid.uuid4(), "plan_id": plan_yearly_id, "entitlement_id": ent_offline_id},
            {"id": uuid.uuid4(), "plan_id": plan_yearly_id, "entitlement_id": ent_unlimited_id},
        ],
    )


def downgrade() -> None:
    op.drop_table("subscription_webhook_events")
    op.drop_table("subscription_transactions")
    op.drop_table("user_entitlement_grants")
    op.drop_table("user_subscriptions")
    op.drop_table("plan_entitlements")
    op.drop_table("entitlements")
    op.drop_table("subscription_plans")
