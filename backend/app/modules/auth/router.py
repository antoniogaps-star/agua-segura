"""Endpoints de autenticación: /register, /login, /refresh, /logout."""

from typing import Annotated

from fastapi import APIRouter, Depends, Header, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_session
from app.modules.auth import service
from app.modules.auth.schemas import (
    AdminBootstrapRequest,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
)

router = APIRouter(prefix="/auth", tags=["auth"])

SessionDep = Annotated[AsyncSession, Depends(get_session)]


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(data: RegisterRequest, session: SessionDep) -> TokenResponse:
    tenant, user = await service.register(
        session,
        company_name=data.company_name,
        company_slug=data.company_slug,
        email=data.email,
        password=data.password,
    )
    return await service.issue_tokens(
        session, user_id=user.id, tenant_id=tenant.id, role=user.role
    )


@router.post("/login", response_model=TokenResponse)
async def login(data: LoginRequest, session: SessionDep) -> TokenResponse:
    tenant, user = await service.authenticate(
        session,
        company_slug=data.company_slug,
        email=data.email,
        password=data.password,
    )
    return await service.issue_tokens(
        session, user_id=user.id, tenant_id=tenant.id, role=user.role
    )


@router.get("/admin-status")
async def admin_status(session: SessionDep) -> dict[str, bool]:
    """Diagnóstico seguro: dice SOLO si el servidor ya tiene un secreto de
    administrador (true/false), venga de la variable de entorno o configurado desde
    la app. No revela su valor."""
    return {"admin_secret_configured": await service.is_admin_configured(session)}


@router.post("/admin/bootstrap", status_code=status.HTTP_201_CREATED)
async def admin_bootstrap(data: AdminBootstrapRequest, session: SessionDep) -> dict[str, bool]:
    """Configura POR PRIMERA VEZ el secreto de administrador desde la app (se guarda
    cifrado en la base). Solo funciona si aún no hay ninguno: si ya existe, responde
    409. Así el dueño no depende de variables de entorno del servidor."""
    await service.bootstrap_admin_secret(session, secret=data.secret)
    return {"admin_secret_configured": True}


@router.post("/reset-password", status_code=status.HTTP_204_NO_CONTENT)
async def reset_password(
    data: ResetPasswordRequest,
    session: SessionDep,
    x_admin_secret: Annotated[str | None, Header()] = None,
) -> None:
    """Restablece la contraseña de una cuenta. Requiere el secreto de administrador
    (variable de entorno o el configurado desde la app). Pensado para que el dueño
    recupere el acceso de un cliente que olvidó su contraseña.

    El secreto puede venir en el cuerpo (`admin_secret`, recomendado) o en el header
    `X-Admin-Secret` (compatibilidad). El cuerpo tiene prioridad."""
    await service.reset_password(
        session,
        company_slug=data.company_slug,
        email=data.email,
        new_password=data.new_password,
        provided_secret=data.admin_secret or x_admin_secret,
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh(data: RefreshRequest, session: SessionDep) -> TokenResponse:
    return await service.rotate_refresh(session, data.refresh_token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(data: RefreshRequest, session: SessionDep) -> None:
    await service.logout(session, data.refresh_token)
