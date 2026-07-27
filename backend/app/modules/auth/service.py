"""Lógica de autenticación: onboarding (register) y login.

Punto clave multi-tenant: el email es único POR empresa. Por eso login y register
resuelven primero el tenant por su `slug` (la tabla `tenants` no tiene RLS), fijan
`app.current_tenant`, y solo entonces operan sobre `users` — que RLS ya acota a esa
empresa. El tenant nunca se toma de un token aún inexistente en estos endpoints públicos.
"""

from datetime import UTC, datetime, timedelta
from uuid import UUID

import jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    hash_token,
    verify_password,
)
from app.db.rls import set_tenant
from app.modules.auth.models import AdminConfig, RefreshToken
from app.modules.auth.schemas import TokenResponse
from app.modules.tenants.models import Tenant
from app.modules.users.models import User
from app.shared.errors import api_error


async def register(session: AsyncSession, *, company_name: str, company_slug: str,
                   email: str, password: str) -> tuple[Tenant, User]:
    async with session.begin():
        exists = await session.scalar(select(Tenant.id).where(Tenant.slug == company_slug))
        if exists is not None:
            raise api_error(409, "SLUG_TAKEN", "Ya existe una empresa con ese identificador")

        tenant = Tenant(name=company_name, slug=company_slug, plan="free", status="trial")
        session.add(tenant)
        await session.flush()  # asigna tenant.id

        await set_tenant(session, tenant.id)
        user = User(
            tenant_id=tenant.id,
            email=email,
            password_hash=hash_password(password),
            role="owner",
        )
        session.add(user)
        await session.flush()
    return tenant, user


async def authenticate(session: AsyncSession, *, company_slug: str, email: str,
                       password: str) -> tuple[Tenant, User]:
    # Mensaje de error genérico para no revelar si existe la empresa o el email.
    invalid = api_error(401, "INVALID_CREDENTIALS", "Credenciales inválidas")
    async with session.begin():
        tenant = await session.scalar(select(Tenant).where(Tenant.slug == company_slug))
        if tenant is None:
            raise invalid

        await set_tenant(session, tenant.id)
        user = await session.scalar(
            select(User).where(User.email == email, User.is_deleted.is_(False))
        )
        if user is None or not user.is_active or not verify_password(user.password_hash, password):
            raise invalid
    return tenant, user


# ── Secreto de administrador (configurable desde la app) ─────
async def _db_admin_hash(session: AsyncSession) -> str | None:
    result: str | None = await session.scalar(
        select(AdminConfig.secret_hash).where(AdminConfig.id == 1)
    )
    return result


async def is_admin_configured(session: AsyncSession) -> bool:
    """True si hay un secreto de administrador disponible: por variable de entorno
    (LICENSE_ADMIN_SECRET) o configurado desde la app (tabla admin_config)."""
    if settings.license_admin_secret:
        return True
    return (await _db_admin_hash(session)) is not None


async def verify_admin_secret(session: AsyncSession, provided: str | None) -> bool:
    """Valida el secreto que llega en el header. La variable de entorno tiene
    prioridad; si no hay, se compara contra el hash guardado en la base."""
    if not provided:
        return False
    if settings.license_admin_secret:
        return provided == settings.license_admin_secret
    stored = await _db_admin_hash(session)
    return stored is not None and verify_password(stored, provided)


async def bootstrap_admin_secret(session: AsyncSession, *, secret: str) -> None:
    """Fija el secreto de administrador por primera vez (desde la app). Solo funciona
    si aún no hay ninguno configurado; si ya existe, responde 409 para no permitir que
    un tercero lo reemplace."""
    async with session.begin():
        if settings.license_admin_secret or (await _db_admin_hash(session)) is not None:
            raise api_error(
                409, "ADMIN_ALREADY_CONFIGURED",
                "El secreto de administrador ya está configurado en este servidor.",
            )
        session.add(AdminConfig(id=1, secret_hash=hash_password(secret)))


async def reset_password(
    session: AsyncSession, *, company_slug: str, email: str, new_password: str,
    provided_secret: str | None,
) -> None:
    """Restablece la contraseña de un usuario (recuperación operada por el dueño).

    Todas las verificaciones (secreto de administrador incluido) ocurren dentro de una
    única transacción para no mezclar lecturas sueltas con `session.begin()`. Resuelve
    el tenant por slug, fija RLS y actualiza el hash del usuario; además revoca sus
    refresh tokens activos para cerrar sesiones abiertas con la contraseña anterior.
    """
    not_found = api_error(404, "NOT_FOUND", "No existe esa empresa o correo")
    async with session.begin():
        # Secreto de administrador: no configurado (503) vs no coincide (403).
        if not settings.license_admin_secret and (await _db_admin_hash(session)) is None:
            raise api_error(
                503,
                "ADMIN_NOT_CONFIGURED",
                "Este servidor todavía no tiene un secreto de administrador. "
                "Configúralo una vez desde la app (Configurar secreto por primera vez).",
            )
        if not await verify_admin_secret(session, provided_secret):
            raise api_error(403, "SECRET_MISMATCH", "El secreto no coincide con el del servidor")

        tenant = await session.scalar(select(Tenant).where(Tenant.slug == company_slug))
        if tenant is None:
            raise not_found

        await set_tenant(session, tenant.id)
        user = await session.scalar(
            select(User).where(User.email == email, User.is_deleted.is_(False))
        )
        if user is None:
            raise not_found

        user.password_hash = hash_password(new_password)
        # Cierra sesiones previas: los refresh tokens viejos dejan de servir.
        for token in await session.scalars(
            select(RefreshToken).where(
                RefreshToken.user_id == user.id, RefreshToken.revoked_at.is_(None)
            )
        ):
            token.revoked_at = datetime.now(UTC)


async def _store_tokens(
    session: AsyncSession, *, user_id: UUID, tenant_id: UUID, role: str
) -> TokenResponse:
    """Emite access+refresh y guarda el hash del refresh (para poder revocarlo)."""
    access = create_access_token(user_id=user_id, tenant_id=tenant_id, role=role)
    refresh = create_refresh_token(user_id=user_id, tenant_id=tenant_id, role=role)
    session.add(
        RefreshToken(
            tenant_id=tenant_id,
            user_id=user_id,
            token_hash=hash_token(refresh),
            expires_at=datetime.now(UTC) + timedelta(days=settings.refresh_token_ttl_days),
        )
    )
    await session.flush()
    return TokenResponse(access_token=access, refresh_token=refresh)


async def issue_tokens(
    session: AsyncSession, *, user_id: UUID, tenant_id: UUID, role: str
) -> TokenResponse:
    """Emite tokens tras register/login (fija el tenant para poder escribir con RLS)."""
    async with session.begin():
        await set_tenant(session, tenant_id)
        return await _store_tokens(session, user_id=user_id, tenant_id=tenant_id, role=role)


async def rotate_refresh(session: AsyncSession, token: str) -> TokenResponse:
    """Valida el refresh contra la base, lo revoca y emite uno nuevo (rotación)."""
    invalid = api_error(401, "INVALID_TOKEN", "Refresh token inválido o expirado")
    try:
        payload = decode_token(token)
    except jwt.PyJWTError as exc:
        raise invalid from exc
    if payload.get("type") != "refresh":
        raise invalid

    tenant_id = UUID(payload["tenant_id"])
    async with session.begin():
        await set_tenant(session, tenant_id)
        row = await session.scalar(
            select(RefreshToken).where(RefreshToken.token_hash == hash_token(token))
        )
        if row is None or row.revoked_at is not None or row.expires_at < datetime.now(UTC):
            raise invalid
        row.revoked_at = datetime.now(UTC)  # rotación: el usado ya no vuelve a servir
        return await _store_tokens(
            session, user_id=UUID(payload["sub"]), tenant_id=tenant_id, role=payload["role"]
        )


async def logout(session: AsyncSession, token: str) -> None:
    """Revoca el refresh token (idempotente: un token inválido no hace nada)."""
    try:
        payload = decode_token(token)
    except jwt.PyJWTError:
        return
    async with session.begin():
        await set_tenant(session, UUID(payload["tenant_id"]))
        row = await session.scalar(
            select(RefreshToken).where(RefreshToken.token_hash == hash_token(token))
        )
        if row is not None and row.revoked_at is None:
            row.revoked_at = datetime.now(UTC)
