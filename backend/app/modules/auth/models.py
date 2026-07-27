"""Modelo RefreshToken: permite revocar sesiones (logout, rotación).

Se guarda solo el HASH del refresh token (no el token en claro). Cada refresh emitido
crea una fila; al usarse se rota (se revoca el anterior y se emite uno nuevo); logout lo
revoca. Ver ADR-004 y docs/09_Seguridad.md.
"""

from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin


class AdminConfig(Base):
    """Secreto de administrador de la plataforma, configurado por el dueño DESDE LA
    APP (no depende de variables de entorno). Fila única (id=1). Se guarda el HASH,
    nunca el secreto en claro. Sin RLS: no es por-tenant, se controla en la app."""

    __tablename__ = "admin_config"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)
    secret_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class RefreshToken(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "refresh_tokens"

    tenant_id: Mapped[UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), index=True, nullable=False
    )
    user_id: Mapped[UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
