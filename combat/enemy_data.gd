class_name EnemyData
extends Resource
## Lo que un enemigo ES (fijo, se diseña a mano en un .tres): nombre, vida,
## poder, sprite y su forma de pelear (movimientos + patrón).
##
## Los enemigos comunes son solo esto: NO tienen memoria. Los rivales usan
## RivalData (que extiende esta ficha) y además una RivalMemory aparte.
## Analogía web: las "props" de un componente <Enemy />.

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_hp: int = 90
## Poder base para la lectura de la piedra (el jugador empieza en 100).
@export var power: int = 110
## Hechizo al que es débil ("" = ninguno). La piedra lo puede leer.
@export var weakness: String = ""

@export_group("Pelea")
## Sus movimientos. El patrón los nombra por id.
@export var moves: Array[EnemyMove] = []
## Orden en que usa sus movimientos, un turno cada uno, en ciclo.
@export var pattern: PackedStringArray = PackedStringArray()
## Patrón cuando le queda menos de la mitad de vida ("se enoja").
## Vacío = sigue con el normal.
@export var pattern_low: PackedStringArray = PackedStringArray()

@export_group("Botín")
## Items que puede soltar al vencerlo: id de item -> probabilidad (0..1).
@export var loot: Dictionary = {}

@export_group("Aspecto")
## Tira de 6 cuadros de 48x48: quieto A, quieto B, preparando, golpeando,
## herido, derrotado (ver tools/art/make_enemy_sprites.py).
@export var sprite: Texture2D
## Metros por pixel del sprite (48 px * 0.04 = 1.9 m de alto).
@export var pixel_size: float = 0.04
## A cuántos metros se para frente a ti en el duelo.
@export var duel_distance: float = 3.0
## Velocidad al perseguirte (m/s).
@export var chase_speed: float = 2.6

@export_group("Texto")
## Lo que dice (o hace) al empezar el duelo la primera vez.
@export var line_first_meet: String = ""
@export var line_defeated: String = "...Recordaré esto."


func is_rival() -> bool:
	return false


func move_by_id(move_id: StringName) -> EnemyMove:
	for m: EnemyMove in moves:
		if m.id == move_id:
			return m
	return null
