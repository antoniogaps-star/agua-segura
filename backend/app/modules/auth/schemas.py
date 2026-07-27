"""Contratos (Pydantic) del módulo de autenticación."""

from typing import Annotated

from pydantic import BaseModel, EmailStr, Field

Slug = Annotated[str, Field(min_length=2, max_length=100, pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")]
Password = Annotated[str, Field(min_length=8, max_length=128)]


class RegisterRequest(BaseModel):
    company_name: Annotated[str, Field(min_length=2, max_length=200)]
    company_slug: Slug
    email: EmailStr
    password: Password


class LoginRequest(BaseModel):
    company_slug: Slug
    email: EmailStr
    # Al ENTRAR no se valida la longitud de la contraseña: esa regla es del registro.
    # Así un password corto (un typo) cae en 401 "Credenciales inválidas" —el mensaje
    # correcto— en vez de un 422 que en la pantalla verde se traduce a un aviso sobre
    # el nombre de empresa/correo que ahí ni siquiera se muestran.
    password: Annotated[str, Field(min_length=1, max_length=128)]


class ResetPasswordRequest(BaseModel):
    company_slug: Slug
    email: EmailStr
    new_password: Password
    # El secreto de administrador se acepta en el CUERPO (JSON admite cualquier carácter:
    # acentos, ñ, emojis…). Un header HTTP no los admite y rompía la petición en el cliente.
    # Se mantiene además el header X-Admin-Secret como respaldo para apps antiguas.
    admin_secret: str | None = None


class AdminBootstrapRequest(BaseModel):
    secret: Annotated[str, Field(min_length=6, max_length=128)]


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
