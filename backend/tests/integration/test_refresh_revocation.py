"""Revocación y rotación de refresh tokens (ADR-004)."""

from httpx import ASGITransport, AsyncClient

from app.main import app


async def _client() -> AsyncClient:
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def _register(client: AsyncClient) -> dict:
    r = await client.post(
        "/api/v1/auth/register",
        json={
            "company_name": "Sesiones",
            "company_slug": "sesiones",
            "email": "owner@sesiones.com",
            "password": "password123",
        },
    )
    return r.json()


async def test_refresh_rota_e_invalida_el_anterior() -> None:
    async with await _client() as client:
        tokens = await _register(client)
        old_refresh = tokens["refresh_token"]

        # Rotar: obtengo un refresh nuevo.
        r1 = await client.post("/api/v1/auth/refresh", json={"refresh_token": old_refresh})
        assert r1.status_code == 200
        new_refresh = r1.json()["refresh_token"]
        assert new_refresh != old_refresh

        # El anterior ya NO sirve (fue revocado en la rotación).
        r2 = await client.post("/api/v1/auth/refresh", json={"refresh_token": old_refresh})
        assert r2.status_code == 401

        # El nuevo sí sirve.
        r3 = await client.post("/api/v1/auth/refresh", json={"refresh_token": new_refresh})
        assert r3.status_code == 200


async def test_logout_revoca_el_refresh() -> None:
    async with await _client() as client:
        tokens = await _register(client)
        refresh = tokens["refresh_token"]

        logout = await client.post("/api/v1/auth/logout", json={"refresh_token": refresh})
        assert logout.status_code == 204

        # Tras logout, el refresh queda inutilizable.
        after = await client.post("/api/v1/auth/refresh", json={"refresh_token": refresh})
        assert after.status_code == 401


async def test_logout_es_idempotente() -> None:
    async with await _client() as client:
        tokens = await _register(client)
        refresh = tokens["refresh_token"]
        first = await client.post("/api/v1/auth/logout", json={"refresh_token": refresh})
        second = await client.post("/api/v1/auth/logout", json={"refresh_token": refresh})
    assert first.status_code == 204
    assert second.status_code == 204
