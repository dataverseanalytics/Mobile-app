"""payments amount in minor units

Revision ID: fd927cb9c43a
Revises: cf1163b08d3f
Create Date: 2026-11-21 10:10:59.136128

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'fd927cb9c43a'
down_revision: Union[str, Sequence[str], None] = 'cf1163b08d3f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Payments can be in any currency now: amounts are in minor units."""
    # Rename (not drop/add) so existing payment rows keep their amounts.
    op.alter_column("payments", "amount_paise", new_column_name="amount_minor")


def downgrade() -> None:
    op.alter_column("payments", "amount_minor", new_column_name="amount_paise")
