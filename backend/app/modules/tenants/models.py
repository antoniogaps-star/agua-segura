"""Modelo Tenant (empresa).

Tabla raíz del multi-tenant: NO lleva `tenant_id` ni RLS; su acceso se controla en la
capa de aplicación. El resto de tablas de negocio referencian su `id`.
Ver docs/04_Base_Datos.md.
"""

from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin, UUIDPrimaryKeyMixin

PLANS = ("free", "pyme", "business", "enterprise")
STATUSES = ("trial", "active", "suspended", "cancelled")


class Tenant(UUIDPrimaryKeyMixin, TimestampMixin, Base):
    __tablename__ = "tenants"
    __table_args__ = (
        CheckConstraint(f"plan IN {PLANS}", name="ck_tenants_plan"),
        CheckConstraint(f"status IN {STATUSES}", name="ck_tenants_status"),
    )

    name: Mapped[str] = mapped_column(String(200), nullable=False)
    slug: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    plan: Mapped[str] = mapped_column(String(20), default="free", server_default="free")
    status: Mapped[str] = mapped_column(String(20), default="trial", server_default="trial")
    # Vence la licencia de pago (null = sin licencia activa o perpetua).
    plan_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
