"""add_admin_creator_studio_tables

Revision ID: e1f234567890
Revises: d0e123456789
Create Date: 2026-10-14 16:00:00.000000+00:00

"""

import uuid
from typing import Sequence, Union
import bcrypt

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID


# revision identifiers, used by Alembic.
revision: str = "e1f234567890"
down_revision: Union[str, None] = "d0e123456789"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def hash_pw(pw: str) -> str:
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(pw.encode("utf-8"), salt).decode("utf-8")


def upgrade() -> None:
    # 1. Add role & suspension columns to users table
    op.add_column(
        "users",
        sa.Column("role", sa.String(length=50), server_default="listener", nullable=False),
    )
    op.create_index("ix_users_role", "users", ["role"])
    op.add_column(
        "users",
        sa.Column("suspension_reason", sa.String(length=500), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("suspended_at", sa.DateTime(timezone=True), nullable=True),
    )

    # 2. Creator applications table
    op.create_table(
        "creator_applications",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("artist_name", sa.String(length=255), nullable=False),
        sa.Column("bio", sa.Text(), nullable=True),
        sa.Column("genres", sa.String(length=255), nullable=True),
        sa.Column("portfolio_url", sa.String(length=500), nullable=True),
        sa.Column("status", sa.String(length=50), server_default="PENDING", nullable=False),
        sa.Column("reviewer_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("review_notes", sa.Text(), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_creator_apps_user_id", "creator_applications", ["user_id"])
    op.create_index("ix_creator_apps_status", "creator_applications", ["status"])
    op.create_index("ix_creator_apps_status_created", "creator_applications", ["status", "created_at"])
    op.create_index("ix_creator_apps_user_status", "creator_applications", ["user_id", "status"])

    # 3. Content reports table
    op.create_table(
        "content_reports",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, server_default=sa.text("gen_random_uuid()")),
        sa.Column("reporter_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("entity_type", sa.String(length=50), nullable=False),
        sa.Column("entity_id", UUID(as_uuid=True), nullable=False),
        sa.Column("reason", sa.String(length=100), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("status", sa.String(length=50), server_default="PENDING", nullable=False),
        sa.Column("moderator_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("resolution_notes", sa.Text(), nullable=True),
        sa.Column("action_taken", sa.String(length=100), nullable=True),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_content_reports_reporter_id", "content_reports", ["reporter_id"])
    op.create_index("ix_content_reports_entity_type", "content_reports", ["entity_type"])
    op.create_index("ix_content_reports_entity_id", "content_reports", ["entity_id"])
    op.create_index("ix_content_reports_status", "content_reports", ["status"])
    op.create_index("ix_content_reports_status_created", "content_reports", ["status", "created_at"])
    op.create_index("ix_content_reports_entity", "content_reports", ["entity_type", "entity_id"])

    # 4. Admin audit logs table
    op.create_table(
        "admin_audit_logs",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, server_default=sa.text("gen_random_uuid()")),
        sa.Column("actor_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("actor_email", sa.String(length=255), nullable=False),
        sa.Column("action", sa.String(length=100), nullable=False),
        sa.Column("target_type", sa.String(length=50), nullable=False),
        sa.Column("target_id", sa.String(length=255), nullable=False),
        sa.Column("details", JSONB, nullable=True),
        sa.Column("reason", sa.String(length=500), nullable=True),
        sa.Column("ip_address", sa.String(length=45), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_admin_audit_logs_actor", "admin_audit_logs", ["actor_id", "created_at"])
    op.create_index("ix_admin_audit_logs_action", "admin_audit_logs", ["action", "created_at"])
    op.create_index("ix_admin_audit_logs_target", "admin_audit_logs", ["target_type", "target_id"])

    # 5. Seed default administrator and creator accounts
    conn = op.get_bind()
    admin_pw = hash_pw("AdminPassword123!")
    creator_pw = hash_pw("CreatorPassword123!")

    # Check if admin user already exists
    res = conn.execute(sa.text("SELECT id FROM users WHERE email = 'admin@hums.app'"))
    admin_row = res.fetchone()
    admin_id = str(uuid.uuid4())
    if not admin_row:
        conn.execute(
            sa.text("""
                INSERT INTO users (id, email, username, hashed_password, full_name, role, is_active, is_verified, created_at, updated_at)
                VALUES (:id, 'admin@hums.app', 'humsadmin', :pw, 'Hums Administrator', 'admin', true, true, NOW(), NOW())
            """),
            {"id": admin_id, "pw": admin_pw},
        )
    else:
        conn.execute(
            sa.text("UPDATE users SET role = 'admin' WHERE email = 'admin@hums.app'")
        )

    # Check if creator user already exists
    res = conn.execute(sa.text("SELECT id FROM users WHERE email = 'creator@hums.app'"))
    creator_row = res.fetchone()
    creator_user_id = str(uuid.uuid4())
    if not creator_row:
        conn.execute(
            sa.text("""
                INSERT INTO users (id, email, username, hashed_password, full_name, role, is_active, is_verified, created_at, updated_at)
                VALUES (:id, 'creator@hums.app', 'humscreator', :pw, 'Hums Studio Artist', 'creator', true, true, NOW(), NOW())
            """),
            {"id": creator_user_id, "pw": creator_pw},
        )
        # Create linked Creator profile
        creator_profile_id = str(uuid.uuid4())
        conn.execute(
            sa.text("""
                INSERT INTO creators (id, user_id, name, username, bio, is_verified, followers_count, created_at, updated_at)
                VALUES (:id, :user_id, 'Hums Studio Artist', 'humscreator', 'Official acoustic creator on Hums Studio.', true, 42, NOW(), NOW())
            """),
            {"id": creator_profile_id, "user_id": creator_user_id},
        )
    else:
        conn.execute(
            sa.text("UPDATE users SET role = 'creator' WHERE email = 'creator@hums.app'")
        )


def downgrade() -> None:
    op.drop_table("admin_audit_logs")
    op.drop_table("content_reports")
    op.drop_table("creator_applications")
    op.drop_index("ix_users_role", table_name="users")
    op.drop_column("users", "suspended_at")
    op.drop_column("users", "suspension_reason")
    op.drop_column("users", "role")
