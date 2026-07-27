"""Contratos del protocolo de sincronización (ver docs/05_API.md).

Este es el ESQUELETO: define el formato de push/pull. La aplicación real por entidad
(y la resolución de conflictos) se añade cuando existan los módulos de negocio.
"""

from datetime import datetime
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel

ChangeOp = Literal["upsert", "delete"]
# "rejected": el id existe pero pertenece a otra empresa. No se aplica y se avisa,
# en vez de dejar que el INSERT reviente contra la llave primaria con un error 500.
ChangeStatus = Literal["applied", "conflict", "unsupported", "rejected"]


class Change(BaseModel):
    """Un cambio de una entidad sincronizable."""

    entity: str
    id: UUID
    op: ChangeOp
    version: int
    updated_at: datetime
    data: dict[str, Any] | None = None


class PushRequest(BaseModel):
    changes: list[Change]


class ChangeResult(BaseModel):
    id: UUID
    entity: str
    status: ChangeStatus
    server_version: int | None = None


class PushResponse(BaseModel):
    results: list[ChangeResult]


class PullResponse(BaseModel):
    changes: list[Change]
    cursor: str
