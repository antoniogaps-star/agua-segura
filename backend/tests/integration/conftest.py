"""Fixtures de integración: preparan Postgres con el rol de aplicación y RLS.

Estos tests necesitan un PostgreSQL real. Si no hay ninguno accesible, se OMITEN
(no fallan), para que la suite unitaria siga corriendo sin base de datos.

Preparación (una vez por sesión):
1. Asegura el rol de aplicación NO superusuario (para que RLS aplique) — replica lo
   que hace infra/postgres/initdb en Docker, para que también funcione en CI.
2. Aplica las migraciones con el rol dueño (subproceso de Alembic).
3. Concede DML sobre las tablas al rol de aplicación.
"""

import asyncio
import os
import subprocess
import sys
from pathlib import Path

import pytest
import pytest_asyncio
from sqlalchemy import text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import DBAPIError, InterfaceError, OperationalError
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.core.config import settings

BACKEND_DIR = Path(__file__).resolve().parents[2]

_CONNECT_ERRORS = (OperationalError, InterfaceError, DBAPIError, OSError, ConnectionError)


def _owner_url() -> str:
    return settings.migration_database_url or settings.database_url


async def _ensure_app_role() -> None:
    app_url = make_url(settings.database_url)
    role, pwd, dbname = app_url.username, app_url.password or "", app_url.database
    engine = create_async_engine(_owner_url(), isolation_level="AUTOCOMMIT")
    try:
        async with engine.connect() as conn:
            exists = await conn.scalar(
                text("SELECT 1 FROM pg_roles WHERE rolname = :r"), {"r": role}
            )
            if not exists:
                pwd_literal = pwd.replace("'", "''")
                await conn.execute(text(f'CREATE ROLE "{role}" LOGIN PASSWORD \'{pwd_literal}\''))
            await conn.execute(text(f'GRANT CONNECT ON DATABASE "{dbname}" TO "{role}"'))
            await conn.execute(text(f'GRANT USAGE ON SCHEMA public TO "{role}"'))
    finally:
        await engine.dispose()


async def _grant_table_privileges() -> None:
    role = make_url(settings.database_url).username
    engine = create_async_engine(_owner_url(), isolation_level="AUTOCOMMIT")
    try:
        async with engine.connect() as conn:
            await conn.execute(
                text(
                    "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES "
                    f'IN SCHEMA public TO "{role}"'
                )
            )
    finally:
        await engine.dispose()


def _run_migrations() -> None:
    subprocess.run(
        [sys.executable, "-m", "alembic", "upgrade", "head"],
        cwd=str(BACKEND_DIR),
        check=True,
        env=os.environ.copy(),
    )


@pytest.fixture(scope="session", autouse=True)
def prepared_database() -> None:
    try:
        asyncio.run(_ensure_app_role())
        _run_migrations()
        asyncio.run(_grant_table_privileges())
    except _CONNECT_ERRORS as exc:  # pragma: no cover
        pytest.skip(f"PostgreSQL no disponible; se omiten los tests de integración ({exc})")
    except subprocess.CalledProcessError as exc:  # pragma: no cover
        pytest.skip(f"No se pudieron aplicar migraciones; se omiten integración ({exc})")


@pytest_asyncio.fixture(autouse=True)
async def _clean_tables():
    """Deja las tablas vacías tras cada test (el dueño no está sujeto a RLS para TRUNCATE)."""
    yield
    engine = create_async_engine(_owner_url())
    try:
        async with engine.begin() as conn:
            await conn.execute(
                text("TRUNCATE users, tenants, admin_config RESTART IDENTITY CASCADE")
            )
    finally:
        await engine.dispose()


@pytest_asyncio.fixture(autouse=True)
async def _dispose_app_engine():
    """Desecha el engine global de la app tras cada test.

    Cada test corre en su propio event loop; sin esto, el pool del engine global
    conservaría conexiones ligadas a un loop ya cerrado (RuntimeError: Event loop is
    closed). Se desecha dentro del loop del test, cerrando las conexiones limpiamente.
    """
    yield
    from app.db.session import engine as app_engine

    await app_engine.dispose()


@pytest_asyncio.fixture
async def owner_sessions() -> async_sessionmaker:
    """Sesiones con el rol DUEÑO de las tablas.

    Sirve para reproducir el entorno de Neon (donde el rol de la base ignora RLS) y así
    comprobar que el aislamiento del código aguanta por sí solo.
    """
    engine = create_async_engine(_owner_url())
    try:
        yield async_sessionmaker(engine, expire_on_commit=False)
    finally:
        await engine.dispose()


@pytest_asyncio.fixture
async def app_sessions() -> async_sessionmaker:
    """Fábrica de sesiones conectadas con el rol de APLICACIÓN (sujeto a RLS)."""
    engine = create_async_engine(settings.database_url)
    try:
        yield async_sessionmaker(engine, expire_on_commit=False)
    finally:
        await engine.dispose()
