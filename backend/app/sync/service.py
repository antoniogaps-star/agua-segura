"""Motor de sincronización de Agua Segura.

Los técnicos trabajan en azoteas, donde casi nunca hay señal: registran el servicio ahí
arriba y todo sube cuando vuelven a tener internet.

Política por entidad (client y service_job): gana el cambio más reciente (last-write-wins
por `updated_at`), con soporte de borrado. Si lo que llega es más viejo que lo que ya está
en el servidor, se responde `conflict` con la versión del servidor y el móvil decide.

DEFENSA EN PROFUNDIDAD: todas las consultas filtran por `tenant_id` explícitamente, además
de RLS. Aquí importa doble: sin ese filtro, un push con el id de una fila ajena la
SOBRESCRIBIRÍA, y un pull devolvería la cartera de clientes de otra empresa.
"""

from datetime import UTC, date, datetime
from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.clients.models import Client
from app.modules.services.models import ServiceJob
from app.modules.users.models import User
from app.sync.schemas import Change, ChangeResult, PullResponse, PushRequest, PushResponse

SUPPORTED_ENTITIES = {"client", "service_job"}

# El equipo (dueño y técnicos) solo BAJA al móvil: las altas se hacen en /users, no por
# sincronización, porque hay que fijar la contraseña y validar quién puede crearlas.


def _fecha(valor: Any) -> date | None:
    """Texto ISO → date. Tolera nulo y cadena vacía."""
    if valor in (None, ""):
        return None
    return date.fromisoformat(valor) if isinstance(valor, str) else valor


def _momento(valor: Any) -> datetime | None:
    if valor in (None, ""):
        return None
    return datetime.fromisoformat(valor) if isinstance(valor, str) else valor


# ── Serialización modelo → data ──────────────────────────────
def _client_data(c: Client) -> dict[str, Any]:
    return {
        "name": c.name,
        "phone": c.phone,
        "address": c.address,
        "directions": c.directions,
        "notes": c.notes,
        "referred_by_id": str(c.referred_by_id) if c.referred_by_id else None,
    }


def _user_data(u: User) -> dict[str, Any]:
    return {
        "email": u.email,
        "name": u.name,
        "role": u.role,
        "is_active": u.is_active,
    }


def _job_data(j: ServiceJob) -> dict[str, Any]:
    return {
        "client_id": str(j.client_id),
        "service_type": j.service_type,
        "status": j.status,
        # Fechas y horas viajan como texto ISO para que el móvil las lea sin ambigüedad.
        "scheduled_for": j.scheduled_for.isoformat() if j.scheduled_for else None,
        "performed_on": j.performed_on.isoformat() if j.performed_on else None,
        "technician_id": str(j.technician_id) if j.technician_id else None,
        "price_cents": j.price_cents,
        "is_paid": j.is_paid,
        "notes": j.notes,
        "next_due_on": j.next_due_on.isoformat() if j.next_due_on else None,
    }


# ── Acotar a la empresa ──────────────────────────────────────
async def _propia(session: AsyncSession, model: Any, row_id: UUID, tenant_id: UUID) -> Any:
    """Busca una fila por id SOLO si es de esta empresa. Evita pisar datos ajenos."""
    rows = await session.execute(
        select(model).where(model.id == row_id, model.tenant_id == tenant_id)
    )
    return rows.scalars().first()


async def _de_otra_empresa(
    session: AsyncSession, model: Any, row_id: UUID, tenant_id: UUID
) -> bool:
    """¿Ese id ya existe, pero es de otra empresa?

    Sin esta comprobación el código lo trataría como fila nueva, intentaría insertarlo y
    chocaría contra la llave primaria: un error 500 en vez de un rechazo claro.
    """
    rows = await session.execute(
        select(model.id).where(model.id == row_id, model.tenant_id != tenant_id)
    )
    return rows.first() is not None


async def _recomendador(
    session: AsyncSession, data: dict[str, Any], tenant_id: UUID
) -> UUID | None:
    """Valida a quién recomendó: tiene que ser cliente de esta empresa.

    Sin esta comprobación, un id ajeno quedaría guardado como referencia y la lista de
    "quién te trae clientes" apuntaría a alguien de otra cartera.
    """
    crudo = data.get("referred_by_id")
    if not crudo:
        return None
    quien = await _propia(session, Client, UUID(str(crudo)), tenant_id)
    return quien.id if quien is not None else None


async def _tecnico(session: AsyncSession, crudo: Any, tenant_id: UUID) -> UUID | None:
    """Valida al técnico asignado: tiene que ser usuario de ESTA empresa.

    Sin esto, un id ajeno dejaría la visita asignada a alguien de otro negocio y el
    técnico de verdad nunca la vería en su agenda.
    """
    if not crudo:
        return None
    quien = await _propia(session, User, UUID(str(crudo)), tenant_id)
    return quien.id if quien is not None else None


# ── PUSH ─────────────────────────────────────────────────────
async def push(session: AsyncSession, tenant_id: UUID, payload: PushRequest) -> PushResponse:
    results: list[ChangeResult] = []
    for change in payload.changes:
        if change.entity == "client":
            results.append(await _push_client(session, tenant_id, change))
        elif change.entity == "service_job":
            results.append(await _push_job(session, tenant_id, change))
        else:
            results.append(ChangeResult(id=change.id, entity=change.entity, status="unsupported"))
    return PushResponse(results=results)


async def _push_client(session: AsyncSession, tenant_id: UUID, ch: Change) -> ChangeResult:
    data = ch.data or {}
    if await _de_otra_empresa(session, Client, ch.id, tenant_id):
        return ChangeResult(id=ch.id, entity="client", status="rejected")

    actual = await _propia(session, Client, ch.id, tenant_id)
    if actual is None:
        session.add(
            Client(
                id=ch.id,
                tenant_id=tenant_id,
                name=data.get("name", ""),
                phone=data.get("phone"),
                address=data.get("address"),
                directions=data.get("directions"),
                notes=data.get("notes"),
                # Solo se acepta si quien recomendó ya existe en ESTA empresa.
                referred_by_id=await _recomendador(session, data, tenant_id),
                is_deleted=(ch.op == "delete"),
                version=ch.version,
                updated_at=ch.updated_at,
            )
        )
        await session.flush()
        return ChangeResult(id=ch.id, entity="client", status="applied", server_version=ch.version)

    if ch.updated_at < actual.updated_at:
        return ChangeResult(
            id=ch.id, entity="client", status="conflict", server_version=actual.version
        )

    for campo in ("name", "phone", "address", "directions", "notes"):
        if campo in data:
            setattr(actual, campo, data[campo])
    if "referred_by_id" in data:
        actual.referred_by_id = await _recomendador(session, data, tenant_id)
    actual.is_deleted = ch.op == "delete"
    actual.version = ch.version
    actual.updated_at = ch.updated_at
    await session.flush()
    return ChangeResult(id=ch.id, entity="client", status="applied", server_version=actual.version)


async def _push_job(session: AsyncSession, tenant_id: UUID, ch: Change) -> ChangeResult:
    data = ch.data or {}
    if await _de_otra_empresa(session, ServiceJob, ch.id, tenant_id):
        return ChangeResult(id=ch.id, entity="service_job", status="rejected")

    actual = await _propia(session, ServiceJob, ch.id, tenant_id)
    if actual is None:
        # El cliente al que se cuelga el servicio también tiene que ser de esta empresa:
        # si no, se estaría metiendo trabajo en la cartera de alguien más.
        cliente = await _propia(session, Client, UUID(str(data["client_id"])), tenant_id)
        if cliente is None:
            return ChangeResult(id=ch.id, entity="service_job", status="rejected")
        session.add(
            ServiceJob(
                id=ch.id,
                tenant_id=tenant_id,
                client_id=cliente.id,
                service_type=data.get("service_type", "tinacos"),
                status=data.get("status", "agendado"),
                scheduled_for=_momento(data.get("scheduled_for")),
                performed_on=_fecha(data.get("performed_on")),
                technician_id=await _tecnico(session, data.get("technician_id"), tenant_id),
                price_cents=data.get("price_cents", 0),
                is_paid=data.get("is_paid", False),
                notes=data.get("notes"),
                next_due_on=_fecha(data.get("next_due_on")),
                is_deleted=(ch.op == "delete"),
                version=ch.version,
                updated_at=ch.updated_at,
            )
        )
        await session.flush()
        return ChangeResult(
            id=ch.id, entity="service_job", status="applied", server_version=ch.version
        )

    if ch.updated_at < actual.updated_at:
        return ChangeResult(
            id=ch.id, entity="service_job", status="conflict", server_version=actual.version
        )

    for campo in ("service_type", "status", "price_cents", "is_paid", "notes"):
        if campo in data:
            setattr(actual, campo, data[campo])
    if "scheduled_for" in data:
        actual.scheduled_for = _momento(data["scheduled_for"])
    if "performed_on" in data:
        actual.performed_on = _fecha(data["performed_on"])
    if "next_due_on" in data:
        actual.next_due_on = _fecha(data["next_due_on"])
    if "technician_id" in data:
        actual.technician_id = await _tecnico(session, data["technician_id"], tenant_id)
    actual.is_deleted = ch.op == "delete"
    actual.version = ch.version
    actual.updated_at = ch.updated_at
    await session.flush()
    return ChangeResult(
        id=ch.id, entity="service_job", status="applied", server_version=actual.version
    )


# ── PULL ─────────────────────────────────────────────────────
async def pull(session: AsyncSession, tenant_id: UUID, since: str | None) -> PullResponse:
    since_dt = datetime.fromisoformat(since) if since else None
    changes: list[Change] = []
    changes += await _pull(session, "client", Client, _client_data, since_dt, tenant_id)
    changes += await _pull(session, "service_job", ServiceJob, _job_data, since_dt, tenant_id)
    changes += await _pull(session, "user", User, _user_data, since_dt, tenant_id)
    return PullResponse(changes=changes, cursor=datetime.now(UTC).isoformat())


async def _pull(
    session: AsyncSession,
    nombre: str,
    model: Any,
    data_fn: Any,
    since_dt: datetime | None,
    tenant_id: UUID,
) -> list[Change]:
    query = select(model).where(model.tenant_id == tenant_id)
    if since_dt is not None:
        query = query.where(model.updated_at > since_dt)
    rows = (await session.execute(query)).scalars().all()
    return [
        Change(
            entity=nombre,
            id=row.id,
            op="delete" if row.is_deleted else "upsert",
            version=row.version,
            updated_at=row.updated_at,
            data=data_fn(row),
        )
        for row in rows
    ]
