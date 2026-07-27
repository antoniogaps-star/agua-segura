"""Lógica de clientes.

DEFENSA EN PROFUNDIDAD: cada consulta filtra por `tenant_id` explícitamente, además de
la política RLS de Postgres. No basta con RLS: hay proveedores (Neon, entre otros) donde
el rol de la base **ignora** las políticas por tener privilegios elevados, y entonces una
empresa vería la cartera de clientes de otra.
"""

from typing import Any
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.modules.clients.models import Client
from app.shared.errors import api_error

EDITABLES = ("name", "phone", "address", "directions", "notes", "referred_by_id")


async def create_client(
    session: AsyncSession,
    *,
    tenant_id: UUID,
    name: str,
    phone: str | None = None,
    address: str | None = None,
    directions: str | None = None,
    notes: str | None = None,
    referred_by_id: UUID | None = None,
) -> Client:
    # Quien recomendó tiene que ser cliente de ESTA empresa. Si no, se ignora en vez de
    # guardar una referencia rota.
    if referred_by_id is not None:
        quien = await get_client(session, referred_by_id, tenant_id)
        if quien is None:
            referred_by_id = None

    cliente = Client(
        tenant_id=tenant_id,
        name=name,
        phone=phone,
        address=address,
        directions=directions,
        notes=notes,
        referred_by_id=referred_by_id,
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

    # Nadie se recomienda a sí mismo, y quien recomienda debe ser de esta empresa.
    quien = cambios.get("referred_by_id")
    if quien is not None and (
        quien == client_id or await get_client(session, quien, tenant_id) is None
    ):
        cambios = {k: v for k, v in cambios.items() if k != "referred_by_id"}

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


async def recomendadores(session: AsyncSession, tenant_id: UUID) -> list[dict[str, Any]]:
    """Quién te trae clientes: los que han recomendado a alguien, de más a menos.

    Es la otra mitad del negocio. La pantalla de "a quién le toca" trae de vuelta a los
    de siempre; esto dice a quién agradecerle —y a quién pedirle— los nuevos.
    """
    recomendado = aliased(Client)
    filas = await session.execute(
        select(Client, func.count(recomendado.id).label("cuantos"))
        .join(recomendado, recomendado.referred_by_id == Client.id)
        .where(
            Client.tenant_id == tenant_id,
            Client.is_deleted.is_(False),
            recomendado.tenant_id == tenant_id,
            recomendado.is_deleted.is_(False),
        )
        .group_by(Client.id)
        .order_by(func.count(recomendado.id).desc(), Client.name)
    )
    return [
        {
            "client_id": c.id,
            "name": c.name,
            "phone": c.phone,
            "recomendados": cuantos,
        }
        for c, cuantos in filas.all()
    ]
