"""Primitivas de seguridad: hashing de contraseñas (Argon2) y JWT.

Ver docs/09_Seguridad.md y ADR-004. Ningún otro módulo debe implementar hashing o
firmar tokens: todo pasa por aquí.
"""

import hashlib
from datetime import UTC, datetime, timedelta
from typing import Any, Literal
from uuid import UUID, uuid4

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError

from app.core.config import settings

_hasher = PasswordHasher()

TokenType = Literal["access", "refresh"]


# ── Contraseñas ──────────────────────────────────────────────
def hash_password(plain: str) -> str:
    return _hasher.hash(plain)


def verify_password(password_hash: str, plain: str) -> bool:
    try:
        return _hasher.verify(password_hash, plain)
    except VerifyMismatchError:
        return False


# ── JWT ──────────────────────────────────────────────────────
def _create_token(
    *, user_id: UUID, tenant_id: UUID, role: str, token_type: TokenType, ttl: timedelta
) -> str:
    now = datetime.now(UTC)
    payload = {
        "sub": str(user_id),
        "tenant_id": str(tenant_id),
        "role": role,
        "type": token_type,
        "jti": uuid4().hex,  # único: evita colisiones de hash entre tokens del mismo segundo
        "iat": now,
        "exp": now + ttl,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_access_token(*, user_id: UUID, tenant_id: UUID, role: str) -> str:
    return _create_token(
        user_id=user_id,
        tenant_id=tenant_id,
        role=role,
        token_type="access",
        ttl=timedelta(minutes=settings.access_token_ttl_minutes),
    )


def create_refresh_token(*, user_id: UUID, tenant_id: UUID, role: str) -> str:
    return _create_token(
        user_id=user_id,
        tenant_id=tenant_id,
        role=role,
        token_type="refresh",
        ttl=timedelta(days=settings.refresh_token_ttl_days),
    )


def decode_token(token: str) -> dict[str, Any]:
    """Decodifica y valida firma/expiración. Lanza jwt.PyJWTError si es inválido."""
    return jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])


def hash_token(token: str) -> str:
    """SHA-256 del token, para almacenarlo sin guardar el token en claro."""
    return hashlib.sha256(token.encode()).hexdigest()
