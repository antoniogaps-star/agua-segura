"""Lógica de los servicios y del recordatorio de mantenimiento.

DEFENSA EN PROFUNDIDAD: cada consulta filtra por `tenant_id` explícitamente, además de
la política RLS de Postgres. No basta con RLS: hay proveedores (Neon, entre otros) donde
el rol de la base **ignora** las políticas por tener privilegios elevados, y entonces una
empresa vería la cartera de clientes de otra.
"""

from datetime import date
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.clients.models import Client
from app.modules.services.models import PERIODICIDAD_MESES, ServiceJob
from app.modules.users.models import User
from app.shared.errors import api_error


def siguiente_fecha(service_type: str, desde: date) -> date | None:
    """Cuándo toca repetir un servicio. Devuelve None si no es preventivo (plomería).

    Se suma en MESES, no en días: "seis meses después del 31 de enero" es el 31 de julio,
    no 181 días exactos. Y si el día no existe en el mes destino (31 de agosto + 6 meses),
    se recorre al último día de ese mes.
    """
    meses = PERIODICIDAD_MESES.get(service_type)
    if meses is None:
        return None

    total = desde.month - 1 + meses
    anio = desde.year + total // 12
    mes = total % 12 + 1
    # Último día del mes destino, para no construir una fecha inexistente.
    if mes == 12:
        ultimo = 31
    else:
        ultimo = (date(anio, mes + 1, 1) - date.resolution).day
    return date(anio, mes, min(desde.day, ultimo))


async def _tecnico_de_la_empresa(
    session: AsyncSession, technician_id: UUID | None, tenant_id: UUID
) -> UUID | None:
    """El técnico asignado tiene que ser usuario de ESTA empresa.

    Si no, la visita quedaría a nombre de alguien de otro negocio y no aparecería en la
    agenda de nadie.
    """
    if technician_id is None:
        return None
    rows = await session.execute(
        select(User).where(
            User.id == technician_id,
            User.tenant_id == tenant_id,
            User.is_deleted.is_(False),
        )
    )
    if rows.scalars().first() is None:
        raise api_error(404, "TECHNICIAN_NOT_FOUND", "Ese técnico no existe")
    return technician_id


async def get_job(session: AsyncSession, job_id: UUID, tenant_id: UUID) -> ServiceJob | None:
    """Busca un servicio SOLO dentro de la empresa indicada."""
    rows = await session.execute(
        select(ServiceJob).where(ServiceJob.id == job_id, ServiceJob.tenant_id == tenant_id)
    )
    return rows.scalars().first()


async def create_job(
    session: AsyncSession,
    *,
    tenant_id: UUID,
    client_id: UUID,
    service_type: str,
    scheduled_for: object | None = None,
    technician_id: UUID | None = None,
    notes: str | None = None,
    price_cents: int = 0,
) -> ServiceJob:
    # El cliente debe ser de ESTA empresa: si no, no existe para nosotros.
    rows = await session.execute(
        select(Client).where(Client.id == client_id, Client.tenant_id == tenant_id)
    )
    cliente = rows.scalars().first()
    if cliente is None or cliente.is_deleted:
        raise api_error(404, "CLIENT_NOT_FOUND", "Cliente no encontrado")

    job = ServiceJob(
        tenant_id=tenant_id,
        client_id=client_id,
        service_type=service_type,
        status="agendado",
        scheduled_for=scheduled_for,
        technician_id=await _tecnico_de_la_empresa(session, technician_id, tenant_id),
        notes=notes,
        price_cents=price_cents,
    )
    session.add(job)
    await session.flush()
    return job


async def complete_job(
    session: AsyncSession,
    job_id: UUID,
    tenant_id: UUID,
    *,
    performed_on: date | None = None,
    price_cents: int | None = None,
    is_paid: bool | None = None,
    notes: str | None = None,
    technician_id: UUID | None = None,
) -> ServiceJob:
    """Marca el servicio como realizado y programa el siguiente.

    Aquí es donde se resuelve el problema que originó la app: al terminar, la fecha del
    próximo mantenimiento queda anotada sola. Nadie tiene que acordarse.
    """
    job = await get_job(session, job_id, tenant_id)
    if job is None or job.is_deleted:
        raise api_error(404, "SERVICE_NOT_FOUND", "Servicio no encontrado")

    job.status = "realizado"
    job.performed_on = performed_on or date.today()
    if price_cents is not None:
        job.price_cents = price_cents
    if is_paid is not None:
        job.is_paid = is_paid
    if notes is not None:
        job.notes = notes
    if technician_id is not None:
        job.technician_id = await _tecnico_de_la_empresa(session, technician_id, tenant_id)

    job.next_due_on = siguiente_fecha(job.service_type, job.performed_on)
    job.version += 1
    await session.flush()
    return job


async def list_jobs(
    session: AsyncSession,
    tenant_id: UUID,
    *,
    status: str | None = None,
    technician_id: UUID | None = None,
) -> list[ServiceJob]:
    query = select(ServiceJob).where(
        ServiceJob.tenant_id == tenant_id, ServiceJob.is_deleted.is_(False)
    )
    if status is not None:
        query = query.where(ServiceJob.status == status)
    if technician_id is not None:
        query = query.where(ServiceJob.technician_id == technician_id)
    rows = await session.execute(
        query.order_by(ServiceJob.scheduled_for.nulls_last(), ServiceJob.performed_on.desc())
    )
    return list(rows.scalars().all())


async def delete_job(session: AsyncSession, job_id: UUID, tenant_id: UUID) -> None:
    job = await get_job(session, job_id, tenant_id)
    if job is None or job.is_deleted:
        raise api_error(404, "SERVICE_NOT_FOUND", "Servicio no encontrado")
    job.is_deleted = True
    job.version += 1
    await session.flush()


# ── ¿A QUIÉN LE TOCA? ────────────────────────────────────────
# La pantalla estrella. Todo lo demás existe para alimentar esta consulta.

async def pendientes(
    session: AsyncSession, tenant_id: UUID, *, dentro_de_dias: int = 30
) -> list[dict[str, object]]:
    """Clientes a los que ya les tocó su mantenimiento, o les toca pronto.

    Se toma el ÚLTIMO servicio realizado de cada cliente+tipo (un cliente puede tener
    tinacos y calentadores con fechas distintas) y se descarta si ya hay otra visita
    agendada: no tiene caso recordarle a alguien que ya tiene cita.

    Devuelve, por cada pendiente, cuántos días lleva vencido (negativo = aún no vence),
    para que la app pueda pintarlo en rojo, amarillo o verde sin recalcular nada.
    """
    hoy = date.today()

    # El servicio realizado más reciente por cliente y tipo.
    ultimo = (
        select(
            ServiceJob.client_id,
            ServiceJob.service_type,
            func.max(ServiceJob.performed_on).label("ultima_fecha"),
        )
        .where(
            ServiceJob.tenant_id == tenant_id,
            ServiceJob.is_deleted.is_(False),
            ServiceJob.status == "realizado",
            ServiceJob.next_due_on.is_not(None),
        )
        .group_by(ServiceJob.client_id, ServiceJob.service_type)
        .subquery()
    )

    filas = await session.execute(
        select(ServiceJob, Client)
        .join(
            ultimo,
            (ServiceJob.client_id == ultimo.c.client_id)
            & (ServiceJob.service_type == ultimo.c.service_type)
            & (ServiceJob.performed_on == ultimo.c.ultima_fecha),
        )
        .join(Client, Client.id == ServiceJob.client_id)
        .where(
            ServiceJob.tenant_id == tenant_id,
            Client.tenant_id == tenant_id,
            Client.is_deleted.is_(False),
            ServiceJob.is_deleted.is_(False),
            ServiceJob.status == "realizado",
            ServiceJob.next_due_on.is_not(None),
        )
    )

    # Qué clientes YA tienen una visita agendada: a esos no se les recuerda.
    agendados = await session.execute(
        select(ServiceJob.client_id, ServiceJob.service_type).where(
            ServiceJob.tenant_id == tenant_id,
            ServiceJob.is_deleted.is_(False),
            ServiceJob.status == "agendado",
        )
    )
    ya_agendado = {(c, t) for c, t in agendados.all()}

    resultado: list[dict[str, object]] = []
    for job, cliente in filas.all():
        if (job.client_id, job.service_type) in ya_agendado:
            continue
        assert job.next_due_on is not None
        dias = (hoy - job.next_due_on).days
        if dias < -dentro_de_dias:
            continue  # todavía falta mucho
        resultado.append(
            {
                "client_id": job.client_id,
                "client_name": cliente.name,
                "client_phone": cliente.phone,
                "service_type": job.service_type,
                "last_service_on": job.performed_on,
                "due_on": job.next_due_on,
                # Positivo = ya se pasó · Negativo = aún faltan días.
                "days_overdue": dias,
            }
        )

    # Lo más vencido primero: es lo que el dueño tiene que atender hoy.
    resultado.sort(key=lambda r: r["days_overdue"], reverse=True)  # type: ignore[arg-type,return-value]
    return resultado
