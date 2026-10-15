"""add_track_publishing_and_cover

Revision ID: f2a345678901
Revises: e1f234567890
Create Date: 2026-10-15 16:00:00.000000+00:00

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "f2a345678901"
down_revision: Union[str, None] = "e1f234567890"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add is_published to tracks table (defaults to true for existing catalog)
    op.add_column(
        "tracks",
        sa.Column("is_published", sa.Boolean(), server_default=sa.text("true"), nullable=False),
    )
    op.create_index("ix_tracks_is_published", "tracks", ["is_published"])

    # 2. Add cover_image_key to tracks table
    op.add_column(
        "tracks",
        sa.Column("cover_image_key", sa.String(length=500), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("tracks", "cover_image_key")
    op.drop_index("ix_tracks_is_published", table_name="tracks")
    op.drop_column("tracks", "is_published")
