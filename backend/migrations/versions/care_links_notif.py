"""add care_links and notifications tables

Revision ID: care_links_notif
Revises: 20251112_emoji_category
Create Date: 2025-11-20 10:50:00.000000
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision = 'care_links_notif'
down_revision = '20251112_emoji_category'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Check if tables already exist (from partial migration)
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    existing_tables = inspector.get_table_names()
    
    # Create care_links table if it doesn't exist
    if 'care_links' not in existing_tables:
        op.create_table(
            'care_links',
            sa.Column('id', sa.Integer(), nullable=False, autoincrement=True),
            sa.Column('cuidador_id', sa.Integer(), nullable=False),
            sa.Column('pessoa_tea_id', sa.Integer(), nullable=False),
            sa.Column('status', sa.String(length=50), nullable=False, server_default='pending'),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.Column('updated_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['cuidador_id'], ['users.id'], ),
            sa.ForeignKeyConstraint(['pessoa_tea_id'], ['users.id'], ),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint('cuidador_id', 'pessoa_tea_id', name='unique_care_link')
        )
        op.create_index('ix_care_links_cuidador_id', 'care_links', ['cuidador_id'])
        op.create_index('ix_care_links_pessoa_tea_id', 'care_links', ['pessoa_tea_id'])
    else:
        # Tables exist, just create indexes if they don't exist
        existing_indexes = [idx['name'] for idx in inspector.get_indexes('care_links')]
        if 'ix_care_links_cuidador_id' not in existing_indexes:
            op.create_index('ix_care_links_cuidador_id', 'care_links', ['cuidador_id'])
        if 'ix_care_links_pessoa_tea_id' not in existing_indexes:
            op.create_index('ix_care_links_pessoa_tea_id', 'care_links', ['pessoa_tea_id'])

    # Create notifications table if it doesn't exist
    if 'notifications' not in existing_tables:
        op.create_table(
            'notifications',
            sa.Column('id', sa.Integer(), nullable=False, autoincrement=True),
            sa.Column('user_id', sa.Integer(), nullable=False),
            sa.Column('tipo', sa.String(length=50), nullable=False),
            sa.Column('titulo', sa.String(length=255), nullable=False),
            sa.Column('mensagem', sa.Text(), nullable=False),
            sa.Column('lida', sa.Boolean(), nullable=False, server_default='0'),
            sa.Column('care_link_id', sa.Integer(), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.Column('updated_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
            sa.ForeignKeyConstraint(['care_link_id'], ['care_links.id'], ),
            sa.PrimaryKeyConstraint('id')
        )
        op.create_index('ix_notifications_user_id', 'notifications', ['user_id'])
        op.create_index('ix_notifications_care_link_id', 'notifications', ['care_link_id'])
    else:
        # Table exists, just create indexes if they don't exist
        existing_indexes = [idx['name'] for idx in inspector.get_indexes('notifications')]
        if 'ix_notifications_user_id' not in existing_indexes:
            op.create_index('ix_notifications_user_id', 'notifications', ['user_id'])
        if 'ix_notifications_care_link_id' not in existing_indexes:
            op.create_index('ix_notifications_care_link_id', 'notifications', ['care_link_id'])


def downgrade() -> None:
    op.drop_index('ix_notifications_care_link_id', table_name='notifications')
    op.drop_index('ix_notifications_user_id', table_name='notifications')
    op.drop_table('notifications')
    op.drop_index('ix_care_links_pessoa_tea_id', table_name='care_links')
    op.drop_index('ix_care_links_cuidador_id', table_name='care_links')
    op.drop_table('care_links')

