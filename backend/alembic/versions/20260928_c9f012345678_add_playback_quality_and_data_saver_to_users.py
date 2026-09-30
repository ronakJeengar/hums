"""add_playback_quality_and_data_saver_to_users

Revision ID: c9f012345678
Revises: b8e9f0123456
Create Date: 2026-09-28 10:00:00.000000+00:00

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "c9f012345678"
down_revision: Union[str, None] = "b8e9f0123456"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "preferred_streaming_quality",
            sa.String(length=20),
            server_default="AUTO",
            nullable=False,
        ),
    )
    op.add_column(
        "users",
        sa.Column(
            "preferred_mobile_quality",
            sa.String(length=20),
            server_default="LOW",
            nullable=False,
        ),
    )
    op.add_column(
        "users",
        sa.Column(
            "preferred_wifi_quality",
            sa.String(length=20),
            server_default="HIGH",
            nullable=False,
        ),
    )
    op.add_column(
        "users",
        sa.Column(
            "preferred_download_quality",
            sa.String(length=20),
            server_default="HIGH",
            nullable=False,
        ),
    )
    op.add_column(
        "users",
        sa.Column(
            "data_saver_enabled",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "data_saver_enabled")
    op.drop_column("users", "preferred_download_quality")
    op.drop_column("users", "preferred_wifi_quality")
    op.drop_column("users", "preferred_mobile_quality")
    op.drop_column("users", "preferred_streaming_quality")
