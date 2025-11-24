"""add emoji and category columns to board items

Revision ID: 20251112_emoji_category
Revises: 9bd28675fde0
Create Date: 2025-11-12 12:00:00.000000
"""

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '20251112_emoji_category'
down_revision = '9bd28675fde0'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('board_items', sa.Column('emoji', sa.String(length=16), nullable=True))
    op.add_column('board_items', sa.Column('categoria', sa.String(length=100), nullable=True))


def downgrade() -> None:
    op.drop_column('board_items', 'categoria')
    op.drop_column('board_items', 'emoji')











