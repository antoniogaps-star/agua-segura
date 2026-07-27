"""Endpoints de facturación/licencias: estado, canje de clave y generación (admin)."""

from collections.abc import AsyncGenerator
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Header
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import SessionFactory
from app.modules.auth import service as auth_service
from app.modules.billing import service
from app.modules.billing.schemas import (
    AdminKeyRequest,
    AdminKeyResponse,
    BillingStatus,
    RedeemRequest,
)
from app.shared.deps import Claims, TenantSession
from app.shared.errors import api_error

router = APIRouter(prefix="/billing", tags=["billing"])


async def _plain_session() -> AsyncGenerator[AsyncSession, None]:
    async with SessionFactory() as session:
        yield session


PlainSession = Annotated[AsyncSession, Depends(_plain_session)]


@router.get("/status", response_model=BillingStatus)
async def billing_status(session: TenantSession, claims: Claims) -> dict[str, object]:
    return await service.get_status(session, tenant_id=UUID(claims["tenant_id"]))


@router.post("/redeem", response_model=BillingStatus)
async def redeem(data: RedeemRequest, session: TenantSession, claims: Claims) -> dict[str, object]:
    await service.redeem(session, tenant_id=UUID(claims["tenant_id"]), code=data.code)
    return await service.get_status(session, tenant_id=UUID(claims["tenant_id"]))


@router.post("/admin/keys", response_model=AdminKeyResponse)
async def admin_generate_keys(
    data: AdminKeyRequest,
    session: PlainSession,
    x_admin_secret: Annotated[str | None, Header()] = None,
) -> AdminKeyResponse:
    if not await auth_service.verify_admin_secret(session, data.admin_secret or x_admin_secret):
        raise api_error(403, "FORBIDDEN", "No autorizado")
    codes = await service.generate_keys(
        session, plan=data.plan, months=data.months, count=data.count
    )
    await session.commit()
    return AdminKeyResponse(codes=codes)
