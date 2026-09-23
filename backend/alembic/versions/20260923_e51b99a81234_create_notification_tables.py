"""create_notification_tables

Revision ID: e51b99a81234
Revises: d7edb8b28e26
Create Date: 2026-09-23 16:30:00.000000+00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'e51b99a81234'
down_revision: Union[str, None] = 'd7edb8b28e26'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. user_devices
    op.create_table(
        'user_devices',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('device_token', sa.String(length=500), nullable=False),
        sa.Column('platform', sa.String(length=20), server_default='ANDROID', nullable=False),
        sa.Column('device_name', sa.String(length=100), nullable=True),
        sa.Column('app_version', sa.String(length=50), nullable=True),
        sa.Column('is_active', sa.Boolean(), server_default=sa.text('true'), nullable=False),
        sa.Column('last_seen_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_user_devices_id'), 'user_devices', ['id'], unique=False)
    op.create_index(op.f('ix_user_devices_user_id'), 'user_devices', ['user_id'], unique=False)
    op.create_index(op.f('ix_user_devices_device_token'), 'user_devices', ['device_token'], unique=True)
    op.create_index('ix_user_devices_user_id_is_active', 'user_devices', ['user_id', 'is_active'], unique=False)

    # 2. notifications
    op.create_table(
        'notifications',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('type', sa.String(length=50), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('body', sa.Text(), nullable=False),
        sa.Column('data', postgresql.JSONB(astext_type=sa.Text()), server_default=sa.text("'{}'::jsonb"), nullable=True),
        sa.Column('is_read', sa.Boolean(), server_default=sa.text('false'), nullable=False),
        sa.Column('read_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('idempotency_key', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_notifications_id'), 'notifications', ['id'], unique=False)
    op.create_index(op.f('ix_notifications_user_id'), 'notifications', ['user_id'], unique=False)
    op.create_index(op.f('ix_notifications_type'), 'notifications', ['type'], unique=False)
    op.create_index(op.f('ix_notifications_idempotency_key'), 'notifications', ['idempotency_key'], unique=True)
    op.create_index('ix_notifications_user_id_created_at', 'notifications', ['user_id', 'created_at'], unique=False)
    op.create_index('ix_notifications_user_id_is_read', 'notifications', ['user_id', 'is_read'], unique=False)

    # 3. notification_preferences
    op.create_table(
        'notification_preferences',
        sa.Column('id', sa.UUID(), server_default=sa.text('gen_random_uuid()'), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('push_enabled', sa.Boolean(), server_default=sa.text('true'), nullable=False),
        sa.Column('new_releases_enabled', sa.Boolean(), server_default=sa.text('true'), nullable=False),
        sa.Column('playlist_updates_enabled', sa.Boolean(), server_default=sa.text('true'), nullable=False),
        sa.Column('recommendations_enabled', sa.Boolean(), server_default=sa.text('true'), nullable=False),
        sa.Column('processing_updates_enabled', sa.Boolean(), server_default=sa.text('true'), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_notification_preferences_id'), 'notification_preferences', ['id'], unique=False)
    op.create_index(op.f('ix_notification_preferences_user_id'), 'notification_preferences', ['user_id'], unique=True)


def downgrade() -> None:
    op.drop_table('notification_preferences')
    op.drop_table('notifications')
    op.drop_table('user_devices')
