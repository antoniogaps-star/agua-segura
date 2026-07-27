"""Endpoints REST de servicios y del recordatorio de mantenimiento."""

from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status

from app.modules.billing.deps import require_active_subscription
from app.modules.services import service
from app.modules.services.models import ServiceJob
from app.modules.services.schemas import (
    JobStatus,
    Pendiente,
    ServiceJobComplete,
    ServiceJobCreate,
    ServiceJobRead,
)
from app.shared.deps import Claims, TenantSession

router = APIRouter(
    prefix="/services",
    tags=["services"],
    dependencies=[Depends(require_active_subscription)],
)


@router.get("", response_model=list[ServiceJobRead])
async def list_jobs(
    session: TenantSession,
    claims: Claims,
    status_filter: Annotated[JobStatus | None, Query(alias="status")] = None,
    technician_id: UUID | None = None,
) -> list[ServiceJob]:
    return await service.list_jobs(
        session,
        UUID(claims["tenant_id"]),
        status=status_filter,
        technician_id=technician_id,
    )


@router.post("", response_model=ServiceJobRead, status_code=status.HTTP_201_CREATED)
async def create_job(
    data: ServiceJobCreate, session: TenantSession, claims: Claims
) -> ServiceJob:
    return await service.create_job(
        session,
        tenant_id=UUID(claims["tenant_id"]),
        client_id=data.client_id,
        service_type=data.service_type,
        scheduled_for=data.scheduled_for,
        technician_id=data.technician_id,
        notes=data.notes,
        price_cents=data.price_cents,
    )


@router.post("/{job_id}/complete", response_model=ServiceJobRead)
async def complete_job(
    job_id: UUID, data: ServiceJobComplete, session: TenantSession, claims: Claims
) -> ServiceJob:
    """Marca el servicio como realizado y programa solo el siguiente mantenimiento."""
    return await service.complete_job(
        session,
        job_id,
        UUID(claims["tenant_id"]),
        performed_on=data.performed_on,
        price_cents=data.price_cents,
        is_paid=data.is_paid,
        notes=data.notes,
        technician_id=data.technician_id,
    )


@router.delete("/{job_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_job(job_id: UUID, session: TenantSession, claims: Claims) -> None:
    await service.delete_job(session, job_id, UUID(claims["tenant_id"]))


@router.get("/pendientes", response_model=list[Pendiente])
async def pendientes(
    session: TenantSession,
    claims: Claims,
    dentro_de_dias: int = Query(default=30, ge=0, le=365),
) -> list[dict[str, Any]]:
    """**¿A quién le toca?** — la pantalla estrella de la app.

    Devuelve a los clientes con su mantenimiento vencido o por vencer, lo más urgente
    primero, para poder mandarles el recordatorio por WhatsApp.
    """
    return await service.pendientes(
        session, UUID(claims["tenant_id"]), dentro_de_dias=dentro_de_dias
    )
