"""add_performance_composite_indexes

Revision ID: f8957d4b8b3a
Revises: d7edb8b28e26
Create Date: 2026-09-24 15:51:22.460747+00:00

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "f8957d4b8b3a"
down_revision: Union[str, None] = "d7edb8b28e26"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Composite index for catalog / ready tracks feed queries: WHERE status = 'READY' ORDER BY created_at DESC
    op.create_index(
        "ix_tracks_status_created_at",
        "tracks",
        ["status", sa.text("created_at DESC")],
    )

    # 2. Composite index for user uploaded tracks queries: WHERE owner_id = :id ORDER BY created_at DESC
    op.create_index(
        "ix_tracks_owner_id_created_at",
        "tracks",
        ["owner_id", sa.text("created_at DESC")],
    )

    # 3. Composite index for user playlists queries: WHERE owner_id = :id ORDER BY created_at DESC
    op.create_index(
        "ix_playlists_owner_id_created_at",
        "playlists",
        ["owner_id", sa.text("created_at DESC")],
    )

    # 4. Composite index for public playlists queries: WHERE is_public = true ORDER BY created_at DESC
    op.create_index(
        "ix_playlists_is_public_created_at",
        "playlists",
        ["is_public", sa.text("created_at DESC")],
    )

    # 5. Composite index for ordered playlist track retrieval: WHERE playlist_id = :id ORDER BY position ASC
    op.create_index(
        "ix_playlist_tracks_playlist_id_position",
        "playlist_tracks",
        ["playlist_id", "position"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_playlist_tracks_playlist_id_position", table_name="playlist_tracks"
    )
    op.drop_index("ix_playlists_is_public_created_at", table_name="playlists")
    op.drop_index("ix_playlists_owner_id_created_at", table_name="playlists")
    op.drop_index("ix_tracks_owner_id_created_at", table_name="tracks")
    op.drop_index("ix_tracks_status_created_at", table_name="tracks")
