class_name PowerReading
extends RefCounted
## La piedra como "scouter": lee el poder de un rival. Entre más fuerte tu
## piedra, más precisa la lectura:
##   nivel 1: solo "más fuerte / parecido / más débil"
##   nivel 2: número aproximado (de 25 en 25)
##   nivel 3: número de 10 en 10 + su debilidad
##   nivel 4: número exacto + debilidad
## Si el rival es demasiado fuerte para tu piedra, la lectura se "rompe".

const BREAK_RATIO_BASE: float = 1.5
const BREAK_RATIO_PER_LEVEL: float = 0.5
const STRONGER_RATIO: float = 1.15
const WEAKER_RATIO: float = 0.87
## Cada vez que un rival te vence, se hace un poco más fuerte (él mismo).
const RIVAL_POWER_PER_WIN: int = 10

var tier: StringName = &"similar"  # &"weaker", &"similar", &"stronger", &"broken"
## Número mostrado (-1 = la piedra no da número a este nivel).
var value: int = -1
var weakness: String = ""
var text: String = ""


## Poder actual de un rival: su base + lo que creció venciéndote A TI.
## Solo usa la memoria de ESE rival.
static func rival_power(data: RivalData, memory: RivalMemory) -> int:
	var wins_over_player: int = memory.player_losses if memory != null else 0
	return data.power + RIVAL_POWER_PER_WIN * wins_over_player


static func read(stone_level: int, reader_power: int, target_name: String,
		target_power: int, target_weakness: String = "") -> PowerReading:
	var r: PowerReading = PowerReading.new()
	var ratio: float = float(target_power) / float(maxi(reader_power, 1))
	if ratio > BREAK_RATIO_BASE + BREAK_RATIO_PER_LEVEL * stone_level:
		r.tier = &"broken"
		r.text = "%s: la piedra se agrieta... ¡demasiado poder para leerlo!" % target_name
		return r
	if ratio >= STRONGER_RATIO:
		r.tier = &"stronger"
	elif ratio <= WEAKER_RATIO:
		r.tier = &"weaker"
	var words: Dictionary = {&"stronger": "más fuerte que tú", &"similar": "parecido a ti",
			&"weaker": "más débil que tú"}
	r.text = "%s: %s" % [target_name, words[r.tier]]
	match stone_level:
		1:
			pass
		2:
			r.value = roundi(target_power / 25.0) * 25
		3:
			r.value = roundi(target_power / 10.0) * 10
		_:
			r.value = target_power
	if r.value >= 0:
		r.text += " (~%d)" % r.value if stone_level < 4 else " (%d)" % r.value
	if stone_level >= 3 and not target_weakness.is_empty():
		r.weakness = target_weakness
		r.text += ". Débil a %s" % target_weakness
	return r
