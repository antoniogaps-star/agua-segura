"""Endpoints de sincronización: /sync/push y /sync/pull.

Ambos requieren autenticación y usan la sesión con el tenant fijado (RLS), de modo que
la sincronización queda aislada por empresa desde el diseño.
"""

from uuid import UUID

from fastapi import APIRouter, Depends

from app.modules.billing.deps import require_active_subscription
from app.shared.deps import Claims, TenantSession
from app.sync import service
from app.sync.schemas import PullResponse, PushRequest, PushResponse

router = APIRouter(
    prefix="/sync",
    tags=["sync"],
    dependencies=[Depends(require_active_subscription)],
)


@router.post("/push", response_model=PushResponse)
async def push(payload: PushRequest, session: TenantSession, claims: Claims) -> PushResponse:
    return await service.push(session, UUID(claims["tenant_id"]), payload)


@router.get("/pull", response_model=PullResponse)
async def pull(session: TenantSession, claims: Claims, since: str | None = None) -> PullResponse:
    return await service.pull(session, UUID(claims["tenant_id"]), since)
