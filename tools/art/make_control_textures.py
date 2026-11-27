#!/usr/bin/env python3
"""Genera las texturas pixel art (placeholder) de los controles táctiles.

Estilo "Materiales": placa de hierro roja (ATACAR), gema facetada morada
(PIEDRA), disco de madera con surco cosido (base del stick) y perilla clara.
Se dibujan a escala de pixel del mundo (1 px = 3 unidades de UI) y el juego
las estira con filtro "nearest".

Uso:  python3 tools/art/make_control_textures.py
Necesita Pillow (pip install pillow). Es determinista.
"""
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "ui" / "controls"

RED = (199, 41, 41)
PURPLE = (107, 89, 204)
WOOD = (205, 170, 128)
KNOB = (236, 212, 178)
RIM = (56, 38, 23)  # marrón muy oscuro: separa el stick del piso café


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def edge(f, x, y):
    """Pixel de la forma con algún vecino (4 dir.) fuera de ella."""
    return f(x, y) and not all(f(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))


def render(w, h, inside, painter):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            if inside(x, y):
                px[x, y] = painter(x, y) + (255,)
    return img


def darken_press(c, pressed):
    return shade(c, 0.85) if pressed else c


def attack(pressed):
    n = 30
    inside = lambda x, y: 0 <= x < n and 0 <= y < n
    rivets = {(4, 4), (n - 5, 4), (4, n - 5), (n - 5, n - 5)}

    def paint(x, y):
        if edge(inside, x, y):
            return shade(RED, 0.3)
        base = shade(RED, 0.9 + 0.15 * ((x + y) % 5 == 0))  # líneas diagonales de cepillado
        if x in (1, 2) or y in (1, 2):  # bisel arriba-izquierda
            tl = True
        else:
            tl = False
        br = x in (n - 3, n - 2) or y in (n - 3, n - 2)
        if tl and not br:
            base = shade(RED, 0.65) if pressed else shade(RED, 1.3)
        elif br and not tl:
            base = shade(RED, 1.25) if pressed else shade(RED, 0.7)
        if (x, y) in rivets:
            base = (200, 200, 210)
        elif (x - 1, y - 1) in rivets:
            base = shade(RED, 0.45)
        return darken_press(base, pressed)

    return render(n, n, inside, paint)


def stone(pressed):
    w, h = 32, 16

    def inside(x, y):
        if not (0 <= x < w and 0 <= y < h):
            return False
        dx = (x + 0.5 - w / 2) / (w / 2)
        dy = (y + 0.5 - h) / h
        return dx * dx + dy * dy <= 1.0

    def paint(x, y):
        if edge(inside, x, y) or y == h - 1:
            return shade(PURPLE, 0.3)
        fac = int(((x - w / 2) * 0.9 + (h - y) * 1.6) // 4) % 3  # 3 facetas en bandas diagonales
        c = shade(PURPLE, (0.8, 1.0, 1.3)[fac])
        if not inside(x - 1, y - 1):  # filo claro arriba-izquierda
            c = shade(PURPLE, 0.7) if pressed else shade(PURPLE, 1.45)
        if (x, y) in {(8, 4), (7, 4), (9, 4), (8, 3), (8, 5)}:
            c = (240, 232, 255)
        return darken_press(c, pressed)

    return render(w, h, inside, paint)


def stick_base():
    n, r = 64, 32.0

    def dist(x, y):
        return math.hypot(x + 0.5 - n / 2, y + 0.5 - n / 2)

    inside = lambda x, y: dist(x, y) <= r

    def paint(x, y):
        d = dist(x, y)
        if edge(inside, x, y):
            return shade(RIM, 0.55)
        if d > r - 3:  # aro oscuro de 2 px
            return RIM
        # Anillos de veta suaves; casi lisos en el centro para que se lean las flechas.
        amp = 0.03 + 0.06 * min(1.0, max(0.0, (d - 12) / 14))
        c = shade(WOOD, 0.96 + amp * math.sin(d * 1.3))
        if d > r - 4:
            c = shade(WOOD, 0.8)  # sombra interior bajo el aro
        if abs(d - (r - 7.5)) < 0.7 and int(math.atan2(y - n / 2, x - n / 2) * 10) % 2 == 0:
            c = shade(WOOD, 0.5)  # surco punteado "cosido"
        return c

    return render(n, n, inside, paint)


def stick_knob():
    n, r = 28, 14.0

    def dist(x, y):
        return math.hypot(x + 0.5 - n / 2, y + 0.5 - n / 2)

    inside = lambda x, y: dist(x, y) <= r

    def paint(x, y):
        if edge(inside, x, y):
            return shade(KNOB, 0.4)
        d = dist(x, y)
        c = KNOB
        if (x - n / 2) + (y - n / 2) < -5:
            c = shade(KNOB, 1.08)
        elif d > r - 3.5:
            c = shade(KNOB, 0.85)
        if (x - 9) ** 2 + (y - 9) ** 2 <= 3.5:
            c = (255, 250, 240)
        return c

    return render(n, n, inside, paint)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    files = {
        "attack.png": attack(False),
        "attack_pressed.png": attack(True),
        "stone.png": stone(False),
        "stone_pressed.png": stone(True),
        "stick_base.png": stick_base(),
        "stick_knob.png": stick_knob(),
    }
    for name, img in files.items():
        img.save(OUT / name)
        print("escrito", OUT / name)


if __name__ == "__main__":
    main()
