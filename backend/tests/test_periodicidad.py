"""El cálculo de la próxima fecha: el corazón de "¿a quién le toca?".

No necesita base de datos. Si esto se equivoca, se le avisa tarde al cliente y se pierde
el trabajo — que es justo el problema que la app viene a resolver.
"""

from datetime import date

from app.modules.services.service import siguiente_fecha


def test_tinacos_son_seis_meses() -> None:
    assert siguiente_fecha("tinacos", date(2026, 1, 15)) == date(2026, 7, 15)


def test_calentadores_y_techos_son_un_anio() -> None:
    assert siguiente_fecha("calentadores", date(2026, 3, 10)) == date(2027, 3, 10)
    assert siguiente_fecha("techos", date(2026, 3, 10)) == date(2027, 3, 10)


def test_impermeabilizacion_son_dos_anios() -> None:
    assert siguiente_fecha("impermeabilizacion", date(2026, 5, 1)) == date(2028, 5, 1)


def test_cruza_el_fin_de_anio() -> None:
    """Un lavado de octubre cae en abril del año siguiente, no en el mismo año."""
    assert siguiente_fecha("tinacos", date(2026, 10, 20)) == date(2027, 4, 20)


def test_no_inventa_un_dia_que_no_existe() -> None:
    """31 de agosto + 6 meses = 28 de febrero, no un "31 de febrero" imposible."""
    assert siguiente_fecha("tinacos", date(2026, 8, 31)) == date(2027, 2, 28)


def test_anio_bisiesto() -> None:
    assert siguiente_fecha("tinacos", date(2027, 8, 31)) == date(2028, 2, 29)


def test_plomeria_no_se_reprograma_sola() -> None:
    """La plomería es correctiva: nadie llama para que le arreglen una fuga que no tiene."""
    assert siguiente_fecha("plomeria", date(2026, 1, 15)) is None
