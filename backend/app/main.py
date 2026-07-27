"""Punto de entrada de la API de Agua Segura (lavado de tinacos y mantenimiento).

Registra los routers bajo /api/v1 y da formato uniforme a los errores.
"""

from contextlib import asynccontextmanager
from typing import Any

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.config import settings
from app.db.session import engine
from app.modules.auth.router import router as auth_router
from app.modules.billing.router import router as billing_router
from app.modules.clients.router import router as clients_router
from app.modules.services.router import router as services_router
from app.modules.users.router import router as users_router
from app.sync.router import router as sync_router

API_PREFIX = "/api/v1"


@asynccontextmanager
async def lifespan(_: FastAPI) -> Any:
    yield
    await engine.dispose()


app = FastAPI(
    title="Agua Segura API",
    version="0.0.1",
    description="Lavado de tinacos y mantenimiento del hogar — multiempresa, offline-first.",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(_: Request, exc: StarletteHTTPException) -> JSONResponse:
    """Envuelve toda HTTPException en { "error": { code, message } }."""
    detail = exc.detail
    if isinstance(detail, dict) and "code" in detail:
        body = {"error": detail}
    else:
        body = {"error": {"code": "ERROR", "message": str(detail)}}
    return JSONResponse(status_code=exc.status_code, content=body)


# ── Health ───────────────────────────────────────────────────
@app.get("/health", tags=["health"])
async def health() -> dict[str, str]:
    return {"status": "ok", "env": settings.app_env}


@app.get("/health/db", tags=["health"])
async def health_db() -> dict[str, str]:
    async with engine.connect() as conn:
        await conn.execute(text("SELECT 1"))
    return {"status": "ok", "database": "reachable"}


# ── Routers de negocio ───────────────────────────────────────
app.include_router(auth_router, prefix=API_PREFIX)
app.include_router(billing_router, prefix=API_PREFIX)
app.include_router(users_router, prefix=API_PREFIX)
app.include_router(clients_router, prefix=API_PREFIX)
app.include_router(services_router, prefix=API_PREFIX)
app.include_router(sync_router, prefix=API_PREFIX)
