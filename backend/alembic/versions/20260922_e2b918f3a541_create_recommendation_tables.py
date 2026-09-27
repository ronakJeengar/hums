"""create_recommendation_tables

Revision ID: e2b918f3a541
Revises: d7edb8b28e26
Create Date: 2026-09-22 16:00:00.000000+00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e2b918f3a541'
down_revision: Union[str, None] = 'd7edb8b28e26'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add index on tracks.genre for fast recommendation candidate lookups
    op.create_index(op.f('ix_tracks_genre'), 'tracks', ['genre'], unique=False)

    # 2. Create recommendation_sets table
    op.create_table(
        'recommendation_sets',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('algorithm_version', sa.String(length=50), nullable=False, server_default='v1-hybrid'),
        sa.Column('model_name', sa.String(length=100), nullable=True),
        sa.Column('prompt_version', sa.String(length=50), nullable=True),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_recommendation_sets_id'), 'recommendation_sets', ['id'], unique=False)
    op.create_index(op.f('ix_recommendation_sets_user_id'), 'recommendation_sets', ['user_id'], unique=False)
    op.create_index(op.f('ix_recommendation_sets_expires_at'), 'recommendation_sets', ['expires_at'], unique=False)

    # 3. Create recommendation_items table
    op.create_table(
        'recommendation_items',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('recommendation_set_id', sa.UUID(), nullable=False),
        sa.Column('track_id', sa.UUID(), nullable=False),
        sa.Column('section', sa.String(length=50), nullable=False),
        sa.Column('position', sa.Integer(), nullable=False, server_default=sa.text('0')),
        sa.Column('score', sa.Float(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['recommendation_set_id'], ['recommendation_sets.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['track_id'], ['tracks.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('recommendation_set_id', 'section', 'track_id', name='uq_rec_items_set_section_track')
    )
    op.create_index(op.f('ix_recommendation_items_id'), 'recommendation_items', ['id'], unique=False)
    op.create_index(op.f('ix_recommendation_items_recommendation_set_id'), 'recommendation_items', ['recommendation_set_id'], unique=False)
    op.create_index(op.f('ix_recommendation_items_track_id'), 'recommendation_items', ['track_id'], unique=False)
    op.create_index(op.f('ix_recommendation_items_section'), 'recommendation_items', ['section'], unique=False)
    op.create_index(op.f('ix_recommendation_items_position'), 'recommendation_items', ['position'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_recommendation_items_position'), table_name='recommendation_items')
    op.drop_index(op.f('ix_recommendation_items_section'), table_name='recommendation_items')
    op.drop_index(op.f('ix_recommendation_items_track_id'), table_name='recommendation_items')
    op.drop_index(op.f('ix_recommendation_items_recommendation_set_id'), table_name='recommendation_items')
    op.drop_index(op.f('ix_recommendation_items_id'), table_name='recommendation_items')
    op.drop_table('recommendation_items')

    op.drop_index(op.f('ix_recommendation_sets_expires_at'), table_name='recommendation_sets')
    op.drop_index(op.f('ix_recommendation_sets_user_id'), table_name='recommendation_sets')
    op.drop_index(op.f('ix_recommendation_sets_id'), table_name='recommendation_sets')
    op.drop_table('recommendation_sets')

    op.drop_index(op.f('ix_tracks_genre'), table_name='tracks')
