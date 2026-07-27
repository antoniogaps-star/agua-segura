"""Contratos del módulo de clientes."""

from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ClientCreate(BaseModel):
    name: Annotated[str, Field(min_length=1, max_length=200)]
    phone: str | None = None
    address: str | None = None
    # Cómo llegar: el técnico las necesita más que la calle y el número.
    directions: str | None = None
    notes: str | None = None
    # Quién lo recomendó (otro cliente).
    referred_by_id: UUID | None = None


class ClientUpdate(BaseModel):
    """Edición parcial: solo se cambia lo que venga.

    Se distingue "no lo mandaron" (no tocar) de "lo mandaron vacío" (limpiar). Sin eso,
    corregir el teléfono borraría las referencias para llegar.
    """

    name: Annotated[str, Field(min_length=1, max_length=200)] | None = None
    phone: str | None = None
    address: str | None = None
    directions: str | None = None
    notes: str | None = None
    referred_by_id: UUID | None = None


class ClientRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    phone: str | None
    address: str | None
    directions: str | None
    notes: str | None
    referred_by_id: UUID | None


class Recomendador(BaseModel):
    """Un cliente que ha traído a otros. Sale de la pantalla "quién te trae clientes"."""

    client_id: UUID
    name: str
    phone: str | None
    recomendados: int
