"""Helper de Row-Level Security: fija el tenant activo en la sesión.

Postgres filtra las filas comparando `tenant_id` con `current_setting('app.current_tenant')`
(ver la política creada en la migración inicial). El backend debe llamar a `set_tenant`
al inicio de cada request autenticado, con el `tenant_id` extraído del JWT — nunca de
entrada del cliente (ver docs/09_Seguridad.md).

`SET LOCAL` limita el ajuste a la transacción actual, evitando fugas entre requests que
reutilicen una conexión del pool.
"""

from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


async def set_tenant(session: AsyncSession, tenant_id: UUID) -> None:
    """Fija el tenant de la transacción actual para que RLS lo aplique.

    Se usa set_config(clave, valor, is_local=true) en vez de `SET LOCAL ... = :param`
    porque los comandos SET de Postgres NO admiten parámetros ligados. El tercer
    argumento `true` limita el ajuste a la transacción actual (equivalente a SET LOCAL).
    """
    await session.execute(
        text("SELECT set_config('app.current_tenant', :tenant_id, true)"),
        {"tenant_id": str(tenant_id)},
    )
