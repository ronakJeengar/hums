"""create_creators_and_following_tables

Revision ID: a7d8e9f01234
Revises: e3b18c72f109
Create Date: 2026-09-26 12:00:00.000000+00:00

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = "a7d8e9f01234"
down_revision: Union[str, None] = "e3b18c72f109"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create creators table
    op.create_table(
        "creators",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("username", sa.String(length=100), nullable=True),
        sa.Column("bio", sa.Text(), nullable=True),
        sa.Column("avatar_url", sa.String(length=500), nullable=True),
        sa.Column("cover_image_url", sa.String(length=500), nullable=True),
        sa.Column("is_verified", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("followers_count", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.CheckConstraint("followers_count >= 0", name="chk_creators_followers_count_nonnegative"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id"),
        sa.UniqueConstraint("username"),
    )
    op.create_index("ix_creators_name", "creators", ["name"])
    op.create_index("ix_creators_user_id", "creators", ["user_id"])
    op.create_index("ix_creators_username", "creators", ["username"])
    op.create_index("ix_creators_name_lower", "creators", [sa.text("lower(name)")])
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_creators_name_trgm ON creators USING gin (name gin_trgm_ops);"
    )

    # 2. Create creator_followers table
    op.create_table(
        "creator_followers",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("creator_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.ForeignKeyConstraint(["creator_id"], ["creators.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("uq_creator_followers_user_creator", "creator_followers", ["user_id", "creator_id"], unique=True)
    op.create_index("ix_creator_followers_creator_created_at", "creator_followers", ["creator_id", sa.text("created_at DESC")])
    op.create_index("ix_creator_followers_user_created_at", "creator_followers", ["user_id", sa.text("created_at DESC")])

    # 3. Add creator_id column to tracks
    op.add_column(
        "tracks",
        sa.Column("creator_id", postgresql.UUID(as_uuid=True), nullable=True),
    )
    op.create_foreign_key(
        "fk_tracks_creator_id_creators",
        "tracks",
        "creators",
        ["creator_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index("ix_tracks_creator_id", "tracks", ["creator_id"])


def downgrade() -> None:
    op.drop_constraint("fk_tracks_creator_id_creators", "tracks", type_="foreignkey")
    op.drop_index("ix_tracks_creator_id", table_name="tracks")
    op.drop_column("tracks", "creator_id")

    op.drop_index("ix_creator_followers_user_created_at", table_name="creator_followers")
    op.drop_index("ix_creator_followers_creator_created_at", table_name="creator_followers")
    op.drop_index("uq_creator_followers_user_creator", table_name="creator_followers")
    op.drop_table("creator_followers")

    op.execute("DROP INDEX IF EXISTS ix_creators_name_trgm;")
    op.drop_index("ix_creators_name_lower", table_name="creators")
    op.drop_index("ix_creators_username", table_name="creators")
    op.drop_index("ix_creators_user_id", table_name="creators")
    op.drop_index("ix_creators_name", table_name="creators")
    op.drop_table("creators")
