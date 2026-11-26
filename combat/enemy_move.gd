class_name EnemyMove
extends Resource
## Un movimiento de un enemigo en su turno. Cada enemigo tiene 2-4 y los
## usa en el orden de su patrón (EnemyData.pattern), así se pueden aprender.
##
## Tipos (todos se bloquean con la fila de arriba de la cuadrícula):
## - SIMPLE: un golpe de un lado (la flecha de siempre).
## - COMBO: varios golpes seguidos, por lados distintos y más rápidos.
## - FEINT (finta): amaga un lado (aro morado con "?") y a medio camino
##   cambia al otro. Si bloqueas antes del cambio, te comiste la finta.
## - CHARGED (cargado): un turno se prepara (no pega) y el siguiente suelta
##   un golpe muy fuerte. Trueno lo corta; Égida lo aguanta.

enum Kind { SIMPLE, COMBO, FEINT, CHARGED }

@export var id: StringName = &"golpe"
@export var display_name: String = "Golpe"
@export var kind: Kind = Kind.SIMPLE
## Golpes que da (solo importa en COMBO).
@export_range(1, 4) var hits: int = 1
@export var damage: int = 12
## Rango de segundos de aviso antes de cada golpe (se elige al azar dentro).
@export var windup: Vector2 = Vector2(0.7, 1.2)


static func make(move_id: StringName, move_name: String, move_kind: Kind, move_damage: int,
		move_windup: Vector2 = Vector2(0.7, 1.2), move_hits: int = 1) -> EnemyMove:
	var m: EnemyMove = EnemyMove.new()
	m.id = move_id
	m.display_name = move_name
	m.kind = move_kind
	m.damage = move_damage
	m.windup = move_windup
	m.hits = move_hits
	return m
