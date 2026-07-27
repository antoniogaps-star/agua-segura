"""Modelo User (usuario de una empresa).

Tabla de tenant: lleva `tenant_id` y queda protegida por RLS (ver la migración inicial).
El email es único POR empresa. La contraseña se guarda hasheada con Argon2 (hito 4).
Ver docs/04_Base_Datos.md y docs/09_Seguridad.md.
"""

from uuid import UUID

from sqlalchemy import Boolean, CheckConstraint, ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import CITEXT
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, SyncMixin, UUIDPrimaryKeyMixin

ROLES = ("owner", "admin", "operator", "viewer")


class User(UUIDPrimaryKeyMixin, SyncMixin, Base):
    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint("tenant_id", "email", name="uq_users_tenant_email"),
        CheckConstraint(f"role IN {ROLES}", name="ck_users_role"),
    )

    tenant_id: Mapped[UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), index=True, nullable=False
    )
    email: Mapped[str] = mapped_column(CITEXT, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(20), default="operator", server_default="operator")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
