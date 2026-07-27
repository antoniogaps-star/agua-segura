"""Quién recomendó a cada cliente.

Los clientes de este negocio llegan por recomendación, así que guardar de dónde vino
cada uno es información de venta, no un dato administrativo: dice a quién agradecerle
y a quién volver a pedirle.

Revision ID: 0002
Revises: 0001
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0002"
down_revision: str | None = "0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("clients", sa.Column("referred_by_id", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        "fk_clients_referred_by",
        "clients",
        "clients",
        ["referred_by_id"],
        ["id"],
        # SET NULL: borrar a quien recomendó no debe llevarse al recomendado.
        ondelete="SET NULL",
    )
    op.create_index("ix_clients_referred_by_id", "clients", ["referred_by_id"])


def downgrade() -> None:
    op.drop_index("ix_clients_referred_by_id", table_name="clients")
    op.drop_constraint("fk_clients_referred_by", "clients", type_="foreignkey")
    op.drop_column("clients", "referred_by_id")
