#!/usr/bin/env bash
# Respaldo de la base de datos de Ágora ERP (Postgres / Neon).
#
# Genera un volcado en formato "custom" (comprimido, ideal para restaurar de forma
# selectiva) con marca de tiempo. Pensado para correr a mano o desde una tarea
# programada (cron / GitHub Actions). No depende de la app: solo necesita `pg_dump`.
#
# Uso:
#   DATABASE_URL="postgres://user:pass@host/db?sslmode=require" ./backup_db.sh [DESTINO]
#   ./backup_db.sh "postgres://user:pass@host/db?sslmode=require"   # URL como argumento
#
# Restaurar un volcado:
#   pg_restore --clean --if-exists --no-owner -d "$DATABASE_URL" backups/agora_XXXX.dump
set -euo pipefail

# 1) Resolver la URL: argumento posicional o variable de entorno.
URL="${1:-${DATABASE_URL:-}}"
if [[ -z "$URL" ]]; then
  echo "ERROR: falta la URL. Pásala como argumento o exporta DATABASE_URL." >&2
  exit 1
fi

# 2) Normalizar a una URL libpq que pg_dump entienda:
#    - el driver async de la app usa 'postgresql+asyncpg://'; pg_dump quiere 'postgresql://'.
#    - 'ssl=' (forma asyncpg) se traduce de vuelta a 'sslmode=' (forma libpq).
URL="${URL/postgresql+asyncpg:\/\//postgresql://}"
URL="${URL/postgres+asyncpg:\/\//postgres://}"
URL="${URL//\?ssl=/\?sslmode=}"
URL="${URL//&ssl=/&sslmode=}"

# 3) Carpeta de salida (por defecto ./backups junto al script) y nombre con fecha UTC.
DEST="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/backups}"
mkdir -p "$DEST"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
OUT="$DEST/agora_${STAMP}.dump"

# 4) Volcado en formato custom (-Fc): comprimido y restaurable selectivamente.
echo "Respaldando -> $OUT"
pg_dump --format=custom --no-owner --no-privileges --file="$OUT" "$URL"

# 5) Retención simple: conserva los 14 respaldos más recientes.
ls -1t "$DEST"/agora_*.dump 2>/dev/null | tail -n +15 | xargs -r rm -f

SIZE="$(du -h "$OUT" | cut -f1)"
echo "Listo: $OUT ($SIZE). Conservados los 14 más recientes en $DEST."
