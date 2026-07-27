"""Endpoints de usuarios: el perfil propio y la administración de los técnicos."""

from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy import select

from app.modules.users import service
from app.modules.users.models import User
from app.modules.users.schemas import UserCreate, UserRead, UserUpdate
from app.shared.deps import Claims, TenantSession
from app.shared.errors import api_error

router = APIRouter(prefix="/users", tags=["users"])


async def solo_dueno(claims: Claims) -> None:
    """Dar de alta o de baja gente es cosa del dueño, no del técnico.

    Sin esto, un técnico podría crearse una cuenta de dueño y ver la caja del negocio.
    """
    if claims.get("role") not in ("owner", "admin"):
        raise api_error(403, "FORBIDDEN", "Solo el dueño puede administrar usuarios")


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


@router.get("", response_model=list[UserRead])
async def list_users(session: TenantSession, claims: Claims) -> list[User]:
    """El equipo de la empresa.

    La puede consultar cualquiera con sesión: el técnico necesita saber a quién está
    asignada cada visita del día.
    """
    return await service.list_users(session, UUID(claims["tenant_id"]))


@router.post(
    "",
    response_model=UserRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(solo_dueno)],
)
async def create_user(data: UserCreate, session: TenantSession, claims: Claims) -> User:
    return await service.create_user(
        session,
        tenant_id=UUID(claims["tenant_id"]),
        email=data.email,
        password=data.password,
        name=data.name,
        role=data.role,
    )


@router.patch("/{user_id}", response_model=UserRead, dependencies=[Depends(solo_dueno)])
async def update_user(
    user_id: UUID, data: UserUpdate, session: TenantSession, claims: Claims
) -> User:
    return await service.update_user(
        session,
        user_id,
        UUID(claims["tenant_id"]),
        # exclude_unset distingue "no lo mandaron" de "lo mandaron vacío para borrarlo".
        data.model_dump(exclude_unset=True),
    )


@router.delete(
    "/{user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(solo_dueno)],
)
async def delete_user(user_id: UUID, session: TenantSession, claims: Claims) -> None:
    await service.delete_user(session, user_id, UUID(claims["tenant_id"]))
