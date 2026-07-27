"""Reja de suscripción: al vencer la prueba gratis, la cuenta entra en solo-lectura.

Las ESCRITURAS (POST/DELETE/…) responden 402 SUBSCRIPTION_EXPIRED; las LECTURAS (GET)
siguen funcionando para que la empresa vea sus datos y pueda canjear una clave.
"""

from datetime import UTC, datetime, timedelta

from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

from app.core.config import settings
from app.main import app


async def _client() -> AsyncClient:
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def _register(client: AsyncClient, slug: str) -> str:
    r = await client.post(
        "/api/v1/auth/register",
        json={
            "company_name": slug,
            "company_slug": slug,
            "email": f"dueno@{slug}.com",
            "password": "password123",
        },
    )
    assert r.status_code == 201, r.text
    return r.json()["access_token"]


async def _backdate_trial(slug: str) -> None:
    """Retrasa created_at más allá de la prueba (7 días) para simular vencimiento."""
    engine = create_async_engine(settings.migration_database_url or settings.database_url)
    try:
        async with engine.begin() as conn:
            await conn.execute(
                text("UPDATE tenants SET created_at = :old WHERE slug = :slug"),
                {"old": datetime.now(UTC) - timedelta(days=8), "slug": slug},
            )
    finally:
        await engine.dispose()


async def test_prueba_vigente_permite_escribir() -> None:
    async with await _client() as client:
        access = await _register(client, "vigente")
        r = await client.post(
            "/api/v1/clients",
            json={"name": "Sra. Martínez"},
            headers={"Authorization": f"Bearer {access}"},
        )
    assert r.status_code == 201, r.text


async def test_prueba_vencida_bloquea_escritura_pero_deja_leer() -> None:
    async with await _client() as client:
        access = await _register(client, "vencida")
        auth = {"Authorization": f"Bearer {access}"}
        await _backdate_trial("vencida")

        # Escritura -> 402 con el código esperado.
        blocked = await client.post(
            "/api/v1/clients", json={"name": "Cliente nuevo"}, headers=auth
        )
        assert blocked.status_code == 402, blocked.text
        assert blocked.json()["error"]["code"] == "SUBSCRIPTION_EXPIRED"

        # Lectura -> 200: sigue viendo su cartera.
        read = await client.get("/api/v1/clients", headers=auth)
        assert read.status_code == 200

        # /billing/redeem no se bloquea (para poder reactivar) — clave inexistente = 404,
        # no 402: prueba que la reja NO cubre billing.
        reactivar = await client.post(
            "/api/v1/billing/redeem", json={"code": "AGUA-XXXX-XXXX"}, headers=auth
        )
        assert reactivar.status_code == 404
