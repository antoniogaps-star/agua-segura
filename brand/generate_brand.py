"""Genera la marca de Agua Segura a partir del logo que entregó el diseñador.

Dos piezas distintas, y a propósito:

1. **El logo completo** (`logo_full.png`) se recorta del original: la insignia con su
   salpicadura. Va donde hay espacio — splash, landing, encabezado del panel.

2. **El ícono de la app** se DIBUJA aquí, simplificado: solo el tinaco y la gota. El logo
   real trae "LAVADO / TINACOS / DESINFECCIÓN" en tres renglones, y a 48 px —que es como
   se ve el ícono en el celular— eso es una mancha ilegible. Un ícono necesita silueta,
   no texto.

Ejecutar:  python brand/generate_brand.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

AQUI = Path(__file__).parent

# ── Paleta, muestreada del logo original ────────────────────
MARINO = (1, 24, 41)        # #011829 — el fondo de la insignia
MARINO_CLARO = (10, 45, 78)  # para el degradado del splash
AZUL = (28, 116, 217)       # el azul de "Agua Segura"
AZUL_CLARO = (94, 178, 255)
BLANCO = (245, 250, 253)
PLATA = (200, 212, 224)
DORADO = (247, 203, 37)     # #F7CB25 — el de "TINACOS"


def _tinaco(draw: ImageDraw.ImageDraw, cx: float, cy: float, alto: float) -> None:
    """Dibuja el tinaco: cilindro con tapa y sus costillas horizontales.

    Se dibuja plano y macizo (sin degradados ni brillos): es lo que sobrevive cuando el
    sistema encoge el ícono a 48 px.
    """
    # Un tinaco es MÁS ANCHO QUE ALTO. Con proporción vertical parece libreta.
    ancho = alto * 1.18
    x0, x1 = cx - ancho / 2, cx + ancho / 2
    y0, y1 = cy - alto / 2, cy + alto / 2

    # Cuerpo: esquinas de abajo más redondeadas, como la base curva del tinaco.
    draw.rounded_rectangle(
        [x0, y0, x1, y1],
        radius=ancho * 0.16,
        fill=BLANCO,
        corners=(True, True, True, True),
    )

    # Tapa: angosta y bien marcada, la seña más clara de que es un tinaco.
    tapa_ancho = ancho * 0.30
    tapa_alto = alto * 0.22
    draw.rounded_rectangle(
        [cx - tapa_ancho / 2, y0 - tapa_alto * 0.80, cx + tapa_ancho / 2, y0 + tapa_alto * 0.20],
        radius=tapa_alto * 0.30,
        fill=BLANCO,
    )

    # Costillas: lo que termina de decir "tinaco" y no "bote".
    grosor = max(2.0, alto * 0.075)
    for frac in (0.30, 0.55, 0.80):
        y = y0 + alto * frac
        draw.rounded_rectangle(
            [x0 + ancho * 0.06, y - grosor / 2, x1 - ancho * 0.06, y + grosor / 2],
            radius=grosor / 2,
            fill=PLATA,
        )


def _gota(draw: ImageDraw.ImageDraw, cx: float, cy: float, alto: float) -> None:
    """La gota de agua: punta arriba, panza abajo."""
    ancho = alto * 0.78
    # La panza.
    draw.ellipse(
        [cx - ancho / 2, cy - alto * 0.10, cx + ancho / 2, cy - alto * 0.10 + ancho],
        fill=AZUL_CLARO,
    )
    # La punta.
    draw.polygon(
        [
            (cx, cy - alto * 0.55),
            (cx - ancho * 0.46, cy + alto * 0.16),
            (cx + ancho * 0.46, cy + alto * 0.16),
        ],
        fill=AZUL_CLARO,
    )


def hacer_icono(lado: int = 512, con_fondo: bool = True) -> Image.Image:
    """El ícono de la app: tinaco + gota. Sin texto, para que se lea en chiquito."""
    img = Image.new("RGBA", (lado, lado), MARINO + (255,) if con_fondo else (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Sin fondo (ícono adaptativo de Android) el dibujo va más chico: el sistema recorta
    # los bordes con formas distintas según el teléfono.
    escala = 1.0 if con_fondo else 0.72
    u = lado / 512

    _tinaco(draw, lado / 2, lado * 0.44, 250 * u * escala)
    _gota(draw, lado / 2, lado * 0.80, 96 * u * escala)
    return img


def _degradado(ancho: int, alto: int) -> Image.Image:
    """Fondo marino con un degradado suave, como el del logo original."""
    fondo = Image.new("RGB", (ancho, alto), MARINO)
    draw = ImageDraw.Draw(fondo)
    for y in range(alto):
        t = abs(y - alto * 0.42) / alto
        c = tuple(
            int(MARINO_CLARO[i] + (MARINO[i] - MARINO_CLARO[i]) * min(1.0, t * 2.0))
            for i in range(3)
        )
        draw.line([(0, y), (ancho, y)], fill=c)
    return fondo


def hacer_splash(ancho: int = 1242, alto: int = 2208) -> Image.Image:
    """Pantalla de bienvenida: la insignia real sobre el marino de la marca."""
    fondo = _degradado(ancho, alto)
    insignia = Image.open(AQUI / "logo_full.png").convert("RGBA")

    destino = int(ancho * 0.62)
    insignia = insignia.resize((destino, destino), Image.LANCZOS)
    fondo.paste(insignia, ((ancho - destino) // 2, int(alto * 0.30) - destino // 2), insignia)

    draw = ImageDraw.Draw(fondo)
    # El nombre y el eslogan se dejan como texto del sistema: se ven nítidos en cualquier
    # pantalla y no dependen de una fuente que haya que empaquetar.
    from PIL import ImageFont

    def fuente(tam: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
        for nombre in ("arialbd.ttf", "segoeuib.ttf", "calibrib.ttf"):
            try:
                return ImageFont.truetype(nombre, tam)
            except OSError:
                continue
        return ImageFont.load_default()

    def centrado(texto: str, y: int, f, color) -> None:
        caja = draw.textbbox((0, 0), texto, font=f)
        draw.text(((ancho - (caja[2] - caja[0])) / 2, y), texto, font=f, fill=color)

    centrado("Agua Segura", int(alto * 0.53), fuente(int(ancho * 0.115)), BLANCO)
    centrado(
        "HOGAR PROTEGIDO, AGUA SEGURA",
        int(alto * 0.605),
        fuente(int(ancho * 0.028)),
        AZUL_CLARO,
    )
    return fondo


def main() -> None:
    salida = AQUI

    hacer_icono(512, con_fondo=True).save(salida / "icon.png")
    hacer_icono(512, con_fondo=False).save(salida / "icon_foreground.png")
    for tam in (192, 512):
        hacer_icono(tam, con_fondo=True).save(salida / f"icon-{tam}.png")

    hacer_splash().save(salida / "splash.png")

    print(f"Marca generada en {salida}")


if __name__ == "__main__":
    main()
