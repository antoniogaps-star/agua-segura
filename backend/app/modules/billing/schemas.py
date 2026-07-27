"""Contratos del módulo de facturación/licencias."""

from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, Field


class BillingStatus(BaseModel):
    plan: str
    status: str
    in_trial: bool
    active: bool
    trial_ends_at: datetime
    plan_expires_at: datetime | None
    businesses_allowed: int


class RedeemRequest(BaseModel):
    code: Annotated[str, Field(min_length=4, max_length=40)]


class AdminKeyRequest(BaseModel):
    plan: Literal["pyme", "business", "enterprise"]
    months: Annotated[int, Field(ge=0, le=120)] = 1  # 0 = perpetua
    count: Annotated[int, Field(ge=1, le=100)] = 1
    # Secreto de admin en el cuerpo (JSON acepta cualquier carácter). El header
    # X-Admin-Secret se mantiene como respaldo. Ver auth/schemas.ResetPasswordRequest.
    admin_secret: str | None = None


class AdminKeyResponse(BaseModel):
    codes: list[str]
