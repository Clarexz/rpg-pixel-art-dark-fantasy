class_name RivalData
extends EnemyData
## Un RIVAL: un enemigo con nombre propio que te recuerda. Todo lo de
## EnemyData (vida, sprite, movimientos) más su temperamento. Lo que un
## rival RECUERDA de ti vive aparte, en RivalMemory.
##
## A propósito NO hay facción, rango, jefe ni "estatus": cada rival es
## independiente (ver docs/rivales-y-piedra.md, sección patente).

## Qué tan rápido aprende de ti (1 = normal, 2 = el doble, 0.5 = la mitad).
@export_range(0.25, 3.0) var cunning: float = 1.0
## Orgullo: cambia lo que dice (provoca más, acepta peor perder).
@export_range(0.0, 1.0) var pride: float = 0.5


func is_rival() -> bool:
	return true
