# Ágora ERP — Backend

FastAPI + PostgreSQL. API multiempresa con aislamiento por Row-Level Security.

## Requisitos

- Python 3.12+
- PostgreSQL 16+ (o usar `infra/docker-compose.yml`)

## Puesta en marcha (desarrollo)

```bash
# Desde la raíz del repo: levantar Postgres
docker compose -f ../infra/docker-compose.yml up -d

cd backend
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -e ".[dev]"

cp .env.example .env        # y edita JWT_SECRET

# (a partir del hito 3) migraciones y arranque:
# alembic upgrade head
# uvicorn app.main:app --reload
```

## Estructura

```
app/
├── main.py            # creación de la app, routers, middleware
├── core/              # config, seguridad (JWT/Argon2), logging
├── db/                # sesión async, base declarativa, helper RLS
├── middleware/        # extracción de tenant desde el JWT
├── modules/           # módulos de negocio (auth, tenants, users, …)
├── sync/              # endpoints push/pull (esqueleto)
└── shared/            # dependencias comunes, excepciones, paginación
alembic/               # migraciones
tests/                 # incluye tests de aislamiento de tenants
```

## Comandos

```bash
ruff check .           # lint
mypy app               # tipos
pytest                 # tests (requiere Postgres para integración/aislamiento)
```

Ver [`docs/06_Backend.md`](../docs/06_Backend.md) y [`docs/09_Seguridad.md`](../docs/09_Seguridad.md).
