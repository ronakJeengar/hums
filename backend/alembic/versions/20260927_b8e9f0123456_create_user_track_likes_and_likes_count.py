"""create_user_track_likes_and_likes_count

Revision ID: b8e9f0123456
Revises: a7d8e9f01234
Create Date: 2026-09-27 10:00:00.000000+00:00

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = "b8e9f0123456"
down_revision: Union[str, None] = "a7d8e9f01234"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add likes_count column to tracks table
    op.add_column(
        "tracks",
        sa.Column("likes_count", sa.Integer(), server_default="0", nullable=False),
    )
    op.create_index(
        "ix_tracks_likes_count",
        "tracks",
        ["likes_count"],
        unique=False,
    )

    # 2. Create user_track_likes table
    op.create_table(
        "user_track_likes",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("track_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["track_id"],
            ["tracks.id"],
            name="fk_user_track_likes_track_id",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_user_track_likes_user_id",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "track_id", name="uq_user_track_likes_user_track"),
    )

    # 3. Create indexes on user_track_likes
    op.create_index(
        "ix_user_track_likes_user_id",
        "user_track_likes",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_user_track_likes_track_id",
        "user_track_likes",
        ["track_id"],
        unique=False,
    )
    op.create_index(
        "ix_user_track_likes_user_created",
        "user_track_likes",
        ["user_id", sa.text("created_at DESC")],
        unique=False,
    )
    op.create_index(
        "ix_user_track_likes_track_created",
        "user_track_likes",
        ["track_id", sa.text("created_at DESC")],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_user_track_likes_track_created", table_name="user_track_likes")
    op.drop_index("ix_user_track_likes_user_created", table_name="user_track_likes")
    op.drop_index("ix_user_track_likes_track_id", table_name="user_track_likes")
    op.drop_index("ix_user_track_likes_user_id", table_name="user_track_likes")
    op.drop_table("user_track_likes")
    op.drop_index("ix_tracks_likes_count", table_name="tracks")
    op.drop_column("tracks", "likes_count")
