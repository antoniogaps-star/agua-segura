"""Endpoints REST de clientes."""

from uuid import UUID

from fastapi import APIRouter, Depends, status

from app.modules.billing.deps import require_active_subscription
from app.modules.clients import service
from app.modules.clients.models import Client
from app.modules.clients.schemas import ClientCreate, ClientRead, ClientUpdate
from app.shared.deps import Claims, TenantSession

router = APIRouter(
    prefix="/clients",
    tags=["clients"],
    dependencies=[Depends(require_active_subscription)],
)


@router.get("", response_model=list[ClientRead])
async def list_clients(session: TenantSession, claims: Claims) -> list[Client]:
    return await service.list_clients(session, UUID(claims["tenant_id"]))


@router.post("", response_model=ClientRead, status_code=status.HTTP_201_CREATED)
async def create_client(data: ClientCreate, session: TenantSession, claims: Claims) -> Client:
    return await service.create_client(
        session,
        tenant_id=UUID(claims["tenant_id"]),
        name=data.name,
        phone=data.phone,
        address=data.address,
        directions=data.directions,
        notes=data.notes,
    )


@router.patch("/{client_id}", response_model=ClientRead)
async def update_client(
    client_id: UUID, data: ClientUpdate, session: TenantSession, claims: Claims
) -> Client:
    return await service.update_client(
        session,
        client_id,
        UUID(claims["tenant_id"]),
        # exclude_unset distingue "no lo mandaron" de "lo mandaron vacío para borrarlo".
        data.model_dump(exclude_unset=True),
    )


@router.delete("/{client_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_client(client_id: UUID, session: TenantSession, claims: Claims) -> None:
    await service.delete_client(session, client_id, UUID(claims["tenant_id"]))
