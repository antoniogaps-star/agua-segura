"""El aislamiento debe aguantar AUNQUE la base no aplique RLS.

Por qué existe esta prueba: en producción (Neon) el rol de la base tiene privilegios
elevados y **ignora** las políticas RLS. Con el aislamiento delegado solo a Postgres, una
empresa alcanzaba a ver los datos de otra. Pasó de verdad, en producción, en otra app.

Aquí se reproduce ese entorno a propósito: se quita el FORCE de las políticas, con lo que
el rol dueño deja de estar sujeto a ellas — exactamente lo que pasa en Neon. Luego se
comprueba que las consultas del código siguen filtrando por tenant. Si alguien vuelve a
escribir una consulta sin `WHERE tenant_id`, esta prueba falla.

Para este negocio lo que está en juego es la **cartera de clientes**: es su activo, la
consiguieron por recomendación una por una.
"""

from datetime import UTC, date, datetime
from uuid import uuid4

import pytest
from sqlalchemy import text

# Importar el modelo de tenants completa el mapeo (clientes y servicios lo referencian).
import app.modules.tenants.models  # noqa: F401
from app.modules.clients import service as clients
from app.modules.services import service as services
from app.sync import service as sync
from app.sync.schemas import Change, PushRequest

_TABLAS = ("clients", "service_jobs")


@pytest.fixture
async def base_sin_aislamiento(owner_sessions):
    """Deja la base como Neon: las políticas existen pero NO se aplican a este rol."""
    async with owner_sessions() as s:
        for t in _TABLAS:
            await s.execute(text(f"ALTER TABLE {t} NO FORCE ROW LEVEL SECURITY"))
        await s.commit()
    yield
    async with owner_sessions() as s:
        for t in _TABLAS:
            await s.execute(text(f"ALTER TABLE {t} FORCE ROW LEVEL SECURITY"))
        await s.commit()


@pytest.fixture
async def dos_negocios(base_sin_aislamiento, owner_sessions):
    """Dos empresas con un cliente cada una. Devuelve (empresa_a, empresa_b, id_cliente_a)."""
    empresa_a, empresa_b = uuid4(), uuid4()
    async with owner_sessions() as s:
        for t, nombre in ((empresa_a, "Agua Segura"), (empresa_b, "La Competencia")):
            await s.execute(
                text("INSERT INTO tenants (id, name, slug) VALUES (:i, :n, :s)"),
                {"i": t, "n": nombre, "s": str(t)[:8]},
            )
        await s.commit()

    async with owner_sessions() as s:
        cliente_a = await clients.create_client(
            s, tenant_id=empresa_a, name="Sra. Martínez", phone="5512345678"
        )
        await clients.create_client(s, tenant_id=empresa_b, name="Cliente de la otra")
        await s.commit()
        id_a = cliente_a.id

    return empresa_a, empresa_b, id_a


async def test_listar_clientes_no_filtra_de_mas(dos_negocios, owner_sessions) -> None:
    """Cada empresa ve SOLO su cartera, aunque la base no esté filtrando."""
    empresa_a, empresa_b, _ = dos_negocios
    async with owner_sessions() as s:
        de_a = [c.name for c in await clients.list_clients(s, empresa_a)]
        de_b = [c.name for c in await clients.list_clients(s, empresa_b)]
    assert de_a == ["Sra. Martínez"]
    assert de_b == ["Cliente de la otra"]


async def test_no_se_puede_borrar_el_cliente_de_otro(dos_negocios, owner_sessions) -> None:
    """B intenta borrar un cliente de A por su id: debe responder 'no encontrado'."""
    _, empresa_b, id_de_a = dos_negocios
    async with owner_sessions() as s:
        with pytest.raises(Exception) as fallo:
            await clients.delete_client(s, id_de_a, empresa_b)
    assert "CLIENT_NOT_FOUND" in str(fallo.value)


async def test_no_se_puede_editar_el_cliente_de_otro(dos_negocios, owner_sessions) -> None:
    _, empresa_b, id_de_a = dos_negocios
    async with owner_sessions() as s:
        with pytest.raises(Exception) as fallo:
            await clients.update_client(s, id_de_a, empresa_b, {"phone": "0000000000"})
    assert "CLIENT_NOT_FOUND" in str(fallo.value)


async def test_no_se_puede_agendar_al_cliente_de_otro(dos_negocios, owner_sessions) -> None:
    """Agendarle una visita a un cliente ajeno sería meterse en su cartera."""
    _, empresa_b, id_de_a = dos_negocios
    async with owner_sessions() as s:
        with pytest.raises(Exception) as fallo:
            await services.create_job(
                s, tenant_id=empresa_b, client_id=id_de_a, service_type="tinacos"
            )
    assert "CLIENT_NOT_FOUND" in str(fallo.value)


async def test_no_se_puede_completar_el_servicio_de_otro(dos_negocios, owner_sessions) -> None:
    empresa_a, empresa_b, id_de_a = dos_negocios
    async with owner_sessions() as s:
        job = await services.create_job(
            s, tenant_id=empresa_a, client_id=id_de_a, service_type="tinacos"
        )
        await s.commit()
        job_id = job.id

    async with owner_sessions() as s:
        with pytest.raises(Exception) as fallo:
            await services.complete_job(s, job_id, empresa_b)
    assert "SERVICE_NOT_FOUND" in str(fallo.value)


async def test_a_quien_le_toca_no_mezcla_empresas(dos_negocios, owner_sessions) -> None:
    """La pantalla estrella no puede soplarle a nadie la cartera del vecino."""
    empresa_a, empresa_b, id_de_a = dos_negocios
    async with owner_sessions() as s:
        job = await services.create_job(
            s, tenant_id=empresa_a, client_id=id_de_a, service_type="tinacos"
        )
        # Lavado de hace ocho meses: ya se pasó del plazo de seis.
        await services.complete_job(
            s, job.id, empresa_a, performed_on=date.today().replace(year=date.today().year - 1)
        )
        await s.commit()

    async with owner_sessions() as s:
        de_a = await services.pendientes(s, empresa_a)
        de_b = await services.pendientes(s, empresa_b)

    assert [p["client_name"] for p in de_a] == ["Sra. Martínez"]
    assert de_b == []


async def test_el_pull_no_arrastra_la_cartera_ajena(dos_negocios, owner_sessions) -> None:
    _, empresa_b, _ = dos_negocios
    async with owner_sessions() as s:
        respuesta = await sync.pull(s, empresa_b, None)
    nombres = [c.data["name"] for c in respuesta.changes if c.entity == "client" and c.data]
    assert nombres == ["Cliente de la otra"]


async def test_el_push_no_sobrescribe_el_cliente_de_otro(dos_negocios, owner_sessions) -> None:
    """Lo más peligroso: B empuja un cambio con el id de un cliente de A."""
    empresa_a, empresa_b, id_de_a = dos_negocios
    async with owner_sessions() as s:
        respuesta = await sync.push(
            s,
            empresa_b,
            PushRequest(
                changes=[
                    Change(
                        entity="client",
                        id=id_de_a,
                        op="upsert",
                        version=99,
                        updated_at=datetime.now(UTC),
                        data={"name": "SECUESTRADO"},
                    )
                ]
            ),
        )
        await s.commit()

    # Se rechaza con un estado claro, no con un error del servidor.
    assert respuesta.results[0].status == "rejected"

    async with owner_sessions() as s:
        de_a = [c.name for c in await clients.list_clients(s, empresa_a)]
    assert de_a == ["Sra. Martínez"], "una empresa sobrescribió el cliente de otra"


async def test_el_push_no_borra_el_servicio_de_otro(dos_negocios, owner_sessions) -> None:
    empresa_a, empresa_b, id_de_a = dos_negocios
    async with owner_sessions() as s:
        job = await services.create_job(
            s, tenant_id=empresa_a, client_id=id_de_a, service_type="tinacos"
        )
        await s.commit()
        job_id = job.id

    async with owner_sessions() as s:
        respuesta = await sync.push(
            s,
            empresa_b,
            PushRequest(
                changes=[
                    Change(
                        entity="service_job",
                        id=job_id,
                        op="delete",
                        version=99,
                        updated_at=datetime.now(UTC),
                        data={"client_id": str(id_de_a)},
                    )
                ]
            ),
        )
        await s.commit()

    assert respuesta.results[0].status == "rejected"

    async with owner_sessions() as s:
        vivos = await services.list_jobs(s, empresa_a)
    assert len(vivos) == 1


async def test_no_se_puede_marcar_como_recomendador_a_un_cliente_ajeno(
    dos_negocios, owner_sessions
) -> None:
    """B da de alta a alguien diciendo que lo recomendó un cliente de A.

    Si se aceptara, la lista de "quién te trae clientes" de B apuntaría a alguien de la
    cartera de A — y eso es filtrar información entre empresas.
    """
    _, empresa_b, id_de_a = dos_negocios
    async with owner_sessions() as s:
        nuevo = await clients.create_client(
            s, tenant_id=empresa_b, name="Vecino", referred_by_id=id_de_a
        )
        await s.commit()
        assert nuevo.referred_by_id is None


async def test_recomendadores_no_mezcla_empresas(dos_negocios, owner_sessions) -> None:
    empresa_a, empresa_b, id_de_a = dos_negocios
    async with owner_sessions() as s:
        await clients.create_client(
            s, tenant_id=empresa_a, name="Vecina de la Sra.", referred_by_id=id_de_a
        )
        await s.commit()

    async with owner_sessions() as s:
        de_a = await clients.recomendadores(s, empresa_a)
        de_b = await clients.recomendadores(s, empresa_b)

    assert [(r["name"], r["recomendados"]) for r in de_a] == [("Sra. Martínez", 1)]
    assert de_b == []
