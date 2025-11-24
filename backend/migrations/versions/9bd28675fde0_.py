"""empty message

Revision ID: 9bd28675fde0
Revises: 
Create Date: 2025-11-12 09:25:01.624696

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision = '9bd28675fde0'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'users',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('email', sa.String(length=255), nullable=False, unique=True, index=True),
        sa.Column('password_hash', sa.String(length=255), nullable=False),
        sa.Column('role', sa.String(length=50), nullable=False, server_default='viewer'),
        sa.Column('nome_completo', sa.String(length=255), nullable=False),
        sa.Column('perfil', sa.String(length=100)),
        sa.Column('preferencias_sensoriais', sa.Text()),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )

    op.create_table(
        'boards',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('nome', sa.String(length=255), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('ix_boards_user_id', 'boards', ['user_id'])

    op.create_table(
        'entries',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('tipo', sa.String(length=50), nullable=False),
        sa.Column('texto', sa.Text(), nullable=False),
        sa.Column('midia_url', sa.String(length=255)),
        sa.Column('tags', sa.Text()),
        sa.Column('timestamp', sa.DateTime(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('ix_entries_user_id', 'entries', ['user_id'])

    op.create_table(
        'routines',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('titulo', sa.String(length=255), nullable=False),
        sa.Column('lembrete', sa.String(length=120)),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('ix_routines_user_id', 'routines', ['user_id'])

    op.create_table(
        'shares',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('owner_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('viewer_id', sa.Integer(), sa.ForeignKey('users.id')),
        sa.Column('viewer_email', sa.String(length=255), nullable=False),
        sa.Column('escopo', sa.String(length=50), nullable=False),
        sa.Column('expira_em', sa.DateTime()),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('ix_shares_owner_id', 'shares', ['owner_id'])
    op.create_index('ix_shares_viewer_id', 'shares', ['viewer_id'])

    op.create_table(
        'board_items',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('board_id', sa.Integer(), sa.ForeignKey('boards.id'), nullable=False),
        sa.Column('texto', sa.String(length=500), nullable=False),
        sa.Column('img_url', sa.String(length=255)),
        sa.Column('audio_url', sa.String(length=255)),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('ix_board_items_board_id', 'board_items', ['board_id'])

    op.create_table(
        'routine_steps',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('routine_id', sa.Integer(), sa.ForeignKey('routines.id'), nullable=False),
        sa.Column('descricao', sa.String(length=500), nullable=False),
        sa.Column('duracao', sa.Integer()),
        sa.Column('ordem', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('ix_routine_steps_routine_id', 'routine_steps', ['routine_id'])


def downgrade():
    op.drop_index('ix_routine_steps_routine_id', table_name='routine_steps')
    op.drop_table('routine_steps')

    op.drop_index('ix_board_items_board_id', table_name='board_items')
    op.drop_table('board_items')

    op.drop_index('ix_shares_viewer_id', table_name='shares')
    op.drop_index('ix_shares_owner_id', table_name='shares')
    op.drop_table('shares')

    op.drop_index('ix_routines_user_id', table_name='routines')
    op.drop_table('routines')

    op.drop_index('ix_entries_user_id', table_name='entries')
    op.drop_table('entries')

    op.drop_index('ix_boards_user_id', table_name='boards')
    op.drop_table('boards')

    op.drop_table('users')
