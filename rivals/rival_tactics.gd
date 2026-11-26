class_name RivalTactics
extends RefCounted
## Cómo pelea un rival en el próximo duelo. Se calcula al empezar el duelo
## con plan(), a partir de SOLO dos cosas:
##   1. lo que el rival es (RivalData)
##   2. lo que ESE rival recuerda de ti (RivalMemory)
## No recibe a otros rivales, ni un registro, ni la reputación del jugador.
## Así, por construcción, lo que pase con el rival A no puede cambiar cómo
## pelea el rival B (ver docs/rivales-y-piedra.md).
##
## Analogía web: una función pura `plan(rival, memory) => tactics`, como un
## selector de Redux: misma entrada, misma salida, sin efectos.

## Con cunning = 1, a partir de cuántos duelos empieza a usar lo aprendido.
const ADAPT_BASE_DUELS: int = 3
## Probabilidad de cubrir tu lado favorito cuando ya te conoce.
const GUARD_FAVORITE_CHANCE: float = 0.7
## Cuántas veces tiene que ver un hechizo para aprender a resistirlo.
const RESIST_AFTER_CASTS: int = 3
const RESIST_MULT: float = 0.65
## Daño extra del hechizo al que es débil.
const WEAKNESS_MULT: float = 1.3
## Si bloqueas perfecto así de seguido, cambia el ritmo de sus golpes.
const RHYTHM_PERFECT_RATE: float = 0.4
const RHYTHM_MIN_STRIKES: int = 4
const WINDUP_NORMAL: Vector2 = Vector2(0.7, 1.2)
const WINDUP_MIXED: Vector2 = Vector2(0.5, 1.5)
## Si te ha vencido seguido, se envalentona: un golpe más por turno.
const BOLD_AFTER_WINS: int = 2

## Duelos que necesita este rival para adaptarse (según su astucia).
var adapt_after: int = ADAPT_BASE_DUELS
## Lado que cubre de más (-1 = adivina al azar).
var guard_side: int = -1
var guard_chance: float = 0.0
## Hechizo que resiste ("" = ninguno) y hechizo al que es débil.
var resists: String = ""
var weakness: String = ""
## Rango de tiempo de aviso de sus golpes (segundos).
var windup: Vector2 = WINDUP_NORMAL
var extra_strikes: int = 0
## Lista legible de lo que aprendió (para la UI, el doc y las pruebas).
var learned: PackedStringArray = []


## Tácticas de un enemigo COMÚN (sin memoria): nunca se adapta a ti.
static func for_enemy(data: EnemyData) -> RivalTactics:
	var t: RivalTactics = RivalTactics.new()
	t.weakness = data.weakness
	return t


static func plan(data: RivalData, memory: RivalMemory) -> RivalTactics:
	var t: RivalTactics = RivalTactics.new()
	t.weakness = data.weakness
	t.adapt_after = maxi(1, roundi(ADAPT_BASE_DUELS / maxf(data.cunning, 0.01)))
	if memory == null or memory.duels < t.adapt_after:
		return t

	var fav: int = memory.favorite_side()
	if fav != -1:
		t.guard_side = fav
		t.guard_chance = GUARD_FAVORITE_CHANCE
		t.learned.append("cubre %s" % RivalMemory.SIDE_NAMES[fav])

	# Resiste el hechizo que más le lanzas... o el que lo venció (cicatriz).
	var spell: String = memory.favorite_spell()
	if not spell.is_empty() and int(memory.spell_counts[spell]) >= RESIST_AFTER_CASTS:
		t.resists = spell
	elif not memory.scars.is_empty() and memory.scars[-1] != "Acero":
		t.resists = memory.scars[-1]
	if not t.resists.is_empty():
		t.learned.append("resiste %s" % t.resists)
		if t.resists == t.weakness:
			t.weakness = ""  # aprendió a cubrir su punto débil

	if memory.strikes_thrown >= RHYTHM_MIN_STRIKES and memory.perfect_rate() >= RHYTHM_PERFECT_RATE:
		t.windup = WINDUP_MIXED
		t.learned.append("cambia el ritmo de sus golpes")

	if memory.player_losses >= BOLD_AFTER_WINS:
		t.extra_strikes = 1
		t.learned.append("ataca más seguido")
	return t


## Qué lado cubre ante tu golpe.
func pick_guard(rng: RandomNumberGenerator) -> int:
	if guard_side != -1 and rng.randf() < guard_chance:
		return guard_side
	var roll: float = rng.randf()
	if roll < 0.3:
		return 0
	if roll < 0.7:
		return 1
	return 2


## Multiplicador de daño de un hechizo tuyo contra este rival.
func spell_multiplier(spell_name: String) -> float:
	if spell_name == resists:
		return RESIST_MULT
	if spell_name == weakness:
		return WEAKNESS_MULT
	return 1.0


func pick_windup(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(windup.x, windup.y)


## Aviso de un movimiento concreto. Si aprendió a "cambiar el ritmo",
## el rango se abre (a veces más rápido, a veces más lento).
func pick_windup_for(base: Vector2, rng: RandomNumberGenerator) -> float:
	if windup == WINDUP_NORMAL:
		return rng.randf_range(base.x, base.y)
	return rng.randf_range(base.x * 0.7, base.y * 1.25)
