"""Alta y administración de los usuarios de la empresa (el dueño y sus técnicos).

DEFENSA EN PROFUNDIDAD: cada consulta filtra por `tenant_id` explícitamente, además de
RLS. Aquí importa especialmente: si se colara un usuario de otra empresa, esa persona
podría acabar asignada a visitas que no le corresponden — y viendo datos ajenos.
"""

from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.modules.users.models import ROLES, User
from app.shared.errors import api_error

EDITABLES = ("name", "role", "is_active")


async def list_users(session: AsyncSession, tenant_id: UUID) -> list[User]:
    rows = await session.execute(
        select(User)
        .where(User.tenant_id == tenant_id, User.is_deleted.is_(False))
        .order_by(User.name, User.email)
    )
    return list(rows.scalars().all())


async def get_user(session: AsyncSession, user_id: UUID, tenant_id: UUID) -> User | None:
    """Busca un usuario SOLO dentro de la empresa indicada."""
    rows = await session.execute(
        select(User).where(User.id == user_id, User.tenant_id == tenant_id)
    )
    return rows.scalars().first()


async def create_user(
    session: AsyncSession,
    *,
    tenant_id: UUID,
    email: str,
    password: str,
    name: str | None = None,
    role: str = "operator",
) -> User:
    """Da de alta a un técnico (o a otro usuario) dentro de la empresa."""
    if role not in ROLES:
        raise api_error(422, "INVALID_ROLE", "Ese tipo de usuario no existe")

    # El correo es único POR empresa: dos negocios distintos pueden tener al mismo.
    rows = await session.execute(
        select(User.id).where(User.tenant_id == tenant_id, User.email == email)
    )
    if rows.first() is not None:
        raise api_error(409, "EMAIL_TAKEN", "Ya hay un usuario con ese correo")

    user = User(
        tenant_id=tenant_id,
        email=email,
        password_hash=hash_password(password),
        name=name,
        role=role,
    )
    session.add(user)
    await session.flush()
    return user


async def update_user(
    session: AsyncSession, user_id: UUID, tenant_id: UUID, cambios: dict[str, Any]
) -> User:
    user = await get_user(session, user_id, tenant_id)
    if user is None or user.is_deleted:
        raise api_error(404, "USER_NOT_FOUND", "Usuario no encontrado")

    if cambios.get("role") is not None and cambios["role"] not in ROLES:
        raise api_error(422, "INVALID_ROLE", "Ese tipo de usuario no existe")

    for campo, valor in cambios.items():
        if campo in EDITABLES and valor is not None:
            setattr(user, campo, valor)
    user.version += 1
    await session.flush()
    return user


async def delete_user(session: AsyncSession, user_id: UUID, tenant_id: UUID) -> None:
    """Da de baja a un usuario. Nunca al último dueño: la empresa quedaría sin acceso."""
    user = await get_user(session, user_id, tenant_id)
    if user is None or user.is_deleted:
        raise api_error(404, "USER_NOT_FOUND", "Usuario no encontrado")

    if user.role == "owner":
        rows = await session.execute(
            select(User.id).where(
                User.tenant_id == tenant_id,
                User.role == "owner",
                User.is_deleted.is_(False),
                User.id != user_id,
            )
        )
        if rows.first() is None:
            raise api_error(
                409, "LAST_OWNER", "No puedes dar de baja al único dueño de la empresa"
            )

    user.is_deleted = True
    user.is_active = False
    user.version += 1
    await session.flush()
