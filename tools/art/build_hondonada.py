#!/usr/bin/env python3
"""Genera la primera versión de la Hondonada de ceniza (fase 5, v0.6.3).

Dibuja el mapa como una cuadrícula de letras (vista desde arriba, norte
arriba) y lo convierte en world/zones/hondonada/hondonada.tscn: un GridMap
con los bloques del kit (assets/tiles/tile_kit.tres), los enemigos, el punto
de inicio y la navegación.

Cada letra es una casilla de 2x2 m. Es solo el PUNTO DE PARTIDA: después de
generarla, la zona se edita directo en Godot (pintando el GridMap). Si vuelves
a correr este script, se pierden esos cambios.

Uso:  python3 tools/art/build_hondonada.py          (escribe la escena)
      python3 tools/art/build_hondonada.py --mapa   (solo imprime el mapa)
"""
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "world" / "zones" / "hondonada" / "hondonada.tscn"

W, H = 36, 46  # casillas: 72 x 92 m

# Ids del kit (tools/art/build_tile_kit.gd)
CENIZA, ESCORIA, CAMINO, ROCA, LADRILLO, BAJO, CAJA, RAMPA, RAMPA_ALTA, MURO_BAJO, TRONCO = range(11)

LEGEND = {
    "#": "pared de roca (6 m)",
    ".": "suelo de ceniza",
    "=": "camino empedrado",
    ",": "suelo de escoria",
    "p": "meseta del altar (1 m de alto)",
    "r": "rampa a la meseta",
    "A": "lugar del altar (muro bajo de ladrillo)",
    "H": "torre en ruinas (8 m)",
    "b": "muro bajo de ladrillo",
    "o": "bloque bajo de roca",
    "c": "caja / carreta",
    "t": "árbol quemado (4 m)",
    "M": "galería de la mina (con techo)",
    "P": "inicio del jugador (campamento)",
    "S": "Carroñero",
    "G": "Gólem de escoria",
    "W": "Lobo de ceniza (rival)",
}


def build_map() -> list:
    g = [["." for _ in range(W)] for _ in range(H)]

    def fill(x0, z0, x1, z1, ch):
        for z in range(z0, z1 + 1):
            for x in range(x0, x1 + 1):
                g[z][x] = ch

    # Paredes del valle (con entrantes para que no sea una caja).
    fill(0, 0, W - 1, 1, "#")
    fill(0, H - 2, W - 1, H - 1, "#")
    fill(0, 0, 1, H - 1, "#")
    fill(W - 2, 0, W - 1, H - 1, "#")
    fill(2, 2, 4, 4, "#")
    fill(29, 2, 33, 6, "#")
    fill(2, 39, 5, 43, "#")
    fill(29, 37, 33, 43, "#")
    fill(2, 31, 3, 35, "#")
    fill(32, 13, 33, 18, "#")

    # Norte: meseta del altar con rampa.
    fill(13, 2, 22, 7, "p")
    fill(16, 3, 19, 4, "A")
    fill(16, 8, 19, 8, "r")

    # Bosque quemado (oeste): árboles al azar, siempre iguales.
    rng = random.Random(5)
    for z in range(6, 35):
        for x in range(3, 14):
            if g[z][x] == "." and rng.random() < 0.13:
                g[z][x] = "t"

    # Camino principal (sur a norte) y desvíos.
    fill(17, 9, 18, 42, "=")
    fill(19, 15, 27, 15, "=")      # a la torre
    fill(9, 21, 16, 21, "=")       # sendero al bosque
    fill(21, 22, 27, 27, ",")      # escoria frente a la mina
    fill(19, 24, 20, 25, ",")

    # Torre en ruinas (noreste): anillo alto con puerta al sur.
    fill(24, 8, 30, 14, "H")
    fill(25, 9, 29, 13, ".")
    g[14][27] = "."
    for x, z in [(22, 10), (22, 11), (23, 17), (24, 17), (31, 16)]:
        g[z][x] = "b"

    # Mina (este): bloque de roca con galería techada, entrada al oeste.
    fill(27, 19, 33, 30, "#")
    fill(28, 21, 32, 28, "M")
    fill(27, 24, 27, 25, "M")

    # Campamento (sur).
    fill(13, 37, 22, 42, "=")
    for x, z in [(13, 37), (22, 37), (13, 42), (22, 42)]:
        g[z][x] = "c"
    g[40][15] = "o"  # fogata (provisional; la hoguera llega en v0.6.4)

    # Cobertura en el camino.
    for x, z in [(16, 29), (19, 34), (15, 18)]:
        g[z][x] = "c"
    for x, z in [(20, 19), (14, 27)]:
        g[z][x] = "o"

    # Despeja alrededor del lobo y pon a todos.
    fill(7, 21, 9, 23, ".")
    g[21][8] = "="
    spawns = {
        (18, 41): "P",
        (18, 26): "S", (17, 33): "S",   # camino
        (27, 11): "S",                  # torre
        (6, 29): "S",                   # bosque
        (25, 23): "G", (31, 26): "G",   # mina (fuera y dentro)
        (8, 22): "W",                   # bosque
    }
    for (x, z), ch in spawns.items():
        g[z][x] = ch
    return g


def cells_for(ch: str) -> list:
    """(y, bloque) que van en esa casilla. y=-1 es el suelo (arriba en 0 m)."""
    floor = {".": CENIZA, "t": CENIZA, "W": CENIZA, "b": CENIZA, "o": CENIZA,
             "=": CAMINO, "P": CAMINO, "S": CAMINO, "c": CAMINO,
             ",": ESCORIA, "G": ESCORIA, "M": ESCORIA,
             "p": CENIZA, "r": CENIZA, "A": CENIZA}
    out = []
    if ch in floor:
        out.append((-1, floor[ch]))
    if ch == "#":
        out += [(0, ROCA), (1, ROCA), (2, ROCA)]
    elif ch == "H":
        out += [(0, LADRILLO), (1, LADRILLO), (2, LADRILLO), (3, LADRILLO)]
    elif ch == "p":
        out.append((0, BAJO))
    elif ch == "A":
        out.append((0, MURO_BAJO))
    elif ch == "r":
        out.append((0, RAMPA))
    elif ch == "b":
        out.append((0, MURO_BAJO))
    elif ch == "o":
        out.append((0, BAJO))
    elif ch == "c":
        out.append((0, CAJA))
    elif ch == "t":
        out += [(0, TRONCO), (1, TRONCO)]
    elif ch == "M":
        out.append((2, ROCA))  # techo de la galería (4 m)
    return out


def i32(v: int) -> int:
    return v - (1 << 32) if v >= (1 << 31) else v


def world_pos(col: int, row: int) -> tuple:
    """Centro de la casilla, a nivel del suelo."""
    return (2 * (col - 18) + 1, 0, 2 * (row - 23) + 1)


def scene(g: list) -> str:
    data = []
    for row in range(H):
        for col in range(W):
            for y, item in cells_for(g[row][col]):
                x, z = col - 18, row - 23
                data += [i32((x & 0xFFFF) | ((y & 0xFFFF) << 16)), z & 0xFFFF, item]
    enemies = []
    counts = {"S": 0, "G": 0, "W": 0}
    names = {"S": "Scavenger", "G": "SlagGolem", "W": "AshWolf"}
    res = {"S": "3_scav", "G": "4_golem", "W": "5_wolf"}
    start = None
    for row in range(H):
        for col in range(W):
            ch = g[row][col]
            x, y, z = world_pos(col, row)
            if ch == "P":
                start = (x, y, z)
            if ch in counts:
                counts[ch] += 1
                name = names[ch] + (str(counts[ch]) if ch != "W" else "")
                extra = ""
                if ch == "G":
                    extra = "patrol_radius = 2.0\nwalk_speed = 0.6\n"
                if ch == "W":
                    extra = "respawn_time = 20.0\n"
                enemies.append(
                    f'[node name="{name}" parent="Enemies" instance=ExtResource("2_enemy")]\n'
                    f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})\n"
                    f'data = ExtResource("{res[ch]}")\n{extra}')
    cells = ", ".join(str(v) for v in data)
    return f'''[gd_scene format=3]

[ext_resource type="Script" path="res://world/zones/zone.gd" id="1_zone"]
[ext_resource type="PackedScene" path="res://enemies/enemy.tscn" id="2_enemy"]
[ext_resource type="Resource" path="res://enemies/data/scavenger.tres" id="3_scav"]
[ext_resource type="Resource" path="res://enemies/data/slag_golem.tres" id="4_golem"]
[ext_resource type="Resource" path="res://rivals/data/ash_wolf.tres" id="5_wolf"]
[ext_resource type="Resource" path="res://world/zones/hondonada/hondonada_zone.tres" id="6_data"]
[ext_resource type="MeshLibrary" path="res://assets/tiles/tile_kit.tres" id="7_kit"]

[sub_resource type="ProceduralSkyMaterial" id="sky_mat"]
sky_top_color = Color(0.09, 0.06, 0.1, 1)
sky_horizon_color = Color(0.38, 0.2, 0.16, 1)
ground_bottom_color = Color(0.04, 0.03, 0.03, 1)
ground_horizon_color = Color(0.38, 0.2, 0.16, 1)

[sub_resource type="Sky" id="sky"]
sky_material = SubResource("sky_mat")

[sub_resource type="Environment" id="env"]
background_mode = 2
sky = SubResource("sky")
ambient_light_source = 3
ambient_light_energy = 0.55
tonemap_mode = 2

[sub_resource type="NavigationMesh" id="navmesh"]
geometry_parsed_geometry_type = 1
geometry_source_geometry_mode = 1
geometry_source_group_name = &"navmesh_source"
cell_size = 0.25
cell_height = 0.25
agent_height = 1.75
agent_radius = 0.5
agent_max_climb = 0.5
agent_max_slope = 40.0

[node name="Hondonada" type="Node3D"]
script = ExtResource("1_zone")
data = ExtResource("6_data")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("env")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866025, -0.353553, 0.353553, 0, 0.707107, 0.707107, -0.5, -0.612372, 0.612372, 0, 6, 0)
light_color = Color(1, 0.85, 0.7, 1)
light_energy = 0.8
shadow_enabled = true

[node name="Terrain" type="GridMap" parent="." groups=["navmesh_source"]]
mesh_library = ExtResource("7_kit")
cell_size = Vector3(2, 2, 2)
data = {{
"cells": PackedInt32Array({cells})
}}

[node name="Enemies" type="Node3D" parent="."]

{chr(10).join(enemies)}
[node name="Navigation" type="NavigationRegion3D" parent="."]
navigation_mesh = SubResource("navmesh")

[node name="PlayerStart" type="Marker3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {start[0]}, {start[1]}, {start[2]})
'''


def main() -> None:
    g = build_map()
    text = "\n".join("".join(r) for r in g)
    if "--mapa" in sys.argv:
        print(text)
        print()
        for k, v in LEGEND.items():
            print(f"  {k}  {v}")
        return
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(scene(g))
    print("ok", OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
