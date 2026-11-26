class_name RivalData
extends Resource
## Lo que un rival ES (fijo, se diseña a mano en un .tres): nombre, poder,
## temperamento. Lo que un rival RECUERDA de ti vive aparte, en RivalMemory.
##
## A propósito NO hay facción, rango, jefe ni "estatus": cada rival es
## independiente (ver docs/rivales-y-piedra.md, sección patente).

@export var id: StringName = &""
@export var display_name: String = ""
@export var max_hp: int = 90
## Poder base para la lectura de la piedra (el jugador empieza en 100).
@export var power: int = 110
## Hechizo al que es débil ("" = ninguno). La piedra lo puede leer.
@export var weakness: String = ""
## Qué tan rápido aprende de ti (1 = normal, 2 = el doble, 0.5 = la mitad).
@export_range(0.25, 3.0) var cunning: float = 1.0
## Orgullo: cambia lo que dice (provoca más, acepta peor perder).
@export_range(0.0, 1.0) var pride: float = 0.5
## Frases propias. Si están vacías se usan las genéricas.
@export var line_first_meet: String = ""
@export var line_defeated: String = "...Recordaré esto."
