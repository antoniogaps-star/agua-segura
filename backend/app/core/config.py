"""Configuración de la aplicación, cargada desde variables de entorno / .env.

Fuente única de verdad para settings. No leer os.environ directamente en otros
módulos: importar `settings` de aquí. Ver docs/06_Backend.md y docs/09_Seguridad.md.
"""

from functools import lru_cache
from typing import Literal
from urllib.parse import parse_qsl, urlencode

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

Environment = Literal["local", "test", "staging", "production"]

# Valores de ejemplo/débiles que NUNCA deben usarse en entornos reales.
_WEAK_SECRETS = {
    "CHANGE_ME",
    "CHANGE_ME_use_a_strong_random_secret",
    "ci-test-secret",
}
_MIN_SECRET_LENGTH = 32


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # ── Entorno ──────────────────────────────────────────────
    app_env: Environment = "local"
    debug: bool = False

    # ── Base de datos ────────────────────────────────────────
    # La APP se conecta con un rol NO superusuario para que RLS aplique de verdad.
    database_url: str = "postgresql+asyncpg://aguasegura_app:aguasegura_app@localhost:5432/aguasegura"
    # Las MIGRACIONES se ejecutan con el rol dueño (crea/altera tablas). Si no se
    # define, se usa database_url.
    migration_database_url: str | None = None

    # ── Seguridad / JWT ──────────────────────────────────────
    jwt_secret: str = "CHANGE_ME"
    jwt_algorithm: str = "HS256"
    access_token_ttl_minutes: int = 15
    refresh_token_ttl_days: int = 30

    # ── CORS ─────────────────────────────────────────────────
    cors_origins: str = "http://localhost:5173"

    # ── IA de dictado (capa gratuita) ────────────────────────
    # Se intentan en cascada: primero Groq, luego Gemini como respaldo. Sin ninguna
    # llave, el endpoint de voz responde 503 y el móvil usa reglas locales.
    # Groq (preferido: cupo gratuito amplio y estable)
    # Secreto para generar claves de activación (endpoint admin). Vacío = deshabilitado.
    license_admin_secret: str = ""
    groq_api_key: str = ""
    groq_model: str = "llama-3.3-70b-versatile"
    # Gemini (alternativa)
    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.0-flash-lite"

    @property
    def cors_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @field_validator("database_url", "migration_database_url", mode="before")
    @classmethod
    def _normalize_pg_scheme(cls, value: str | None) -> str | None:
        """Acepta URLs de Postgres de cualquier proveedor (Railway, Neon, Heroku…).

        - Los proveedores entregan `postgres://` o `postgresql://`; SQLAlchemy async
          necesita `postgresql+asyncpg://`.
        - asyncpg no entiende los parámetros libpq `sslmode` / `channel_binding`
          (típicos de Neon): se traducen a `ssl=` y se descarta channel_binding.
        Así la variable del proveedor se pega tal cual, sin ediciones manuales.
        """
        if value is None:
            return value
        for prefix in ("postgres://", "postgresql://"):
            if value.startswith(prefix) and not value.startswith("postgresql+"):
                value = "postgresql+asyncpg://" + value[len(prefix):]
                break
        if value.startswith("postgresql+asyncpg://") and "?" in value:
            base, _, query = value.partition("?")
            params = []
            for pair in parse_qsl(query):
                key, val = pair
                if key == "sslmode":
                    params.append(("ssl", val))
                elif key == "channel_binding":
                    continue
                else:
                    params.append(pair)
            value = base + (f"?{urlencode(params)}" if params else "")

        # Endpoints "pooler" (PgBouncer de Neon): las sentencias preparadas de asyncpg
        # no sobreviven al pool en modo transacción; se desactiva su caché.
        host = value.split("@")[-1].split("/")[0]
        if "-pooler" in host and "prepared_statement_cache_size" not in value:
            value += ("&" if "?" in value else "?") + "prepared_statement_cache_size=0"
        return value

    @model_validator(mode="after")
    def _require_strong_secret_in_real_envs(self) -> "Settings":
        """En staging/production, exige un JWT_SECRET fuerte (no el de ejemplo).

        Evita desplegar con una clave débil, que permitiría falsificar tokens de
        cualquier tenant. En local/test se permite el valor por defecto por comodidad.
        """
        if self.app_env in ("staging", "production"):
            if self.jwt_secret in _WEAK_SECRETS or len(self.jwt_secret) < _MIN_SECRET_LENGTH:
                raise ValueError(
                    "JWT_SECRET debe ser una clave fuerte "
                    f"(>= {_MIN_SECRET_LENGTH} caracteres, no el valor de ejemplo) "
                    f"en el entorno '{self.app_env}'."
                )
        return self

    @model_validator(mode="after")
    def _require_real_database_in_real_envs(self) -> "Settings":
        """En staging/production, rechaza una base de datos local.

        Si falta DATABASE_URL, el valor por defecto apunta a localhost y el error
        que sale es un traceback de red ilegible ("Connect call failed 127.0.0.1").
        Detectarlo aquí convierte ese muro en una frase que dice qué falta.
        """
        if self.app_env in ("staging", "production"):
            host = self.database_url.split("@")[-1].split("/")[0]
            if host.startswith(("localhost", "127.0.0.1", "[::1]")):
                raise ValueError(
                    "Falta la variable de entorno DATABASE_URL: apunta a una base "
                    f"local ({host}), que no existe en el servidor. Pega en el panel "
                    "del proveedor la URL de Neon (la que incluye '-pooler')."
                )
        return self


@lru_cache
def get_settings() -> Settings:
    """Devuelve la instancia única de Settings (cacheada)."""
    return Settings()


settings = get_settings()
