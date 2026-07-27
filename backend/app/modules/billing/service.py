"""Lógica de licencias: estado de la cuenta, canje de claves y generación (admin)."""

import secrets
from datetime import UTC, datetime, timedelta
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.billing.models import License
from app.modules.tenants.models import Tenant
from app.shared.errors import api_error

TRIAL_DAYS = 7

# Negocios permitidos por plan (Esencial=1, Profesional=3, Empresarial=6).
_BUSINESSES = {"free": 1, "pyme": 1, "business": 3, "enterprise": 6}

# Alfabeto sin caracteres ambiguos (0/O, 1/I).
_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def businesses_allowed(plan: str) -> int:
    return _BUSINESSES.get(plan, 1)


def _is_active(tenant: Tenant, now: datetime) -> bool:
    """True si la cuenta puede seguir registrando: plan de pago vigente, o prueba dentro
    de los primeros TRIAL_DAYS días. Suspendida/cancelada o vencida => False."""
    if tenant.status == "active":
        return tenant.plan_expires_at is None or tenant.plan_expires_at > now
    if tenant.status == "trial":
        return now < tenant.created_at + timedelta(days=TRIAL_DAYS)
    return False


async def is_tenant_active(session: AsyncSession, *, tenant_id: UUID) -> bool:
    """¿El tenant tiene derecho a escribir? Fuente de verdad del bloqueo por vencimiento
    (ver require_active_subscription). Un tenant inexistente cuenta como no activo."""
    tenant = await session.get(Tenant, tenant_id)
    return tenant is not None and _is_active(tenant, datetime.now(UTC))


def _gen_code() -> str:
    def part() -> str:
        return "".join(secrets.choice(_ALPHABET) for _ in range(4))

    return f"AGORA-{part()}-{part()}"


async def get_status(session: AsyncSession, *, tenant_id: UUID) -> dict[str, object]:
    tenant = await session.get(Tenant, tenant_id)
    if tenant is None:
        raise api_error(404, "TENANT_NOT_FOUND", "Empresa no encontrada")
    now = datetime.now(UTC)
    trial_ends = tenant.created_at + timedelta(days=TRIAL_DAYS)
    in_trial = tenant.status == "trial"
    active = _is_active(tenant, now)
    return {
        "plan": tenant.plan,
        "status": tenant.status,
        "in_trial": in_trial,
        "active": active,
        "trial_ends_at": trial_ends,
        "plan_expires_at": tenant.plan_expires_at,
        "businesses_allowed": businesses_allowed(tenant.plan if active else "free"),
    }


async def redeem(session: AsyncSession, *, tenant_id: UUID, code: str) -> Tenant:
    lic = await session.scalar(select(License).where(License.code == code.strip().upper()))
    if lic is None:
        raise api_error(404, "LICENSE_NOT_FOUND", "Clave no válida")
    if lic.redeemed_by is not None:
        raise api_error(409, "LICENSE_USED", "Esa clave ya fue usada")

    tenant = await session.get(Tenant, tenant_id)
    if tenant is None:
        raise api_error(404, "TENANT_NOT_FOUND", "Empresa no encontrada")

    now = datetime.now(UTC)
    lic.redeemed_by = tenant.id
    lic.redeemed_at = now
    tenant.plan = lic.plan
    tenant.status = "active"
    tenant.plan_expires_at = None if lic.months == 0 else now + timedelta(days=30 * lic.months)
    await session.flush()
    return tenant


async def generate_keys(
    session: AsyncSession, *, plan: str, months: int, count: int
) -> list[str]:
    codes: list[str] = []
    for _ in range(count):
        code = _gen_code()
        session.add(License(code=code, plan=plan, months=months))
        codes.append(code)
    await session.flush()
    return codes
