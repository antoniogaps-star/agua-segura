"""Reja de suscripción: bloquea las ESCRITURAS cuando la cuenta venció.

Al terminar la prueba gratis (o el plan de pago), la empresa entra en modo solo-lectura:
puede ver sus datos y canjear una clave para reactivar, pero no registrar nada nuevo hasta
pagar. Se cuelga de los routers de negocio y de /sync/push; los métodos de solo-lectura
(GET/HEAD/OPTIONS) nunca se bloquean, así que la misma reja sirve para todo el router.
"""

from uuid import UUID

from fastapi import Request

from app.modules.billing import service
from app.shared.deps import Claims, TenantSession
from app.shared.errors import api_error

# Métodos que no cambian estado: se dejan pasar siempre (ver tus datos aunque venciste).
_SAFE_METHODS = frozenset({"GET", "HEAD", "OPTIONS"})


async def require_active_subscription(
    request: Request, session: TenantSession, claims: Claims
) -> None:
    if request.method in _SAFE_METHODS:
        return
    if not await service.is_tenant_active(session, tenant_id=UUID(claims["tenant_id"])):
        raise api_error(
            402,
            "SUBSCRIPTION_EXPIRED",
            "Tu prueba gratis o tu plan venció. Canjea una clave de activación para "
            "seguir registrando; mientras tanto puedes ver tus datos.",
        )
