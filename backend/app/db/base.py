"""Base declarativa de SQLAlchemy y mixins de columnas estándar.

Toda tabla de tenant comparte un conjunto de columnas (ver docs/04_Base_Datos.md):
- id: UUIDv7 generado en cliente (PK)
- created_at / updated_at
- is_deleted (tombstone) y version — para la sincronización offline
"""

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import BigInteger, Boolean, DateTime, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

from app.shared.ids import uuid7


class Base(DeclarativeBase):
    """Base declarativa común a todos los modelos."""


def utcnow() -> datetime:
    return datetime.now(UTC)


class UUIDPrimaryKeyMixin:
    """PK UUIDv7 generada en el cliente/servidor (no autoincrement)."""

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid7)


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        onupdate=utcnow,
        server_default=func.now(),
        nullable=False,
    )


class SyncMixin(TimestampMixin):
    """Columnas para entidades sincronizables (offline-first).

    `version` y `updated_at` habilitan la resolución de conflictos; `is_deleted`
    permite propagar borrados como tombstones.
    """

    is_deleted: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False
    )
    version: Mapped[int] = mapped_column(
        BigInteger, default=1, server_default="1", nullable=False
    )
