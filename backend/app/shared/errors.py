"""Errores de API con formato uniforme { "error": { code, message } } (ver docs/05_API.md)."""

from fastapi import HTTPException


def api_error(status_code: int, code: str, message: str) -> HTTPException:
    """Crea una HTTPException cuyo `detail` lleva code + message estructurados."""
    return HTTPException(status_code=status_code, detail={"code": code, "message": message})
