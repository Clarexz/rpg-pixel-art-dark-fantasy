#!/usr/bin/env python3
"""Genera los sprites pixel art (placeholder) de los enemigos de la fase 3.

Cada enemigo es una tira de 6 cuadros de 48x48 (288x48 px):
  0 quieto A, 1 quieto B (respira), 2 preparando golpe, 3 golpeando,
  4 herido, 5 derrotado.
El juego la corta con Sprite3D.hframes = 6 (ver enemies/enemy.gd).

Son de relleno: se pueden reemplazar con arte propio (p. ej. Aseprite)
mientras se respete el tamaño y el orden de los cuadros.

Uso:  python3 tools/art/make_enemy_sprites.py
Necesita Pillow (pip install pillow).
"""
from pathlib import Path

from PIL import Image, ImageDraw

S = 48
FRAMES = ["idle_a", "idle_b", "windup", "strike", "hurt", "down"]
ROOT = Path(__file__).resolve().parents[2]


def hexc(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


class Canvas:
    def __init__(self) -> None:
        self.img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.dx = 0
        self.dy = 0

    def _p(self, pts):
        return [(x + self.dx, y + self.dy) for x, y in pts]

    def rect(self, x0, y0, x1, y1, c):
        self.d.rectangle(self._p([(x0, y0), (x1, y1)]), fill=hexc(c))

    def ell(self, x0, y0, x1, y1, c):
        self.d.ellipse(self._p([(x0, y0), (x1, y1)]), fill=hexc(c))

    def poly(self, pts, c):
        self.d.polygon(self._p(pts), fill=hexc(c))

    def line(self, pts, c, w=1):
        self.d.line(self._p(pts), fill=hexc(c), width=w)

    def px(self, x, y, c):
        x += self.dx
        y += self.dy
        if 0 <= x < S and 0 <= y < S:
            self.img.putpixel((x, y), hexc(c))

    def outline(self, c):
        """Contorno oscuro de 1 px alrededor de todo lo dibujado."""
        src = self.img.copy()
        col = hexc(c)
        for y in range(S):
            for x in range(S):
                if src.getpixel((x, y))[3] > 0:
                    continue
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < S and 0 <= ny < S and src.getpixel((nx, ny))[3] > 0:
                        self.img.putpixel((x, y), col)
                        break

    def shear(self, k):
        """Inclina el cuadro (para el cuadro de herido)."""
        self.img = self.img.transform((S, S), Image.AFFINE, (1, k, -k * S, 0, 1, 0), Image.NEAREST)
        self.d = ImageDraw.Draw(self.img)


# --- Gólem de escoria: lento, pega fuerte, grietas de lava -------------------

G = dict(o="#16121a", d="#35313d", m="#524c5c", l="#77707f", hl="#9a93a3",
         c="#ff7a1f", cb="#ffd060", e="#ffe8a0")


def golem(pose: str) -> Canvas:
    cv = Canvas()
    if pose == "down":
        # Montón de piedras con brasas.
        for (x0, y0, x1, y1) in [(6, 38, 20, 46), (16, 34, 32, 46), (28, 39, 42, 46), (12, 30, 22, 38)]:
            cv.rect(x0, y0, x1, y1, G["m"])
            cv.rect(x0, y0, x1, y0 + 1, G["l"])
            cv.rect(x0, y1 - 1, x1, y1, G["d"])
        cv.line([(18, 40), (24, 37), (30, 41)], G["c"])
        cv.px(24, 37, G["cb"])
        cv.px(17, 33, G["c"])
        cv.outline(G["o"])
        return cv
    bob = 1 if pose == "idle_b" else 0
    lower = {"strike": 3, "windup": -1}.get(pose, 0)
    cv.dy = bob + lower
    # Piernas.
    cv.rect(14, 36, 21, 46 - cv.dy, G["d"])
    cv.rect(27, 36, 34, 46 - cv.dy, G["d"])
    cv.rect(14, 36, 16, 46 - cv.dy, G["m"])
    cv.rect(27, 36, 29, 46 - cv.dy, G["m"])
    # Torso.
    cv.rect(10, 15, 38, 38, G["m"])
    cv.rect(11, 14, 37, 15, G["l"])
    cv.rect(10, 15, 14, 34, G["l"])
    cv.rect(30, 30, 38, 38, G["d"])
    cv.rect(10, 35, 38, 38, G["d"])
    # Grietas de lava.
    hot = G["cb"] if pose == "windup" else G["c"]
    cv.line([(16, 20), (20, 24), (19, 29), (23, 33)], hot)
    cv.line([(31, 18), (28, 23), (31, 27)], hot)
    cv.line([(24, 26), (27, 30)], hot)
    # Cabeza hundida en los hombros.
    cv.rect(19, 8, 29, 17, G["m"])
    cv.rect(19, 8, 29, 9, G["hl"])
    cv.rect(20, 12, 22, 13, G["e"] if pose != "hurt" else G["c"])
    cv.rect(26, 12, 28, 13, G["e"] if pose != "hurt" else G["c"])
    # Brazos (rocas enormes).
    if pose == "windup":
        for x0 in (6, 30):
            cv.rect(x0 + 4, 9, x0 + 9, 16, G["m"])
            cv.rect(x0, 0, x0 + 12, 9, G["m"])
            cv.rect(x0, 0, x0 + 12, 1, G["hl"])
            cv.line([(x0 + 3, 3), (x0 + 7, 6)], G["cb"])
    elif pose == "strike":
        cv.rect(3, 18, 10, 30, G["m"])
        cv.rect(38, 18, 45, 30, G["m"])
        cv.rect(4, 30, 22, 41, G["l"])
        cv.rect(26, 30, 44, 41, G["l"])
        cv.rect(4, 39, 22, 41, G["d"])
        cv.rect(26, 39, 44, 41, G["d"])
        cv.line([(9, 33), (14, 36)], G["c"])
        cv.line([(34, 33), (39, 36)], G["c"])
    else:
        cv.rect(3, 17, 10, 40, G["m"])
        cv.rect(38, 17, 45, 40, G["m"])
        cv.rect(3, 17, 5, 40, G["l"])
        cv.rect(38, 35, 45, 40, G["d"])
        cv.rect(3, 35, 10, 40, G["d"])
        cv.line([(6, 25), (8, 29)], G["c"])
    cv.outline(G["o"])
    if pose == "hurt":
        cv.shear(-0.12)
    return cv


# --- Carroñero: rápido, encorvado, dos dagas de hueso -------------------------

C = dict(o="#120c10", s="#a7b394", sd="#6f7b61", sl="#cdd6bd", r="#5c1820", rm="#7e2830",
         rl="#a0404a", b="#ece2c6", bd="#b5a98a", e="#ff3030")


def scavenger(pose: str) -> Canvas:
    cv = Canvas()
    if pose == "down":
        cv.poly([(6, 46), (12, 38), (36, 37), (42, 46)], C["r"])
        cv.line([(12, 40), (34, 39)], C["rm"])
        cv.ell(30, 36, 39, 44, C["s"])
        cv.px(33, 39, C["o"])
        cv.px(36, 39, C["o"])
        cv.line([(8, 44), (16, 42)], C["b"])
        cv.outline(C["o"])
        return cv
    bob = 1 if pose == "idle_b" else 0
    lean = {"windup": -2, "strike": 3}.get(pose, 0)
    cv.dy = bob
    # Piernas flacas y dobladas.
    cv.line([(19, 36), (16, 41), (18, 46 - bob)], C["sd"], 2)
    cv.line([(29, 36), (32, 41), (30, 46 - bob)], C["sd"], 2)
    # Capa rasgada (encorvado: hombros altos).
    cv.dx = lean
    cv.poly([(14, 18), (34, 18), (37, 38), (33, 36), (30, 39), (26, 36), (22, 39), (18, 36), (12, 38)], C["r"])
    cv.poly([(16, 18), (24, 18), (22, 34), (15, 35)], C["rm"])
    cv.line([(15, 19), (33, 19)], C["rl"])
    # Cabeza adelantada (calavera pálida).
    hy = 7 + (2 if pose == "strike" else 0)
    cv.ell(18, hy, 30, hy + 11, C["s"])
    cv.rect(20, hy + 1, 27, hy + 2, C["sl"])
    cv.rect(18, hy + 7, 30, hy + 11, C["sd"])
    cv.rect(20, hy + 4, 22, hy + 5, C["e"])
    cv.rect(26, hy + 4, 28, hy + 5, C["e"])
    for x in (21, 23, 25, 27):
        cv.px(x, hy + 9, C["b"])
    # Brazos con dagas.
    if pose == "windup":
        cv.line([(15, 20), (9, 13), (11, 7)], C["s"], 2)
        cv.line([(33, 20), (39, 13), (37, 7)], C["s"], 2)
        cv.line([(10, 7), (6, 0)], C["b"], 2)
        cv.line([(38, 7), (42, 0)], C["b"], 2)
    elif pose == "strike":
        cv.line([(15, 21), (24, 27), (31, 31)], C["s"], 2)
        cv.line([(33, 21), (24, 27), (17, 31)], C["s"], 2)
        cv.line([(31, 31), (38, 38)], C["b"], 2)
        cv.line([(17, 31), (10, 38)], C["b"], 2)
    else:
        cv.line([(15, 20), (11, 28), (12, 33)], C["s"], 2)
        cv.line([(33, 20), (37, 28), (36, 33)], C["s"], 2)
        cv.line([(12, 34), (10, 41)], C["b"], 2)
        cv.line([(36, 34), (38, 41)], C["b"], 2)
        cv.px(11, 34, C["bd"])
        cv.px(37, 34, C["bd"])
    cv.dx = 0
    cv.outline(C["o"])
    if pose == "hurt":
        cv.shear(-0.15)
    return cv


# --- Lobo de ceniza (rival): ceniza con brasas, ojos amarillos ---------------

W = dict(o="#120e12", d="#3b3539", m="#5f575c", l="#8a8186", hl="#b3a9ad",
         em="#ff6a1a", eb="#ffb347", e="#ffe14d", n="#1c1618", cl="#e9e2d0")


def wolf(pose: str) -> Canvas:
    cv = Canvas()
    if pose == "down":
        cv.ell(8, 36, 40, 46, W["m"])
        cv.ell(10, 36, 30, 41, W["l"])
        cv.poly([(34, 34), (44, 38), (40, 44), (32, 42)], W["m"])
        cv.px(40, 39, W["o"])
        cv.line([(14, 42), (20, 40), (26, 43)], W["em"])
        cv.outline(W["o"])
        return cv
    bob = 1 if pose == "idle_b" else 0
    cv.dy = bob + (2 if pose == "strike" else 0)
    # Piernas (patas traseras dobladas).
    cv.poly([(15, 32), (22, 32), (21, 40), (19, 46 - cv.dy), (14, 46 - cv.dy), (16, 40)], W["d"])
    cv.poly([(26, 32), (33, 32), (32, 40), (34, 46 - cv.dy), (29, 46 - cv.dy), (27, 40)], W["d"])
    # Torso y pecho.
    cv.poly([(13, 16), (35, 16), (33, 34), (15, 34)], W["m"])
    cv.poly([(19, 18), (29, 18), (27, 32), (21, 32)], W["l"])
    cv.line([(15, 22), (17, 30)], W["em"])
    cv.line([(33, 21), (31, 27)], W["em"])
    # Melena con picos.
    for i, x in enumerate(range(12, 37, 4)):
        cv.poly([(x, 17), (x + 2, 11 + (i % 2) * 2), (x + 4, 17)], W["d"])
    cv.px(24, 12, W["eb"])
    # Cabeza de frente: orejas, cara, hocico.
    hy = 2 + (1 if pose == "windup" else 0)
    cv.poly([(16, hy + 6), (17, hy - 2), (21, hy + 4)], W["m"])
    cv.poly([(32, hy + 6), (31, hy - 2), (27, hy + 4)], W["m"])
    cv.px(17, hy + 1, W["em"])
    cv.px(31, hy + 1, W["em"])
    cv.poly([(16, hy + 5), (32, hy + 5), (30, hy + 12), (24, hy + 16), (18, hy + 12)], W["m"])
    cv.rect(21, hy + 10, 27, hy + 15, W["hl"])
    cv.rect(23, hy + 10, 25, hy + 11, W["n"])
    eye = W["eb"] if pose == "hurt" else W["e"]
    cv.rect(19, hy + 7, 21, hy + 8, eye)
    cv.rect(27, hy + 7, 29, hy + 8, eye)
    if pose in ("windup", "strike"):
        cv.line([(22, hy + 14), (26, hy + 14)], W["cl"])  # colmillos
    # Brazos con garras.
    if pose == "windup":
        cv.line([(14, 19), (8, 12), (7, 5)], W["m"], 3)
        cv.line([(34, 19), (40, 12), (41, 5)], W["m"], 3)
        for x in (5, 7, 9):
            cv.line([(x, 4), (x - 1, 1)], W["cl"])
        for x in (39, 41, 43):
            cv.line([(x, 4), (x + 1, 1)], W["cl"])
    elif pose == "strike":
        cv.line([(14, 20), (9, 27), (6, 34)], W["m"], 3)
        cv.line([(34, 20), (30, 28), (24, 34)], W["m"], 3)
        cv.line([(3, 30), (12, 40)], W["eb"])  # zarpazo
        cv.line([(5, 29), (14, 39)], W["eb"])
        for x in (22, 24, 26):
            cv.line([(x, 35), (x - 2, 39)], W["cl"])
    else:
        cv.line([(14, 19), (10, 27), (10, 34)], W["m"], 3)
        cv.line([(34, 19), (38, 27), (38, 34)], W["m"], 3)
        for x in (8, 10, 12):
            cv.px(x, 36, W["cl"])
        for x in (36, 38, 40):
            cv.px(x, 36, W["cl"])
    cv.outline(W["o"])
    if pose == "hurt":
        cv.shear(-0.12)
    return cv


ENEMIES = {
    "enemies/sprites/slag_golem.png": golem,
    "enemies/sprites/scavenger.png": scavenger,
    "enemies/sprites/ash_wolf.png": wolf,
}


def main() -> None:
    for rel, fn in ENEMIES.items():
        sheet = Image.new("RGBA", (S * len(FRAMES), S), (0, 0, 0, 0))
        for i, pose in enumerate(FRAMES):
            sheet.paste(fn(pose).img, (i * S, 0))
        out = ROOT / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(out)
        print("ok", rel)


if __name__ == "__main__":
    main()
