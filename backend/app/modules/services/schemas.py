"""Contratos del módulo de servicios."""

from datetime import date, datetime
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

ServiceType = Literal["tinacos", "techos", "plomeria", "impermeabilizacion", "calentadores"]
JobStatus = Literal["agendado", "realizado", "cancelado"]


class ServiceJobCreate(BaseModel):
    client_id: UUID
    service_type: ServiceType
    scheduled_for: datetime | None = None
    technician_id: UUID | None = None
    price_cents: Annotated[int, Field(ge=0)] = 0
    notes: str | None = None


class ServiceJobComplete(BaseModel):
    """Cerrar el servicio. Al hacerlo se calcula solo el próximo mantenimiento."""

    performed_on: date | None = None
    price_cents: Annotated[int, Field(ge=0)] | None = None
    is_paid: bool | None = None
    notes: str | None = None
    technician_id: UUID | None = None


class ServiceJobRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    client_id: UUID
    service_type: str
    status: str
    scheduled_for: datetime | None
    performed_on: date | None
    technician_id: UUID | None
    price_cents: int
    is_paid: bool
    notes: str | None
    next_due_on: date | None


class Pendiente(BaseModel):
    """Un cliente al que le toca (o le va a tocar) su mantenimiento."""

    client_id: UUID
    client_name: str
    client_phone: str | None
    service_type: str
    last_service_on: date | None
    due_on: date
    # Positivo = ya se pasó · Negativo = aún faltan días.
    days_overdue: int
