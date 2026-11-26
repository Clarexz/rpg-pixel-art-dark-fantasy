class_name Encounter
extends RefCounted
## Resumen de UN duelo entre el jugador y UN rival. Es el único "mensaje"
## que viaja del combate a la memoria: el duelo lo llena y al final se lo
## entrega a la memoria de ESE rival y a la piedra del jugador.
##
## Analogía web: el payload de un evento "duel_finished" que guardas en dos
## tablas (la del rival y la del jugador). Nunca se reparte a otros rivales.

## Con quién fue el duelo (RivalData.id).
var rival_id: StringName = &""
## false = enemigo común (sin memoria): da XP pero no fragmento de piedra.
var is_rival: bool = true
## Dónde pasó (para la reputación por zona).
var zone: StringName = &"greybox"
## &"win" (ganaste tú), &"lose" (perdiste) o &"fled" (huiste).
var result: StringName = &""
## &"player" si golpeaste primero, &"rival" si te emboscó.
var advantage: StringName = &"player"
## Cuántos golpes diste por izquierda, centro y derecha.
var attack_sides: Array[int] = [0, 0, 0]
## Hechizos lanzados con éxito: nombre -> veces.
var spells: Dictionary = {}
## Hechizo con el que lo remataste ("" si fue a golpes o no ganaste).
var finisher: String = ""
## Golpes del rival que bloqueaste perfecto / bloqueaste / te pegaron.
var perfect_blocks: int = 0
var blocks: int = 0
var hits_taken: int = 0
var turns: int = 0


func rival_strikes() -> int:
	return perfect_blocks + blocks + hits_taken


func add_spell(spell_name: String) -> void:
	spells[spell_name] = int(spells.get(spell_name, 0)) + 1
