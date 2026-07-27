"""Flujo de autenticación end-to-end contra Postgres real: register → login → /me."""

from httpx import ASGITransport, AsyncClient

from app.core.config import settings
from app.main import app


async def _client() -> AsyncClient:
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def test_register_login_me() -> None:
    creds = {
        "company_name": "Michilín",
        "company_slug": "michilin",
        "email": "dueno@michilin.com",
        "password": "password123",
    }
    async with await _client() as client:
        # Registro (onboarding): crea empresa + Owner y devuelve tokens.
        r = await client.post("/api/v1/auth/register", json=creds)
        assert r.status_code == 201, r.text
        access = r.json()["access_token"]

        # El token da acceso al propio perfil.
        me = await client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {access}"})
        assert me.status_code == 200
        body = me.json()
        assert body["email"] == creds["email"]
        assert body["role"] == "owner"

        # Login posterior con slug + email + contraseña.
        login = await client.post(
            "/api/v1/auth/login",
            json={k: creds[k] for k in ("company_slug", "email", "password")},
        )
        assert login.status_code == 200
        assert "access_token" in login.json()


async def test_login_credenciales_invalidas() -> None:
    async with await _client() as client:
        await client.post(
            "/api/v1/auth/register",
            json={
                "company_name": "Michilín",
                "company_slug": "michilin",
                "email": "dueno@michilin.com",
                "password": "password123",
            },
        )
        bad = await client.post(
            "/api/v1/auth/login",
            json={
                "company_slug": "michilin",
                "email": "dueno@michilin.com",
                "password": "mala1234",
            },
        )
    assert bad.status_code == 401
    assert bad.json()["error"]["code"] == "INVALID_CREDENTIALS"


async def test_login_password_corto_da_401_no_422() -> None:
    """Al ENTRAR no se valida la longitud de la contraseña. Un password corto (un typo)
    debe caer en 401 'Credenciales inválidas' —el mensaje correcto en la pantalla de
    entrada— y NO en un 422 de validación que confundiría al usuario."""
    async with await _client() as client:
        await client.post(
            "/api/v1/auth/register",
            json={
                "company_name": "Cortito",
                "company_slug": "cortito",
                "email": "dueno@cortito.com",
                "password": "password123",
            },
        )
        r = await client.post(
            "/api/v1/auth/login",
            json={
                "company_slug": "cortito",
                "email": "dueno@cortito.com",
                "password": "corta",  # < 8 caracteres
            },
        )
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "INVALID_CREDENTIALS"


async def test_reset_password_por_admin() -> None:
    """El dueño (con el secreto de admin) restablece la contraseña de una cuenta que
    olvidó su clave, y luego se puede entrar con la nueva."""
    creds = {
        "company_name": "Abarrotes Toño",
        "company_slug": "abarrotestono",
        "email": "dueno@tono.com",
        "password": "vieja12345",
    }
    old_secret = settings.license_admin_secret
    settings.license_admin_secret = "secreto-de-tono"
    try:
        async with await _client() as client:
            reg = await client.post("/api/v1/auth/register", json=creds)
            assert reg.status_code == 201, reg.text

            # Sin secreto correcto: prohibido.
            r = await client.post(
                "/api/v1/auth/reset-password",
                json={
                    "company_slug": creds["company_slug"],
                    "email": creds["email"],
                    "new_password": "nueva12345",
                },
                headers={"X-Admin-Secret": "mal-secreto"},
            )
            assert r.status_code == 403

            # Con secreto correcto: restablece.
            r = await client.post(
                "/api/v1/auth/reset-password",
                json={
                    "company_slug": creds["company_slug"],
                    "email": creds["email"],
                    "new_password": "nueva12345",
                },
                headers={"X-Admin-Secret": "secreto-de-tono"},
            )
            assert r.status_code == 204, r.text

            # La contraseña vieja ya no sirve.
            old = await client.post(
                "/api/v1/auth/login",
                json={
                    "company_slug": creds["company_slug"],
                    "email": creds["email"],
                    "password": "vieja12345",
                },
            )
            assert old.status_code == 401

            # La nueva sí.
            new = await client.post(
                "/api/v1/auth/login",
                json={
                    "company_slug": creds["company_slug"],
                    "email": creds["email"],
                    "password": "nueva12345",
                },
            )
            assert new.status_code == 200, new.text
            assert "access_token" in new.json()
    finally:
        settings.license_admin_secret = old_secret


async def test_reset_password_con_secreto_en_el_cuerpo() -> None:
    """El secreto de admin se puede mandar en el CUERPO (admin_secret), sin header.

    Un header HTTP no admite caracteres no-ASCII (acentos, ñ, emojis) y rompía la
    petición en el cliente; el cuerpo JSON sí los admite. Aquí el secreto lleva una ñ y
    un acento para cubrir justamente ese caso."""
    creds = {
        "company_name": "Piñatería Ñoño",
        "company_slug": "pinateria",
        "email": "dueno@pinateria.com",
        "password": "vieja12345",
    }
    old_secret = settings.license_admin_secret
    settings.license_admin_secret = "señór-piñata-café"  # no-ASCII a propósito
    try:
        async with await _client() as client:
            reg = await client.post("/api/v1/auth/register", json=creds)
            assert reg.status_code == 201, reg.text

            # Secreto correcto EN EL CUERPO (sin header): restablece.
            r = await client.post(
                "/api/v1/auth/reset-password",
                json={
                    "company_slug": creds["company_slug"],
                    "email": creds["email"],
                    "new_password": "nueva12345",
                    "admin_secret": "señór-piñata-café",
                },
            )
            assert r.status_code == 204, r.text

            # Entra con la nueva contraseña.
            new = await client.post(
                "/api/v1/auth/login",
                json={
                    "company_slug": creds["company_slug"],
                    "email": creds["email"],
                    "password": "nueva12345",
                },
            )
            assert new.status_code == 200, new.text
    finally:
        settings.license_admin_secret = old_secret


async def test_bootstrap_admin_desde_la_app() -> None:
    """Sin variable de entorno, el dueño configura el secreto DESDE LA APP y con él
    puede restablecer contraseñas. Un segundo bootstrap se rechaza (409)."""
    old_secret = settings.license_admin_secret
    settings.license_admin_secret = ""  # forzamos el modo "configurar desde la app"
    creds = {
        "company_name": "Depósito Uno",
        "company_slug": "depositouno",
        "email": "dueno@deposito.com",
        "password": "vieja12345",
    }
    try:
        async with await _client() as client:
            await client.post("/api/v1/auth/register", json=creds)

            # Antes de configurar: no hay secreto.
            st = await client.get("/api/v1/auth/admin-status")
            assert st.json() == {"admin_secret_configured": False}

            # Restablecer sin secreto configurado: 503.
            r = await client.post(
                "/api/v1/auth/reset-password",
                json={
                    "company_slug": creds["company_slug"],
                    "email": creds["email"],
                    "new_password": "nueva12345",
                },
                headers={"X-Admin-Secret": "loquesea"},
            )
            assert r.status_code == 503

            # Configurar por primera vez desde la app.
            b = await client.post("/api/v1/auth/admin/bootstrap", json={"secret": "claveadmin7"})
            assert b.status_code == 201, b.text

            # Ahora sí hay secreto.
            st = await client.get("/api/v1/auth/admin-status")
            assert st.json() == {"admin_secret_configured": True}

            # Un segundo bootstrap se rechaza.
            b2 = await client.post("/api/v1/auth/admin/bootstrap", json={"secret": "otro123"})
            assert b2.status_code == 409

            # Secreto equivocado: 403.
            bad = await client.post(
                "/api/v1/auth/reset-password",
                json={
                    "company_slug": creds["company_slug"],
                    "email": creds["email"],
                    "new_password": "nueva12345",
                },
                headers={"X-Admin-Secret": "malo"},
            )
            assert bad.status_code == 403

            # Secreto correcto: restablece y se entra con la nueva contraseña.
            ok = await client.post(
                "/api/v1/auth/reset-password",
                json={
                    "company_slug": creds["company_slug"],
                    "email": creds["email"],
                    "new_password": "nueva12345",
                },
                headers={"X-Admin-Secret": "claveadmin7"},
            )
            assert ok.status_code == 204, ok.text

            login = await client.post(
                "/api/v1/auth/login",
                json={
                    "company_slug": creds["company_slug"],
                    "email": creds["email"],
                    "password": "nueva12345",
                },
            )
            assert login.status_code == 200, login.text
    finally:
        settings.license_admin_secret = old_secret
