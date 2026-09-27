"""create_lyrics_and_lyric_lines

Revision ID: c9f0a1234567
Revises: b8e9f0123456
Create Date: 2026-09-28 10:00:00.000000+00:00

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = "c9f0a1234567"
down_revision: Union[str, None] = "b8e9f0123456"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create lyrics table
    op.create_table(
        "lyrics",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("track_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("status", sa.String(50), server_default="PENDING", nullable=False),
        sa.Column("language", sa.String(10), nullable=True),
        sa.Column("text", sa.Text(), nullable=True),
        sa.Column("source", sa.String(50), server_default="AI_GENERATED", nullable=False),
        sa.Column("is_synchronized", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("model", sa.String(100), nullable=True),
        sa.Column("version", sa.String(20), server_default="v1", nullable=False),
        sa.Column("error_message", sa.Text(), nullable=True),
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
            name="fk_lyrics_track_id",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("track_id", name="uq_lyrics_track_id"),
    )

    op.create_index(
        "ix_lyrics_track_id",
        "lyrics",
        ["track_id"],
        unique=True,
    )
    op.create_index(
        "ix_lyrics_status",
        "lyrics",
        ["status"],
        unique=False,
    )

    # 2. Create lyric_lines table
    op.create_table(
        "lyric_lines",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("lyrics_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("sequence", sa.Integer(), nullable=False),
        sa.Column("start_ms", sa.Integer(), nullable=False),
        sa.Column("end_ms", sa.Integer(), nullable=True),
        sa.Column("text", sa.Text(), nullable=False),
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
            ["lyrics_id"],
            ["lyrics.id"],
            name="fk_lyric_lines_lyrics_id",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        "ix_lyric_lines_lyrics_id",
        "lyric_lines",
        ["lyrics_id"],
        unique=False,
    )
    op.create_index(
        "ix_lyric_lines_lyrics_sequence",
        "lyric_lines",
        ["lyrics_id", "sequence"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_lyric_lines_lyrics_sequence", table_name="lyric_lines")
    op.drop_index("ix_lyric_lines_lyrics_id", table_name="lyric_lines")
    op.drop_table("lyric_lines")
    op.drop_index("ix_lyrics_status", table_name="lyrics")
    op.drop_index("ix_lyrics_track_id", table_name="lyrics")
    op.drop_table("lyrics")
