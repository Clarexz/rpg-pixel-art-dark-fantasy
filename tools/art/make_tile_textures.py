#!/usr/bin/env python3
"""Genera las texturas pixel art (placeholder) del kit de construcción de zonas.

Cada textura es de 32x32 px y se repite sin cortes (tileable). En el juego se
pegan con "triplanar en coordenadas del mundo": 32 px cubren 2 m (un bloque),
así que las paredes y pisos de bloques vecinos se ven continuos.

Son de relleno: se pueden reemplazar con arte propio (p. ej. Aseprite)
mientras se respete el tamaño de 32x32 y que se repitan sin cortes.

Uso:  python3 tools/art/make_tile_textures.py
Necesita Pillow (pip install pillow).
"""
import random
from pathlib import Path

from PIL import Image

S = 32
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "tiles"


def hexc(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def noise_fill(img, rng, palette, weights):
    px = img.load()
    for y in range(S):
        for x in range(S):
            px[x, y] = hexc(rng.choices(palette, weights)[0])


def speckles(img, rng, color, count, size=1):
    px = img.load()
    for _ in range(count):
        x, y = rng.randrange(S), rng.randrange(S)
        for dy in range(size):
            for dx in range(size):
                px[(x + dx) % S, (y + dy) % S] = hexc(color)


def ceniza(rng):
    """Suelo de ceniza: gris tibio con grumos claros y oscuros."""
    img = Image.new("RGBA", (S, S))
    noise_fill(img, rng, ["#3b3734", "#423d39", "#35312e", "#4a4440"], [5, 4, 3, 1])
    speckles(img, rng, "#5c554f", 40)
    speckles(img, rng, "#2a2725", 30)
    speckles(img, rng, "#6e655d", 6, 2)
    return img


def escoria(rng):
    """Suelo de escoria: casi negro, con chispas naranjas de brasa."""
    img = Image.new("RGBA", (S, S))
    noise_fill(img, rng, ["#24201f", "#2b2624", "#1d1a19", "#332c29"], [5, 4, 3, 2])
    speckles(img, rng, "#3d3431", 30, 2)
    speckles(img, rng, "#b5501f", 10)
    speckles(img, rng, "#e07a2c", 4)
    return img


def camino(rng):
    """Camino empedrado: piedras grises con juntas oscuras."""
    img = Image.new("RGBA", (S, S), hexc("#1f1d1c"))
    px = img.load()
    rows = [(0, 8), (8, 16), (16, 24), (24, 32)]
    for r, (y0, y1) in enumerate(rows):
        shift = 0 if r % 2 == 0 else 5
        x = shift
        while x < S + shift:
            w = rng.choice([7, 8, 9])
            base = rng.choice(["#5a5651", "#625d57", "#545049", "#69635c"])
            for yy in range(y0 + 1, y1):
                for xx in range(x + 1, x + w):
                    c = hexc(base)
                    if rng.random() < 0.15:
                        c = hexc("#4b4743")
                    if yy == y0 + 1 or xx == x + 1:
                        c = hexc("#77716a")
                    px[xx % S, yy] = c
            x += w
    return img


def roca(rng):
    """Pared de roca: vetas horizontales en tonos fríos."""
    img = Image.new("RGBA", (S, S))
    px = img.load()
    bands = ["#3a3a40", "#44434a", "#34343a", "#4c4a52"]
    for y in range(S):
        band = bands[(y // 4 + (1 if y % 9 == 0 else 0)) % len(bands)]
        for x in range(S):
            c = band
            r = rng.random()
            if r < 0.12:
                c = "#2a2a2f"
            elif r < 0.2:
                c = "#57555e"
            px[x, y] = hexc(c)
    for _ in range(5):  # grietas
        x, y = rng.randrange(S), rng.randrange(S)
        for _ in range(rng.randrange(3, 8)):
            px[x % S, y % S] = hexc("#1e1e22")
            x += rng.choice([-1, 0, 1])
            y += 1
    return img


def ladrillo(rng):
    """Ladrillo viejo de las ruinas: rojizo apagado, algunos rotos."""
    img = Image.new("RGBA", (S, S), hexc("#2b2321"))
    px = img.load()
    for r in range(4):
        y0 = r * 8
        shift = 0 if r % 2 == 0 else 8
        for b in range(2):
            x0 = shift + b * 16
            base = rng.choice(["#6b4a3f", "#5e4138", "#74513f", "#58403a"])
            broken = rng.random() < 0.25
            for yy in range(y0 + 1, y0 + 8):
                for xx in range(x0 + 1, x0 + 16):
                    c = base
                    if broken and xx - x0 > 10 and yy - y0 < 4:
                        c = "#2b2321"
                    elif rng.random() < 0.12:
                        c = "#4a3530"
                    elif yy == y0 + 1:
                        c = "#80604f"
                    px[xx % S, yy] = hexc(c)
    return img


def madera(rng):
    """Tablas de madera quemada (carretas, cajas)."""
    img = Image.new("RGBA", (S, S))
    px = img.load()
    for p in range(4):
        x0 = p * 8
        base = rng.choice(["#4a3526", "#523b2a", "#45311f"])
        for y in range(S):
            for x in range(x0, x0 + 8):
                c = base
                if x == x0:
                    c = "#21170f"
                elif rng.random() < 0.18:
                    c = "#3a2819"
                elif (y + p * 5) % 11 == 0:
                    c = "#2c1f14"
                px[x, y] = hexc(c)
        px[x0 + 4, (p * 7 + 3) % S] = hexc("#8a8a8a")  # clavo
    return img


TILES = {
    "ceniza": ceniza,
    "escoria": escoria,
    "camino": camino,
    "roca": roca,
    "ladrillo": ladrillo,
    "madera": madera,
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for i, (name, fn) in enumerate(TILES.items()):
        img = fn(random.Random(100 + i))
        img.save(OUT / f"{name}.png")
        print("ok", name)


if __name__ == "__main__":
    main()
