"""Nombre del usuario, para mostrar quién hace cada trabajo.

El correo sirve para entrar; en la agenda hay que ver "Luis", no
"luis.martinez.tecnico@gmail.com".

Revision ID: 0003
Revises: 0002
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0003"
down_revision: str | None = "0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("users", sa.Column("name", sa.String(length=120), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "name")
