"""Modelo ServiceJob: una visita de servicio, agendada o ya realizada.

Es UNA sola entidad con estado, no dos. En la vida real la visita agendada se convierte
en el servicio realizado: separarlas obligaría a copiar datos y a mantener dos cosas
sincronizadas para nada.

Las FOTOS del antes y el después NO viven aquí: se quedan en el celular del técnico
(igual que en "¿Qué me pongo?"). El certificado se arma y se comparte desde ahí; al
servidor solo viaja la ficha, que es lo que alimenta los recordatorios y el corte de caja.
"""

from datetime import date, datetime
from uuid import UUID

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, SyncMixin, UUIDPrimaryKeyMixin

# Los cinco servicios del negocio.
SERVICE_TYPES = (
    "tinacos",           # lavado y desinfección — el servicio estrella
    "techos",            # mantenimiento de techos
    "plomeria",          # plomería
    "impermeabilizacion",  # impermeabilización de azotea
    "calentadores",      # mantenimiento de calentadores solares
)

STATUSES = ("agendado", "realizado", "cancelado")

# Cada cuántos MESES toca repetir cada servicio. Es el corazón del recordatorio:
# "se me olvida a quién le toca" fue el problema que originó esta app.
# La plomería no aparece porque es correctiva, no preventiva: no se agenda sola.
PERIODICIDAD_MESES: dict[str, int] = {
    "tinacos": 6,
    "techos": 12,
    "calentadores": 12,
    "impermeabilizacion": 24,
}

# Precio sugerido en CENTAVOS, para no teclearlo en cada visita. Es solo una propuesta:
# el técnico siempre puede cambiarlo, porque un tinaco de 1100 L no cuesta igual que uno
# de 450, ni una azotea chica que una grande.
# Lo que NO aparece aquí se cotiza cada vez (0 = sin sugerencia).
PRECIO_SUGERIDO_CENTS: dict[str, int] = {
    "tinacos": 50_000,  # $500.00 MXN
}


class ServiceJob(UUIDPrimaryKeyMixin, SyncMixin, Base):
    __tablename__ = "service_jobs"
    __table_args__ = (
        CheckConstraint(f"service_type IN {SERVICE_TYPES}", name="ck_service_jobs_type"),
        CheckConstraint(f"status IN {STATUSES}", name="ck_service_jobs_status"),
    )

    tenant_id: Mapped[UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), index=True, nullable=False
    )
    client_id: Mapped[UUID] = mapped_column(
        ForeignKey("clients.id", ondelete="CASCADE"), index=True, nullable=False
    )
    service_type: Mapped[str] = mapped_column(String(30), nullable=False)
    status: Mapped[str] = mapped_column(
        String(20), default="agendado", server_default="agendado", nullable=False
    )

    # Cuándo se planeó la visita (la agenda del día).
    scheduled_for: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # Cuándo se hizo de verdad. De aquí sale el cálculo del próximo mantenimiento.
    performed_on: Mapped[date | None] = mapped_column(Date, nullable=True)

    # Qué técnico lo atendió. Nulo mientras no se asigne.
    technician_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )

    # Todo se cobra en efectivo: basta con el monto y si ya se pagó.
    price_cents: Mapped[int] = mapped_column(Integer, default=0, server_default="0", nullable=False)
    is_paid: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False
    )

    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Cuándo toca el siguiente. Se calcula al terminar, pero queda guardado y editable:
    # el dueño puede adelantarlo o retrasarlo si el cliente lo pide.
    next_due_on: Mapped[date | None] = mapped_column(Date, nullable=True)
