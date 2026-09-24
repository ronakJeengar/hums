"""add_pg_trgm_and_search_indexes

Revision ID: 51b0b3e77833
Revises: d7edb8b28e26
Create Date: 2026-09-24 15:04:31.589935+00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '51b0b3e77833'
down_revision: Union[str, None] = 'd7edb8b28e26'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Enable pg_trgm extension for trigram similarity and fast substring indexing
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm;")

    # GIN trigram indexes on tracks table
    op.execute("CREATE INDEX IF NOT EXISTS ix_tracks_title_trgm ON tracks USING gin (title gin_trgm_ops);")
    op.execute("CREATE INDEX IF NOT EXISTS ix_tracks_artist_name_trgm ON tracks USING gin (artist_name gin_trgm_ops);")
    op.execute("CREATE INDEX IF NOT EXISTS ix_tracks_album_name_trgm ON tracks USING gin (album_name gin_trgm_ops);")
    op.execute("CREATE INDEX IF NOT EXISTS ix_tracks_genre_trgm ON tracks USING gin (genre gin_trgm_ops);")

    # GIN trigram indexes on playlists table
    op.execute("CREATE INDEX IF NOT EXISTS ix_playlists_name_trgm ON playlists USING gin (name gin_trgm_ops);")
    op.execute("CREATE INDEX IF NOT EXISTS ix_playlists_description_trgm ON playlists USING gin (description gin_trgm_ops);")

    # GIN trigram indexes on users table
    op.execute("CREATE INDEX IF NOT EXISTS ix_users_username_trgm ON users USING gin (username gin_trgm_ops);")
    op.execute("CREATE INDEX IF NOT EXISTS ix_users_full_name_trgm ON users USING gin (full_name gin_trgm_ops);")


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_users_full_name_trgm;")
    op.execute("DROP INDEX IF EXISTS ix_users_username_trgm;")
    op.execute("DROP INDEX IF EXISTS ix_playlists_description_trgm;")
    op.execute("DROP INDEX IF EXISTS ix_playlists_name_trgm;")
    op.execute("DROP INDEX IF EXISTS ix_tracks_genre_trgm;")
    op.execute("DROP INDEX IF EXISTS ix_tracks_album_name_trgm;")
    op.execute("DROP INDEX IF EXISTS ix_tracks_artist_name_trgm;")
    op.execute("DROP INDEX IF EXISTS ix_tracks_title_trgm;")
