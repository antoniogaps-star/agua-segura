"""El equipo: el dueño da de alta a sus técnicos y les asigna las visitas.

Lo que se cuida aquí no es solo que funcione, sino **quién puede hacer qué**: el técnico
ve su agenda y registra el servicio, pero no administra usuarios ni ve la caja. Si eso se
rompe, un técnico podría hacerse dueño y ver cuánto factura el negocio.
"""

from httpx import ASGITransport, AsyncClient

from app.main import app


async def _client() -> AsyncClient:
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def _dueno(client: AsyncClient, slug: str = "agua-equipo") -> str:
    r = await client.post(
        "/api/v1/auth/register",
        json={
            "company_name": "Agua Segura",
            "company_slug": slug,
            "email": f"dueno@{slug}.com",
            "password": "password123",
        },
    )
    assert r.status_code == 201, r.text
    return r.json()["access_token"]


async def test_el_dueno_da_de_alta_a_su_tecnico() -> None:
    async with await _client() as client:
        auth = {"Authorization": f"Bearer {await _dueno(client)}"}
        alta = await client.post(
            "/api/v1/users",
            headers=auth,
            json={"email": "luis@agua.com", "password": "password123", "name": "Luis"},
        )
        assert alta.status_code == 201, alta.text
        assert alta.json()["name"] == "Luis"
        assert alta.json()["role"] == "operator"

        equipo = await client.get("/api/v1/users", headers=auth)

    nombres = {u["email"] for u in equipo.json()}
    assert nombres == {"dueno@agua-equipo.com", "luis@agua.com"}


async def test_el_tecnico_puede_entrar_y_ver_al_equipo() -> None:
    """Necesita ver los nombres: en la agenda tiene que saber a quién le tocó cada visita."""
    async with await _client() as client:
        auth = {"Authorization": f"Bearer {await _dueno(client)}"}
        await client.post(
            "/api/v1/users",
            headers=auth,
            json={"email": "luis@agua.com", "password": "password123", "name": "Luis"},
        )

        entrar = await client.post(
            "/api/v1/auth/login",
            json={
                "company_slug": "agua-equipo",
                "email": "luis@agua.com",
                "password": "password123",
            },
        )
        assert entrar.status_code == 200, entrar.text
        suyo = {"Authorization": f"Bearer {entrar.json()['access_token']}"}

        yo = await client.get("/api/v1/users/me", headers=suyo)
        equipo = await client.get("/api/v1/users", headers=suyo)

    assert yo.json()["name"] == "Luis"
    assert len(equipo.json()) == 2


async def test_el_tecnico_no_puede_dar_de_alta_a_nadie() -> None:
    """GUARDIÁN: si esto falla, un técnico se crea una cuenta de dueño y ve la caja."""
    async with await _client() as client:
        auth = {"Authorization": f"Bearer {await _dueno(client)}"}
        await client.post(
            "/api/v1/users",
            headers=auth,
            json={"email": "luis@agua.com", "password": "password123", "name": "Luis"},
        )
        entrar = await client.post(
            "/api/v1/auth/login",
            json={
                "company_slug": "agua-equipo",
                "email": "luis@agua.com",
                "password": "password123",
            },
        )
        suyo = {"Authorization": f"Bearer {entrar.json()['access_token']}"}

        intento = await client.post(
            "/api/v1/users",
            headers=suyo,
            json={
                "email": "yo-mero@agua.com",
                "password": "password123",
                "role": "owner",
            },
        )
    assert intento.status_code == 403
    assert intento.json()["error"]["code"] == "FORBIDDEN"


async def test_no_se_repite_el_correo_dentro_de_la_empresa() -> None:
    async with await _client() as client:
        auth = {"Authorization": f"Bearer {await _dueno(client)}"}
        datos = {"email": "luis@agua.com", "password": "password123", "name": "Luis"}
        await client.post("/api/v1/users", headers=auth, json=datos)
        repetido = await client.post("/api/v1/users", headers=auth, json=datos)
    assert repetido.status_code == 409
    assert repetido.json()["error"]["code"] == "EMAIL_TAKEN"


async def test_no_se_puede_quedar_sin_dueno() -> None:
    async with await _client() as client:
        token = await _dueno(client)
        auth = {"Authorization": f"Bearer {token}"}
        yo = await client.get("/api/v1/users/me", headers=auth)
        baja = await client.delete(f"/api/v1/users/{yo.json()['id']}", headers=auth)
    assert baja.status_code == 409
    assert baja.json()["error"]["code"] == "LAST_OWNER"


async def test_se_asigna_la_visita_al_tecnico() -> None:
    async with await _client() as client:
        auth = {"Authorization": f"Bearer {await _dueno(client)}"}
        tecnico = await client.post(
            "/api/v1/users",
            headers=auth,
            json={"email": "luis@agua.com", "password": "password123", "name": "Luis"},
        )
        cliente = await client.post(
            "/api/v1/clients", headers=auth, json={"name": "Sra. Martínez"}
        )
        visita = await client.post(
            "/api/v1/services",
            headers=auth,
            json={
                "client_id": cliente.json()["id"],
                "service_type": "tinacos",
                "technician_id": tecnico.json()["id"],
            },
        )
        assert visita.status_code == 201, visita.text
        assert visita.json()["technician_id"] == tecnico.json()["id"]

        # Y se puede pedir la agenda de ese técnico.
        suyas = await client.get(
            "/api/v1/services",
            headers=auth,
            params={"technician_id": tecnico.json()["id"]},
        )
    assert [j["id"] for j in suyas.json()] == [visita.json()["id"]]


async def test_no_se_asigna_a_un_tecnico_de_otra_empresa() -> None:
    """El técnico de otro negocio no existe para esta empresa."""
    async with await _client() as client:
        ajeno_auth = {"Authorization": f"Bearer {await _dueno(client, 'la-competencia')}"}
        ajeno = await client.post(
            "/api/v1/users",
            headers=ajeno_auth,
            json={"email": "otro@x.com", "password": "password123", "name": "Otro"},
        )

        auth = {"Authorization": f"Bearer {await _dueno(client)}"}
        cliente = await client.post(
            "/api/v1/clients", headers=auth, json={"name": "Sra. Martínez"}
        )
        intento = await client.post(
            "/api/v1/services",
            headers=auth,
            json={
                "client_id": cliente.json()["id"],
                "service_type": "tinacos",
                "technician_id": ajeno.json()["id"],
            },
        )
    assert intento.status_code == 404
    assert intento.json()["error"]["code"] == "TECHNICIAN_NOT_FOUND"
