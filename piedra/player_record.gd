class_name PlayerRecord
extends Resource
## Lo que tu piedra sabe de TI: tu estilo, tu nivel de piedra y tu fama por
## zona. Es lógica pura (sin nodos) para poder probarla sola; el autoload
## Piedra (piedra/piedra.gd) solo la guarda y avisa.
##
## Todo lo de aquí es del JUGADOR. Ningún rival se guarda aquí, y los rivales
## no cambian cómo pelean por lo que diga este registro.

signal reputation_changed(zone: StringName, value: int)
signal level_changed(level: int)

## XP de piedra necesaria para cada nivel (nivel 1 = índice 0).
const LEVEL_XP: Array[int] = [0, 30, 80, 160]
const XP_WIN: int = 20
## La primera vez que vences a un RIVAL absorbes un fragmento de su piedra
## (los enemigos comunes no tienen piedra propia: solo dan XP).
const XP_FIRST_ABSORB: int = 20
const XP_LOSE: int = 5
const XP_FLED: int = 2
const XP_PER_PERFECT: int = 2
const REP_WIN: int = 3
const REP_LOSE: int = -1
const REP_FLED: int = -2
const BASE_POWER: int = 100
const POWER_PER_LEVEL: int = 25

@export var stone_xp: int = 0
@export var duels: int = 0
@export var wins: int = 0
@export var losses: int = 0
@export var flees: int = 0
@export var attack_sides: Array[int] = [0, 0, 0]
@export var spell_counts: Dictionary = {}
@export var perfect_blocks: int = 0
## Fama por zona: zona -> puntos.
@export var reputation: Dictionary = {}
## Rivales a los que ya les absorbiste un fragmento (sus ids).
@export var absorbed: Array[String] = []


func level() -> int:
	var lv: int = 1
	for i: int in LEVEL_XP.size():
		if stone_xp >= LEVEL_XP[i]:
			lv = i + 1
	return lv


func power() -> int:
	return BASE_POWER + POWER_PER_LEVEL * (level() - 1)


func reputation_in(zone: StringName) -> int:
	return int(reputation.get(String(zone), 0))


## Registra un duelo (de cualquier rival) en TU historial.
## Devuelve true si absorbiste un fragmento nuevo de piedra.
func record(e: Encounter) -> bool:
	var old_level: int = level()
	duels += 1
	for i: int in 3:
		attack_sides[i] += e.attack_sides[i]
	for spell_name: String in e.spells:
		spell_counts[spell_name] = int(spell_counts.get(spell_name, 0)) + int(e.spells[spell_name])
	perfect_blocks += e.perfect_blocks
	stone_xp += e.perfect_blocks * XP_PER_PERFECT
	var rep_delta: int = 0
	var absorbed_now: bool = false
	match e.result:
		&"win":
			wins += 1
			stone_xp += XP_WIN
			rep_delta = REP_WIN
			if e.is_rival and not absorbed.has(String(e.rival_id)):
				absorbed.append(String(e.rival_id))
				stone_xp += XP_FIRST_ABSORB
				absorbed_now = true
		&"lose":
			losses += 1
			stone_xp += XP_LOSE
			rep_delta = REP_LOSE
		&"fled":
			flees += 1
			stone_xp += XP_FLED
			rep_delta = REP_FLED
	if rep_delta != 0:
		var key: String = String(e.zone)
		reputation[key] = reputation_in(e.zone) + rep_delta
		reputation_changed.emit(e.zone, int(reputation[key]))
	if level() != old_level:
		level_changed.emit(level())
	return absorbed_now


## Cómo te conocen en una zona (texto; "" = nadie te conoce todavía).
func fame_title(zone: StringName) -> String:
	var rep: int = reputation_in(zone)
	if rep <= -4:
		return "el que siempre huye"
	if rep >= 9:
		return "el que tumba rivales"
	if rep >= 3:
		return "el retador del que hablan"
	return ""


## Tu estilo en una frase (lo que la piedra "sabe" de ti).
func style_summary() -> String:
	var parts: PackedStringArray = []
	var total: int = attack_sides[0] + attack_sides[1] + attack_sides[2]
	if total >= 4:
		var best: int = 0
		for i: int in 3:
			if attack_sides[i] > attack_sides[best]:
				best = i
		parts.append("atacas más por %s" % RivalMemory.SIDE_NAMES[best])
	var fav: String = ""
	var fav_n: int = 0
	for s: String in spell_counts:
		if int(spell_counts[s]) > fav_n:
			fav = s
			fav_n = int(spell_counts[s])
	if fav_n > 0:
		parts.append("tu hechizo favorito es %s" % fav)
	if duels > 0 and float(flees) / float(duels) >= 0.4:
		parts.append("huyes seguido")
	return ", ".join(parts) if not parts.is_empty() else "todavía no te conoce"
