"""Sincronización: contrato de /sync/push y /sync/pull.

Es el camino por el que sube el trabajo del técnico desde la azotea, así que se prueba
completo: cliente nuevo, servicio realizado y de vuelta por pull.
"""

from httpx import ASGITransport, AsyncClient

from app.main import app

CLIENTE_ID = "019f6868-9a2c-75b7-8cf1-36e2316aed01"
SERVICIO_ID = "019f6868-9a2c-75b7-8cf1-36e2316aed02"


async def _client() -> AsyncClient:
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def _token(client: AsyncClient) -> str:
    r = await client.post(
        "/api/v1/auth/register",
        json={
            "company_name": "Agua Segura Demo",
            "company_slug": "agua-demo",
            "email": "owner@agua.com",
            "password": "password123",
        },
    )
    return r.json()["access_token"]


def _cambio_cliente(**extra: object) -> dict[str, object]:
    base = {
        "entity": "client",
        "id": CLIENTE_ID,
        "op": "upsert",
        "version": 1,
        "updated_at": "2026-07-23T10:00:00Z",
        "data": {
            "name": "Sra. Martínez",
            "phone": "5512345678",
            "address": "Av. Juárez 120",
            "directions": "Portón verde, junto a la tienda",
            "notes": None,
        },
    }
    base.update(extra)
    return base


async def test_push_requiere_autenticacion() -> None:
    async with await _client() as client:
        r = await client.post("/api/v1/sync/push", json={"changes": []})
    assert r.status_code in (401, 403)


async def test_push_entidad_no_soportada() -> None:
    async with await _client() as client:
        token = await _token(client)
        r = await client.post(
            "/api/v1/sync/push",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "changes": [
                    {
                        "entity": "cosa_desconocida",
                        "id": "019f6868-9a2c-75b7-8cf1-36e2316aed71",
                        "op": "upsert",
                        "version": 1,
                        "updated_at": "2026-07-15T12:00:00Z",
                        "data": {},
                    }
                ]
            },
        )
    assert r.status_code == 200
    assert r.json()["results"][0]["status"] == "unsupported"


async def test_pull_devuelve_cursor() -> None:
    async with await _client() as client:
        token = await _token(client)
        r = await client.get("/api/v1/sync/pull", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200
    body = r.json()
    assert body["changes"] == []
    assert isinstance(body["cursor"], str)


async def test_cliente_y_servicio_suben_y_bajan() -> None:
    """El técnico registra todo sin señal; al reconectar sube y el panel ya lo ve."""
    async with await _client() as client:
        token = await _token(client)
        auth = {"Authorization": f"Bearer {token}"}

        push = await client.post(
            "/api/v1/sync/push",
            headers=auth,
            json={
                "changes": [
                    _cambio_cliente(),
                    {
                        "entity": "service_job",
                        "id": SERVICIO_ID,
                        "op": "upsert",
                        "version": 1,
                        "updated_at": "2026-07-23T14:30:00Z",
                        "data": {
                            "client_id": CLIENTE_ID,
                            "service_type": "tinacos",
                            "status": "realizado",
                            "performed_on": "2026-07-23",
                            "price_cents": 70000,
                            "is_paid": True,
                            "next_due_on": "2027-01-23",
                            "notes": "Tinaco de 1100 L",
                        },
                    },
                ]
            },
        )
        assert push.status_code == 200, push.text
        assert [r["status"] for r in push.json()["results"]] == ["applied", "applied"]

        pull = await client.get("/api/v1/sync/pull", headers=auth)

    assert pull.status_code == 200
    cambios = {c["entity"]: c for c in pull.json()["changes"]}
    assert cambios["client"]["data"]["directions"] == "Portón verde, junto a la tienda"
    servicio = cambios["service_job"]["data"]
    assert servicio["price_cents"] == 70000
    assert servicio["is_paid"] is True
    # La fecha del próximo lavado es lo que alimenta "¿a quién le toca?".
    assert servicio["next_due_on"] == "2027-01-23"


async def test_cambio_mas_viejo_no_pisa_al_nuevo() -> None:
    """Dos técnicos tocaron al mismo cliente: gana el cambio más reciente."""
    async with await _client() as client:
        token = await _token(client)
        auth = {"Authorization": f"Bearer {token}"}

        await client.post(
            "/api/v1/sync/push",
            headers=auth,
            json={"changes": [_cambio_cliente(updated_at="2026-07-23T15:00:00Z", version=2)]},
        )
        viejo = _cambio_cliente(updated_at="2026-07-23T09:00:00Z", version=1)
        viejo["data"] = {"name": "Nombre viejo"}  # type: ignore[assignment]
        r = await client.post("/api/v1/sync/push", headers=auth, json={"changes": [viejo]})

        assert r.json()["results"][0]["status"] == "conflict"

        pull = await client.get("/api/v1/sync/pull", headers=auth)
    cliente = next(c for c in pull.json()["changes"] if c["entity"] == "client")
    assert cliente["data"]["name"] == "Sra. Martínez"


async def test_servicio_de_cliente_ajeno_se_rechaza() -> None:
    """Un servicio no puede colgarse de un cliente que no es de esta empresa."""
    async with await _client() as client:
        token = await _token(client)
        r = await client.post(
            "/api/v1/sync/push",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "changes": [
                    {
                        "entity": "service_job",
                        "id": SERVICIO_ID,
                        "op": "upsert",
                        "version": 1,
                        "updated_at": "2026-07-23T14:30:00Z",
                        "data": {
                            "client_id": "019f6868-9a2c-75b7-8cf1-36e2316aedff",
                            "service_type": "tinacos",
                        },
                    }
                ]
            },
        )
    assert r.status_code == 200, r.text
    assert r.json()["results"][0]["status"] == "rejected"
