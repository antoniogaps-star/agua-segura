"""Modelo License (clave de activación).

Como `tenants`, NO lleva RLS: se genera antes de canjearse y el canje la busca de
forma global. Ver docs/02_Modelo_Negocio.md.
"""

from datetime import datetime
from uuid import UUID

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, UUIDPrimaryKeyMixin

LICENSE_PLANS = ("pyme", "business", "enterprise")


class License(UUIDPrimaryKeyMixin, Base):
    __tablename__ = "licenses"
    __table_args__ = (
        CheckConstraint(f"plan IN {LICENSE_PLANS}", name="ck_licenses_plan"),
    )

    code: Mapped[str] = mapped_column(String(40), unique=True, nullable=False)
    plan: Mapped[str] = mapped_column(String(20), nullable=False)
    # Meses de vigencia (0 = licencia perpetua).
    months: Mapped[int] = mapped_column(Integer, server_default="0", nullable=False)
    redeemed_by: Mapped[UUID | None] = mapped_column(
        ForeignKey("tenants.id", ondelete="SET NULL"), nullable=True
    )
    redeemed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
