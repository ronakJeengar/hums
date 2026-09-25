"""create_playback_history_and_progress_tables

Revision ID: e3b18c72f109
Revises: f8957d4b8b3a
Create Date: 2026-09-25 15:45:00.000000+00:00

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = "e3b18c72f109"
down_revision: Union[str, None] = "f8957d4b8b3a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create playback_progress table
    op.create_table(
        "playback_progress",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("track_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("position_ms", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("duration_ms", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("completed", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["track_id"], ["tracks.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "track_id", name="uq_playback_progress_user_track"),
    )
    op.create_index("ix_playback_progress_user_id", "playback_progress", ["user_id"])
    op.create_index("ix_playback_progress_track_id", "playback_progress", ["track_id"])
    op.create_index(
        "ix_playback_progress_user_updated",
        "playback_progress",
        ["user_id", sa.text("updated_at DESC")],
    )

    # 2. Create playback_events table
    op.create_table(
        "playback_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("track_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("event_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("event_type", sa.String(length=50), nullable=False),
        sa.Column("position_ms", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("duration_ms", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("source", sa.String(length=50), nullable=False, server_default="player"),
        sa.Column("device_id", sa.String(length=100), nullable=True),
        sa.Column("played_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["track_id"], ["tracks.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "event_id", name="uq_playback_events_user_event_id"),
    )
    op.create_index("ix_playback_events_user_id", "playback_events", ["user_id"])
    op.create_index("ix_playback_events_track_id", "playback_events", ["track_id"])
    op.create_index("ix_playback_events_event_id", "playback_events", ["event_id"])
    op.create_index(
        "ix_playback_events_user_played_at",
        "playback_events",
        ["user_id", sa.text("played_at DESC")],
    )
    op.create_index("ix_playback_events_user_track", "playback_events", ["user_id", "track_id"])


def downgrade() -> None:
    op.drop_index("ix_playback_events_user_track", table_name="playback_events")
    op.drop_index("ix_playback_events_user_played_at", table_name="playback_events")
    op.drop_index("ix_playback_events_event_id", table_name="playback_events")
    op.drop_index("ix_playback_events_track_id", table_name="playback_events")
    op.drop_index("ix_playback_events_user_id", table_name="playback_events")
    op.drop_table("playback_events")

    op.drop_index("ix_playback_progress_user_updated", table_name="playback_progress")
    op.drop_index("ix_playback_progress_track_id", table_name="playback_progress")
    op.drop_index("ix_playback_progress_user_id", table_name="playback_progress")
    op.drop_table("playback_progress")
