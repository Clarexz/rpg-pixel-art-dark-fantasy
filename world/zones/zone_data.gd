class_name ZoneData
extends Resource
## Ficha de una zona del mundo: su id, su nombre y nada más por ahora.
## El id es el que guarda la piedra para tu fama por zona (Encounter.zone),
## así que no conviene cambiarlo una vez publicado.
##
## Analogía web: los metadatos de una página (slug + título).

## Id estable, p. ej. &"greybox" o &"hondonada".
@export var id: StringName = &""
## Nombre que ve el jugador.
@export var display_name: String = ""
