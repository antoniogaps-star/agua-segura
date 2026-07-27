"""Endpoints de usuarios. Por ahora, /users/me (perfil autenticado)."""

from uuid import UUID

from fastapi import APIRouter
from sqlalchemy import select

from app.modules.users.models import User
from app.modules.users.schemas import UserRead
from app.shared.deps import Claims, TenantSession
from app.shared.errors import api_error

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserRead)
async def me(claims: Claims, session: TenantSession) -> User:
    # Se busca por id Y empresa. El id sale del propio token, así que ya de por sí
    # nadie puede pedir otro usuario; el filtro lo deja explícito y no depende de que la
    # base aplique RLS.
    rows = await session.execute(
        select(User).where(
            User.id == UUID(claims["sub"]),
            User.tenant_id == UUID(claims["tenant_id"]),
        )
    )
    user = rows.scalars().first()
    if user is None:
        raise api_error(404, "USER_NOT_FOUND", "Usuario no encontrado")
    return user
