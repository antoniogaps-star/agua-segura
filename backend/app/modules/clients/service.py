"""Lógica de clientes.

DEFENSA EN PROFUNDIDAD: cada consulta filtra por `tenant_id` explícitamente, además de
la política RLS de Postgres. No basta con RLS: hay proveedores (Neon, entre otros) donde
el rol de la base **ignora** las políticas por tener privilegios elevados, y entonces una
empresa vería la cartera de clientes de otra.
"""

from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.clients.models import Client
from app.shared.errors import api_error

EDITABLES = ("name", "phone", "address", "directions", "notes")


async def create_client(
    session: AsyncSession,
    *,
    tenant_id: UUID,
    name: str,
    phone: str | None = None,
    address: str | None = None,
    directions: str | None = None,
    notes: str | None = None,
) -> Client:
    cliente = Client(
        tenant_id=tenant_id,
        name=name,
        phone=phone,
        address=address,
        directions=directions,
        notes=notes,
    )
    session.add(cliente)
    await session.flush()
    return cliente


async def get_client(session: AsyncSession, client_id: UUID, tenant_id: UUID) -> Client | None:
    """Busca un cliente SOLO dentro de la empresa indicada."""
    rows = await session.execute(
        select(Client).where(Client.id == client_id, Client.tenant_id == tenant_id)
    )
    return rows.scalars().first()


async def list_clients(session: AsyncSession, tenant_id: UUID) -> list[Client]:
    rows = await session.execute(
        select(Client)
        .where(Client.tenant_id == tenant_id, Client.is_deleted.is_(False))
        .order_by(Client.name)
    )
    return list(rows.scalars().all())


async def update_client(
    session: AsyncSession, client_id: UUID, tenant_id: UUID, cambios: dict[str, Any]
) -> Client:
    cliente = await get_client(session, client_id, tenant_id)
    if cliente is None or cliente.is_deleted:
        raise api_error(404, "CLIENT_NOT_FOUND", "Cliente no encontrado")
    for campo, valor in cambios.items():
        if campo in EDITABLES:
            setattr(cliente, campo, valor)
    cliente.version += 1
    await session.flush()
    return cliente


async def delete_client(session: AsyncSession, client_id: UUID, tenant_id: UUID) -> None:
    cliente = await get_client(session, client_id, tenant_id)
    if cliente is None or cliente.is_deleted:
        raise api_error(404, "CLIENT_NOT_FOUND", "Cliente no encontrado")
    cliente.is_deleted = True
    cliente.version += 1
    await session.flush()
