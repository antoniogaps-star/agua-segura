"""Pruebas unitarias de seguridad (no requieren base de datos)."""

from uuid import uuid4

import pytest

from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)


def test_password_hash_roundtrip() -> None:
    h = hash_password("s3creta-larga")
    assert h != "s3creta-larga"  # no se guarda en claro
    assert verify_password(h, "s3creta-larga") is True
    assert verify_password(h, "incorrecta") is False


def test_access_token_carries_tenant_and_role() -> None:
    user_id, tenant_id = uuid4(), uuid4()
    token = create_access_token(user_id=user_id, tenant_id=tenant_id, role="owner")
    claims = decode_token(token)
    assert claims["sub"] == str(user_id)
    assert claims["tenant_id"] == str(tenant_id)
    assert claims["role"] == "owner"
    assert claims["type"] == "access"


def test_refresh_token_type() -> None:
    token = create_refresh_token(user_id=uuid4(), tenant_id=uuid4(), role="admin")
    assert decode_token(token)["type"] == "refresh"


def test_tampered_token_rejected() -> None:
    import jwt

    token = create_access_token(user_id=uuid4(), tenant_id=uuid4(), role="viewer")
    with pytest.raises(jwt.PyJWTError):
        decode_token(token + "x")
