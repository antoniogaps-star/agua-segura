"""Validación de configuración (no requiere base de datos)."""

import pytest

from app.core.config import Settings


def test_secret_debil_rechazado_en_produccion(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", "CHANGE_ME")
    with pytest.raises(ValueError, match="JWT_SECRET"):
        Settings(_env_file=None)  # type: ignore[call-arg]


def test_secret_corto_rechazado_en_produccion(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", "corta")
    with pytest.raises(ValueError, match="JWT_SECRET"):
        Settings(_env_file=None)  # type: ignore[call-arg]


def test_secret_fuerte_aceptado_en_produccion(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", "x" * 40)
    # En producción el config exige una DATABASE_URL real (no localhost); se da una remota.
    monkeypatch.setenv(
        "DATABASE_URL", "postgresql+asyncpg://u:p@ep-x-pooler.neon.tech/db?ssl=require"
    )
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    assert settings.app_env == "production"


def test_secret_debil_permitido_en_local(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "local")
    monkeypatch.setenv("JWT_SECRET", "CHANGE_ME")
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    assert settings.app_env == "local"


def test_url_de_proveedor_se_normaliza_a_asyncpg(monkeypatch: pytest.MonkeyPatch) -> None:
    """Railway/Heroku entregan postgres:// — debe convertirse a postgresql+asyncpg://."""
    monkeypatch.setenv("DATABASE_URL", "postgresql://u:p@host:5432/db")
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    assert settings.database_url == "postgresql+asyncpg://u:p@host:5432/db"

    monkeypatch.setenv("DATABASE_URL", "postgres://u:p@host:5432/db")
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    assert settings.database_url == "postgresql+asyncpg://u:p@host:5432/db"

    # Una URL ya correcta no se toca.
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://u:p@host:5432/db")
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    assert settings.database_url == "postgresql+asyncpg://u:p@host:5432/db"


def test_url_de_neon_traduce_ssl(monkeypatch: pytest.MonkeyPatch) -> None:
    """Neon usa sslmode/channel_binding (libpq); asyncpg necesita ssl= y sin channel_binding."""
    monkeypatch.setenv(
        "DATABASE_URL",
        "postgresql://u:p@ep-x.neon.tech/db?sslmode=require&channel_binding=require",
    )
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    assert settings.database_url == "postgresql+asyncpg://u:p@ep-x.neon.tech/db?ssl=require"


def test_url_pooler_desactiva_cache_de_preparadas(monkeypatch: pytest.MonkeyPatch) -> None:
    """Con el endpoint -pooler (PgBouncer), asyncpg necesita el caché de preparadas en 0."""
    monkeypatch.setenv(
        "DATABASE_URL",
        "postgresql://u:p@ep-x-pooler.c-10.aws.neon.tech/db?sslmode=require&channel_binding=require",
    )
    settings = Settings(_env_file=None)  # type: ignore[call-arg]
    assert settings.database_url == (
        "postgresql+asyncpg://u:p@ep-x-pooler.c-10.aws.neon.tech/db"
        "?ssl=require&prepared_statement_cache_size=0"
    )
