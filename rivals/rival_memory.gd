class_name RivalMemory
extends Resource
## Lo que UN rival recuerda de ti. Cada rival tiene la suya y solo se llena
## con duelos en los que ESE rival estuvo (ver record()).
##
## Analogía web: una fila por rival en una tabla "rival_memories", con
## contadores que se actualizan después de cada pelea.
##
## Regla de diseño (patente): esta memoria NUNCA se modifica por lo que pase
## con otro rival. No hay método que reciba otra memoria ni a otro rival.

const SIDE_NAMES: Array[String] = ["la izquierda", "el centro", "la derecha"]
## Cuántos golpes tuyos necesita haber visto para saber tu lado favorito.
const MIN_ATTACKS_FOR_FAVORITE: int = 4
## Qué tanto tiene que destacar ese lado (fracción de tus golpes).
const FAVORITE_SHARE: float = 0.4

@export var rival_id: StringName = &""
## Duelos contra ti (cualquier resultado).
@export var duels: int = 0
## "", "win" (ganaste tú), "lose" (perdiste) o "fled" (huiste).
@export var last_result: String = ""
@export var player_wins: int = 0
@export var player_losses: int = 0
@export var player_flees: int = 0
## Cuántas veces lo has atacado por la izquierda, el centro y la derecha.
@export var attack_counts: Array[int] = [0, 0, 0]
## Hechizos que le has lanzado: nombre -> veces.
@export var spell_counts: Dictionary = {}
## Sus golpes que le bloqueaste perfecto, y cuántos golpes ha lanzado.
@export var perfect_blocks_seen: int = 0
@export var strikes_thrown: int = 0
## Marcas que le dejaste al vencerlo (p. ej. "Fuego"). Vuelve con ellas.
@export var scars: Array[String] = []


## Guarda lo que pasó en un duelo con ESTE rival.
func record(e: Encounter) -> void:
	if e.rival_id != rival_id:
		push_error("RivalMemory.record: el duelo era con %s, no con %s" % [e.rival_id, rival_id])
		return
	duels += 1
	last_result = String(e.result)
	match e.result:
		&"win":
			player_wins += 1
			var scar: String = e.finisher if not e.finisher.is_empty() else "Acero"
			if not scars.has(scar):
				scars.append(scar)
		&"lose":
			player_losses += 1
		&"fled":
			player_flees += 1
	for i: int in 3:
		attack_counts[i] += e.attack_sides[i]
	for spell_name: String in e.spells:
		spell_counts[spell_name] = int(spell_counts.get(spell_name, 0)) + int(e.spells[spell_name])
	perfect_blocks_seen += e.perfect_blocks
	strikes_thrown += e.rival_strikes()


## Tu lado favorito para atacar (0..2), o -1 si todavía no se nota.
func favorite_side() -> int:
	var total: int = attack_counts[0] + attack_counts[1] + attack_counts[2]
	if total < MIN_ATTACKS_FOR_FAVORITE:
		return -1
	var best: int = 0
	for i: int in 3:
		if attack_counts[i] > attack_counts[best]:
			best = i
	if float(attack_counts[best]) / float(total) < FAVORITE_SHARE:
		return -1
	return best


## El hechizo que más le has lanzado ("" si ninguno).
func favorite_spell() -> String:
	var best: String = ""
	var best_count: int = 0
	for spell_name: String in spell_counts:
		var c: int = int(spell_counts[spell_name])
		if c > best_count:
			best = spell_name
			best_count = c
	return best


## Fracción de sus golpes que le bloqueaste perfecto (0..1).
func perfect_rate() -> float:
	if strikes_thrown == 0:
		return 0.0
	return float(perfect_blocks_seen) / float(strikes_thrown)
