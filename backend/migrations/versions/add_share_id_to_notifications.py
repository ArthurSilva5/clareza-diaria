"""Add share_id to notifications

Revision ID: add_share_id_notif
Revises: care_links_notif
Create Date: 2024-01-01 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'add_share_id_notif'
down_revision = 'care_links_notif'
branch_labels = None
depends_on = None


def upgrade():
    # Verificar se a coluna já existe antes de adicionar
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    columns = [col['name'] for col in inspector.get_columns('notifications')]
    
    if 'share_id' not in columns:
        # Adicionar coluna share_id à tabela notifications
        op.add_column('notifications', sa.Column('share_id', sa.Integer(), nullable=True))
        op.create_index(op.f('ix_notifications_share_id'), 'notifications', ['share_id'], unique=False)
        op.create_foreign_key('fk_notifications_share_id', 'notifications', 'shares', ['share_id'], ['id'])


def downgrade():
    # Remover foreign key, index e coluna
    op.drop_constraint('fk_notifications_share_id', 'notifications', type_='foreignkey')
    op.drop_index(op.f('ix_notifications_share_id'), table_name='notifications')
    op.drop_column('notifications', 'share_id')

