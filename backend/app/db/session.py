"""Configuración de la conexión asíncrona a PostgreSQL.

Provee el engine, la fábrica de sesiones y la dependencia `get_session` para FastAPI.
La inyección del tenant (RLS) se añade en un hito posterior sobre esta misma sesión.
Ver docs/06_Backend.md.
"""

from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.config import settings

engine = create_async_engine(
    settings.database_url,
    echo=settings.debug,
    pool_pre_ping=True,
)

SessionFactory = async_sessionmaker(
    bind=engine,
    expire_on_commit=False,
    autoflush=False,
)


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    """Dependencia de FastAPI: entrega una sesión por request y la cierra al final."""
    async with SessionFactory() as session:
        yield session
