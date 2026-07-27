"""Generación de identificadores UUIDv7.

UUIDv7 (RFC 9562): 48 bits de timestamp en milisegundos + versión/variante + azar.
Es ordenable en el tiempo y generable en el cliente sin coordinación — requisito del
modelo offline-first para crear registros sin conexión sin colisiones (ver ADR-003).

Se implementa aquí para no depender de la versión de stdlib ni de paquetes externos.
"""

import os
import time
from uuid import UUID


def uuid7() -> UUID:
    """Devuelve un UUID versión 7 (ordenable por tiempo)."""
    unix_ms = int(time.time() * 1000)
    # 6 bytes de timestamp (48 bits) + 10 bytes de aleatoriedad (80 bits) = 16 bytes
    raw = bytearray(unix_ms.to_bytes(6, "big") + os.urandom(10))
    # Versión 7 en el nibble alto del byte 6
    raw[6] = (raw[6] & 0x0F) | 0x70
    # Variante RFC 4122 en los dos bits altos del byte 8
    raw[8] = (raw[8] & 0x3F) | 0x80
    return UUID(bytes=bytes(raw))
