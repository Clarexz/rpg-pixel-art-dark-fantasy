class_name RivalSim
extends RefCounted
## Simulación de texto: 10 duelos guionados contra dos rivales independientes
## (Cubo y Lobo). No hay combate real: el guion dice cómo jugaste y quién
## ganó, y aquí se ve cómo cambia la memoria de cada rival, sus tácticas, su
## saludo, tu piedra y tu fama. La usan la prueba automática y la escena
## tools/sim/rival_sim.tscn.

const CUBE: RivalData = preload("res://rivals/data/test_cube.tres")
const WOLF: RivalData = preload("res://rivals/data/ash_wolf.tres")

## Guion: [rival, resultado, golpes izq/centro/der, hechizos, perfectos, bloqueos, golpes recibidos]
const SCRIPT: Array = [
	[&"test_cube", &"fled", [3, 1, 0], {"Fuego": 1}, 1, 1, 2],
	[&"ash_wolf", &"lose", [2, 0, 1], {}, 0, 1, 4],
	[&"test_cube", &"lose", [4, 0, 1], {"Fuego": 1}, 2, 0, 3],
	[&"ash_wolf", &"lose", [3, 1, 0], {"Fuego": 1}, 1, 1, 3],
	[&"test_cube", &"win", [4, 1, 0], {"Fuego": 1}, 3, 1, 1],
	[&"ash_wolf", &"fled", [2, 0, 0], {}, 0, 0, 3],
	[&"test_cube", &"win", [2, 2, 1], {"Fuego": 1}, 3, 0, 1],
	[&"ash_wolf", &"win", [1, 2, 2], {"Fuego": 2}, 2, 1, 2],
	[&"test_cube", &"win", [1, 3, 1], {"Trueno": 1}, 2, 1, 1],
	[&"ash_wolf", &"win", [1, 3, 2], {"Fuego": 1}, 3, 0, 1],
]

var registry: RivalRegistry = RivalRegistry.new()
var player: PlayerRecord = PlayerRecord.new()
## Una entrada por duelo con lo que se vio ANTES y DESPUÉS.
var history: Array[Dictionary] = []


static func data_for(id: StringName) -> RivalData:
	return CUBE if id == CUBE.id else WOLF


func run() -> RivalSim:
	for step: Array in SCRIPT:
		var data: RivalData = data_for(step[0])
		var memory: RivalMemory = registry.memory_for(data.id)
		var tactics: RivalTactics = RivalTactics.plan(data, memory)
		var reading: PowerReading = PowerReading.read(player.level(), player.power(),
				data.display_name, PowerReading.rival_power(data, memory), data.weakness)
		var hello: String = RivalDialogue.greeting(data, memory, tactics, player.fame_title(&"greybox"))
		var e: Encounter = Encounter.new()
		e.rival_id = data.id
		e.result = step[1]
		e.attack_sides.assign(step[2])
		e.spells = (step[3] as Dictionary).duplicate()
		e.perfect_blocks = step[4]
		e.blocks = step[5]
		e.hits_taken = step[6]
		if e.result == &"win" and not e.spells.is_empty():
			e.finisher = e.spells.keys()[0]
		registry.record(e)
		var absorbed: bool = player.record(e)
		history.append({
			"rival": data.display_name, "id": data.id, "result": e.result,
			"greeting": hello, "reading": reading.text, "learned": tactics.learned,
			"resists": tactics.resists, "guard_side": tactics.guard_side,
			"absorbed": absorbed, "level": player.level(), "fame": player.reputation_in(&"greybox"),
		})
	return self


func lines() -> PackedStringArray:
	var out: PackedStringArray = []
	var words: Dictionary = {&"win": "GANASTE", &"lose": "PERDISTE", &"fled": "HUISTE"}
	for i: int in history.size():
		var l: Dictionary = history[i]
		out.append("— Duelo %d vs %s —" % [i + 1, l.rival])
		out.append("  Piedra: %s" % l.reading)
		out.append("  %s: \"%s\"" % [l.rival, l.greeting])
		var learned: PackedStringArray = l.learned
		out.append("  Tácticas: %s" % (", ".join(learned) if not learned.is_empty() else "ninguna todavía"))
		var tail: String = " · ¡absorbes un fragmento!" if l.absorbed else ""
		out.append("  Resultado: %s · piedra nivel %d · fama %+d%s" % [words[l.result], l.level, l.fame, tail])
	out.append("Tu estilo según la piedra: %s." % player.style_summary())
	return out
