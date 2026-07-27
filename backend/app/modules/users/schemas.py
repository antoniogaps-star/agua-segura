"""Contratos (Pydantic) del módulo de usuarios."""

from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    tenant_id: UUID
    email: EmailStr
    # Cómo se le dice en la agenda ("Luis"). El correo es solo para entrar.
    name: str | None = None
    role: str
    is_active: bool


class UserCreate(BaseModel):
    """Alta de un técnico (o de otro usuario) por parte del dueño."""

    email: EmailStr
    # Ocho como mínimo, igual que en el registro de la empresa.
    password: Annotated[str, Field(min_length=8, max_length=128)]
    name: Annotated[str, Field(min_length=1, max_length=120)] | None = None
    # "operator" es el técnico: su agenda y sus servicios, sin la caja.
    role: Literal["owner", "admin", "operator", "viewer"] = "operator"


class UserUpdate(BaseModel):
    """Edición parcial: solo se cambia lo que venga."""

    name: Annotated[str, Field(min_length=1, max_length=120)] | None = None
    role: Literal["owner", "admin", "operator", "viewer"] | None = None
    # Para el técnico que se va: deja de entrar, pero su historial de trabajos se queda.
    is_active: bool | None = None
