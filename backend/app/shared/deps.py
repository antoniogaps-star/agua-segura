"""Dependencias de FastAPI para autenticación y sesión con tenant (RLS).

- `get_claims`: valida el access token y devuelve sus claims.
- `get_tenant_session`: abre una sesión, fija `app.current_tenant` desde el token y la
  entrega. A partir de ahí, RLS acota automáticamente todas las consultas al tenant.
"""

from collections.abc import AsyncGenerator
from typing import Annotated, Any
from uuid import UUID

import jwt
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decode_token
from app.db.rls import set_tenant
from app.db.session import SessionFactory
from app.shared.errors import api_error

_bearer = HTTPBearer(auto_error=True)


async def get_claims(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(_bearer)],
) -> dict[str, Any]:
    try:
        payload = decode_token(credentials.credentials)
    except jwt.PyJWTError as exc:
        raise api_error(401, "INVALID_TOKEN", "Token inválido o expirado") from exc
    if payload.get("type") != "access":
        raise api_error(401, "INVALID_TOKEN", "Se requiere un access token")
    return payload


Claims = Annotated[dict[str, Any], Depends(get_claims)]


async def get_tenant_session(claims: Claims) -> AsyncGenerator[AsyncSession, None]:
    """Sesión transaccional con el tenant del token fijado para RLS."""
    async with SessionFactory() as session:
        async with session.begin():
            await set_tenant(session, UUID(claims["tenant_id"]))
            yield session


TenantSession = Annotated[AsyncSession, Depends(get_tenant_session)]
