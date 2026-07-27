"""GUARDIÁN: aislamiento entre empresas por Row-Level Security.

Si estos tests fallan, el multi-tenant está roto. No desplegar. Ver docs/11_Pruebas.md.
"""

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.db.rls import set_tenant
from app.modules.auth import service
from app.modules.users.models import User


async def _register(sm: async_sessionmaker, name: str, slug: str, email: str):
    async with sm() as session:
        return await service.register(
            session, company_name=name, company_slug=slug, email=email, password="password123"
        )


async def test_tenant_solo_ve_sus_usuarios(app_sessions: async_sessionmaker) -> None:
    tenant_a, user_a = await _register(app_sessions, "Empresa A", "empresa-a", "a@a.com")
    tenant_b, user_b = await _register(app_sessions, "Empresa B", "empresa-b", "b@b.com")

    # Con el tenant A fijado, RLS solo debe dejar ver al usuario de A.
    async with app_sessions() as session, session.begin():
        await set_tenant(session, tenant_a.id)
        ids = set((await session.execute(select(User.id))).scalars().all())
    assert ids == {user_a.id}
    assert user_b.id not in ids

    # Con el tenant B fijado, solo el usuario de B.
    async with app_sessions() as session, session.begin():
        await set_tenant(session, tenant_b.id)
        ids = set((await session.execute(select(User.id))).scalars().all())
    assert ids == {user_b.id}


async def test_sin_tenant_no_ve_nada(app_sessions: async_sessionmaker) -> None:
    await _register(app_sessions, "Empresa A", "empresa-a", "a@a.com")

    # Sin fijar app.current_tenant, la política no coincide con ninguna fila.
    async with app_sessions() as session, session.begin():
        total = await session.scalar(select(func.count()).select_from(User))
    assert total == 0


async def test_no_se_puede_escribir_en_otro_tenant(app_sessions: async_sessionmaker) -> None:
    tenant_a, _ = await _register(app_sessions, "Empresa A", "empresa-a", "a@a.com")
    tenant_b, _ = await _register(app_sessions, "Empresa B", "empresa-b", "b@b.com")

    # Con el tenant A fijado, insertar una fila con tenant_id de B debe ser rechazado
    # por la cláusula WITH CHECK de la política RLS.
    from sqlalchemy.exc import ProgrammingError

    from app.core.security import hash_password

    raised = False
    async with app_sessions() as session:
        try:
            async with session.begin():
                await set_tenant(session, tenant_a.id)
                session.add(
                    User(
                        tenant_id=tenant_b.id,
                        email="intruso@b.com",
                        password_hash=hash_password("password123"),
                        role="operator",
                    )
                )
        except ProgrammingError:
            raised = True
    assert raised, "RLS debería haber impedido escribir en otro tenant"
