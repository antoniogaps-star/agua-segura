"""Modelo Client (el cliente del negocio: una casa, un edificio, un local).

Tabla de tenant, sincronizable (LWW). Los clientes llegan por recomendación, así que
cada uno vale mucho: por eso guardamos las referencias para llegar — en estas colonias
la dirección sola no basta.
"""

from uuid import UUID

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, SyncMixin, UUIDPrimaryKeyMixin


class Client(UUIDPrimaryKeyMixin, SyncMixin, Base):
    __tablename__ = "clients"

    tenant_id: Mapped[UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), index=True, nullable=False
    )
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    # Teléfono de WhatsApp: es por donde se manda el recordatorio y el certificado.
    phone: Mapped[str | None] = mapped_column(String(50), nullable=True)
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Cómo llegar: "portón verde, junto a la tienda", "tocar en el 3B". El técnico las
    # necesita más que la dirección formal.
    directions: Mapped[str | None] = mapped_column(Text, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Quién lo recomendó. Los clientes llegan por recomendación, así que saber de dónde
    # vino cada uno dice a quién hay que agradecerle — y a quién pedirle la siguiente.
    # Se apunta a otro cliente de la misma empresa; SET NULL para que borrar al que
    # recomendó no se lleve al recomendado.
    referred_by_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("clients.id", ondelete="SET NULL"), nullable=True
    )
