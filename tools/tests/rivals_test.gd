extends Node
## Pruebas unitarias de la lógica de rivales y piedra (sin 3D ni toques).
## Corre en CI con: godot --headless --path . res://tools/tests/rivals_test.tscn
##
## Analogía web: un archivo de Jest con muchos `expect`, pero sin framework.

const CUBE: RivalData = preload("res://rivals/data/test_cube.tres")
const WOLF: RivalData = preload("res://rivals/data/ash_wolf.tres")

var _failures: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	Piedra.save_enabled = false
	test_memory_records_only_its_duels()
	test_fresh_rival_does_not_adapt()
	test_learns_favorite_side()
	test_cunning_changes_learning_speed()
	test_resists_favorite_spell_and_weakness()
	test_scar_from_finisher()
	test_rhythm_and_boldness()
	test_isolation_between_rivals()
	test_plan_only_takes_rival_and_its_memory()
	test_player_record_xp_level_absorb()
	test_reputation_signal_and_fame()
	test_power_reading_precision()
	test_registry_save_roundtrip()
	test_simulation_ten_duels()
	if _failures.is_empty():
		print("RIVALS TEST OK (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		for f: String in _failures:
			printerr("RIVALS TEST FAIL: ", f)
		get_tree().quit(1)


# --- Ayudantes ---------------------------------------------------------------

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(message)


func _duel(id: StringName, result: StringName, sides: Array = [0, 0, 0], spells: Dictionary = {},
		perfect: int = 0, blocks: int = 0, hits: int = 0, finisher: String = "") -> Encounter:
	var e: Encounter = Encounter.new()
	e.rival_id = id
	e.result = result
	if not sides.is_empty():
		e.attack_sides.assign(sides)
	e.spells = spells.duplicate()
	e.perfect_blocks = perfect
	e.blocks = blocks
	e.hits_taken = hits
	e.finisher = finisher
	return e


func _memory(id: StringName) -> RivalMemory:
	var m: RivalMemory = RivalMemory.new()
	m.rival_id = id
	return m


## Huella de una memoria y sus tácticas, para comparar "antes" y "después".
func _fingerprint(data: RivalData, m: RivalMemory) -> String:
	var t: RivalTactics = RivalTactics.plan(data, m)
	var props: Dictionary = {}
	for p: Dictionary in m.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE and p.name not in ["resource_path", "resource_name",
				"resource_local_to_scene", "script", "resource_scene_unique_id"]:
			props[p.name] = m.get(p.name)
	return var_to_str([props, t.guard_side, t.guard_chance, t.resists, t.weakness, t.windup,
			t.extra_strikes, t.learned, RivalDialogue.greeting(data, m, t),
			PowerReading.rival_power(data, m)])


# --- Pruebas -------------------------------------------------------------------

func test_memory_records_only_its_duels() -> void:
	var m: RivalMemory = _memory(&"test_cube")
	m.record(_duel(&"test_cube", &"fled", [2, 1, 0], {"Fuego": 1}, 1, 0, 2))
	m.record(_duel(&"test_cube", &"win", [1, 0, 3], {}, 0, 1, 0, "Trueno"))
	_check(m.duels == 2, "la memoria no contó 2 duelos (%d)" % m.duels)
	_check(m.last_result == "win", "último resultado incorrecto")
	_check(m.player_flees == 1 and m.player_wins == 1, "no contó huidas/victorias")
	_check(m.attack_counts == [3, 1, 3], "no sumó tus golpes por lado (%s)" % str(m.attack_counts))
	_check(m.spell_counts == {"Fuego": 1}, "no contó tus hechizos")
	_check(m.strikes_thrown == 4 and m.perfect_blocks_seen == 1, "no contó sus golpes")
	_check(m.scars == ["Trueno"], "no guardó la cicatriz del remate")


func test_fresh_rival_does_not_adapt() -> void:
	var t: RivalTactics = RivalTactics.plan(CUBE, _memory(&"test_cube"))
	_check(t.guard_side == -1 and t.resists.is_empty() and t.extra_strikes == 0,
			"un rival nuevo ya viene adaptado: %s" % t.learned)
	_check(t.windup == RivalTactics.WINDUP_NORMAL, "un rival nuevo cambia el ritmo")
	_check(t.spell_multiplier("Trueno") > 1.0, "no aplica la debilidad del cubo (Trueno)")
	_check(t.spell_multiplier("Fuego") == 1.0, "Fuego no debería tener multiplicador")


func test_learns_favorite_side() -> void:
	var m: RivalMemory = _memory(&"test_cube")
	for i: int in 2:
		m.record(_duel(&"test_cube", &"fled", [3, 0, 1]))
	_check(RivalTactics.plan(CUBE, m).guard_side == -1, "se adaptó antes de 3 duelos")
	m.record(_duel(&"test_cube", &"fled", [3, 0, 1]))
	var t: RivalTactics = RivalTactics.plan(CUBE, m)
	_check(t.guard_side == 0, "tras 3 duelos no cubre tu lado favorito (izq)")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var guards: Array[int] = [0, 0, 0]
	for i: int in 400:
		guards[t.pick_guard(rng)] += 1
	_check(guards[0] > 280, "no cubre la izquierda la mayoría de las veces (%s)" % str(guards))
	_check(RivalDialogue.greeting(CUBE, m, t).contains("la izquierda"), "el saludo no lo menciona")
	# Si repartes parejo tus golpes, ya no hay favorito.
	var even: RivalMemory = _memory(&"test_cube")
	for i: int in 3:
		even.record(_duel(&"test_cube", &"fled", [2, 2, 2]))
	_check(RivalTactics.plan(CUBE, even).guard_side == -1, "con golpes parejos inventó un favorito")


func test_cunning_changes_learning_speed() -> void:
	_check(RivalTactics.plan(CUBE, _memory(&"test_cube")).adapt_after == 3, "el cubo debería tardar 3 duelos")
	_check(RivalTactics.plan(WOLF, _memory(&"ash_wolf")).adapt_after == 2, "el lobo (astuto) debería tardar 2")
	var m: RivalMemory = _memory(&"ash_wolf")
	for i: int in 2:
		m.record(_duel(&"ash_wolf", &"lose", [0, 0, 4]))
	_check(RivalTactics.plan(WOLF, m).guard_side == 2, "el lobo no aprendió en 2 duelos")


func test_resists_favorite_spell_and_weakness() -> void:
	var m: RivalMemory = _memory(&"ash_wolf")
	m.record(_duel(&"ash_wolf", &"fled", [], {"Fuego": 2}))
	m.record(_duel(&"ash_wolf", &"fled", [], {"Fuego": 1}))
	var t: RivalTactics = RivalTactics.plan(WOLF, m)
	_check(t.resists == "Fuego", "no aprendió a resistir tu Fuego")
	_check(t.spell_multiplier("Fuego") == RivalTactics.RESIST_MULT, "Fuego no se reduce")
	_check(t.weakness.is_empty(), "el lobo era débil a Fuego y al resistirlo debería perder la debilidad")
	_check(RivalDialogue.greeting(WOLF, m, t).contains("Fuego"), "el saludo no menciona el Fuego")


func test_scar_from_finisher() -> void:
	var m: RivalMemory = _memory(&"test_cube")
	m.record(_duel(&"test_cube", &"win", [1, 0, 0], {"Égida": 1}, 0, 0, 0, "Égida"))
	m.record(_duel(&"test_cube", &"fled", [0, 1, 0]))
	m.record(_duel(&"test_cube", &"fled", [0, 1, 0]))
	var t: RivalTactics = RivalTactics.plan(CUBE, m)
	_check(t.resists == "Égida", "no resiste el hechizo de su cicatriz")
	_check(RivalDialogue.greeting(CUBE, m, t).contains("Aún me arde tu Égida"), "no menciona su cicatriz")
	var steel: RivalMemory = _memory(&"test_cube")
	for i: int in 3:
		steel.record(_duel(&"test_cube", &"win", [1, 1, 1]))
	_check(steel.scars == ["Acero"], "vencerlo a golpes deja cicatriz de Acero (%s)" % str(steel.scars))
	_check(RivalTactics.plan(CUBE, steel).resists.is_empty(), "no se puede 'resistir' el acero")


func test_rhythm_and_boldness() -> void:
	var m: RivalMemory = _memory(&"test_cube")
	for i: int in 3:
		m.record(_duel(&"test_cube", &"lose", [], {}, 2, 0, 1))
	var t: RivalTactics = RivalTactics.plan(CUBE, m)
	_check(t.windup == RivalTactics.WINDUP_MIXED, "no cambió el ritmo pese a tus perfectos")
	_check(t.extra_strikes == 1, "no se envalentonó tras vencerte varias veces")
	_check(PowerReading.rival_power(CUBE, m) == CUBE.power + 3 * PowerReading.RIVAL_POWER_PER_WIN,
			"no creció al vencerte")


## La regla de oro: lo que pasa con el rival A no cambia NADA del rival B.
func test_isolation_between_rivals() -> void:
	var registry: RivalRegistry = RivalRegistry.new()
	var player: PlayerRecord = PlayerRecord.new()
	registry.record(_duel(&"ash_wolf", &"lose", [1, 1, 0], {}, 0, 0, 2))
	var wolf_before: String = _fingerprint(WOLF, registry.memory_for(&"ash_wolf"))
	for i: int in 8:
		var e: Encounter = _duel(&"test_cube", [&"win", &"lose", &"fled"][i % 3], [5, 0, 0],
				{"Fuego": 2}, 3, 1, 1, "Fuego")
		registry.record(e)
		player.record(e)
	var wolf_after: String = _fingerprint(WOLF, registry.memory_for(&"ash_wolf"))
	_check(wolf_before == wolf_after, "¡duelos con el cubo cambiaron al lobo!\n%s\n%s" % [wolf_before, wolf_after])
	_check(registry.memory_for(&"test_cube").duels == 8, "el cubo no registró sus duelos")
	# Vencer (o perder) contra el cubo tampoco hace al lobo más fuerte.
	_check(PowerReading.rival_power(WOLF, registry.memory_for(&"ash_wolf")) == WOLF.power + 10,
			"el poder del lobo cambió por duelos ajenos")
	# Un Encounter de otro rival se rechaza.
	var m: RivalMemory = _memory(&"ash_wolf")
	var fp: String = _fingerprint(WOLF, m)
	print("(Se espera un ERROR a continuación: la prueba entrega un duelo equivocado a propósito.)")
	m.record(_duel(&"test_cube", &"win"))
	_check(_fingerprint(WOLF, m) == fp, "una memoria aceptó un duelo de otro rival")


## Guardia estructural: plan() solo recibe (RivalData, RivalMemory). Si alguien
## le agrega "otros rivales", "facción" o el registro, esta prueba avisa.
func test_plan_only_takes_rival_and_its_memory() -> void:
	var script: Script = load("res://rivals/rival_tactics.gd")
	for method: Dictionary in script.get_script_method_list():
		if method.name != "plan":
			continue
		var types: Array[String] = []
		for arg: Dictionary in method.args:
			types.append(arg.class_name)
		_check(types == ["RivalData", "RivalMemory"],
				"RivalTactics.plan recibe %s; solo debe recibir (RivalData, RivalMemory)" % str(types))
		return
	_check(false, "no se encontró RivalTactics.plan")


func test_player_record_xp_level_absorb() -> void:
	var p: PlayerRecord = PlayerRecord.new()
	_check(p.level() == 1 and p.power() == 100, "la piedra no empieza en nivel 1 / poder 100")
	var first: bool = p.record(_duel(&"test_cube", &"win", [1, 0, 0]))
	_check(first, "la primera victoria no absorbió fragmento")
	_check(p.stone_xp == PlayerRecord.XP_WIN + PlayerRecord.XP_FIRST_ABSORB, "XP incorrecta (%d)" % p.stone_xp)
	_check(p.level() == 2, "con 40 XP la piedra debería ser nivel 2")
	var again: bool = p.record(_duel(&"test_cube", &"win"))
	_check(not again, "absorbió dos veces del mismo rival")
	p.record(_duel(&"test_cube", &"lose", [], {}, 3))
	_check(p.stone_xp == 40 + 20 + 5 + 6, "XP de derrota + perfectos incorrecta (%d)" % p.stone_xp)
	_check(p.wins == 2 and p.losses == 1 and p.duels == 3, "contadores del jugador mal")


func test_reputation_signal_and_fame() -> void:
	var p: PlayerRecord = PlayerRecord.new()
	var seen: Array = []
	p.reputation_changed.connect(func(zone: StringName, value: int) -> void: seen.append([zone, value]))
	var e: Encounter = _duel(&"test_cube", &"win")
	e.zone = &"bosque"
	p.record(e)
	_check(seen == [[&"bosque", 3]], "reputation_changed no se emitió bien (%s)" % str(seen))
	_check(p.reputation_in(&"greybox") == 0, "la fama se filtró a otra zona")
	_check(p.fame_title(&"bosque") == "el retador del que hablan", "título de fama incorrecto")
	for i: int in 4:
		var f: Encounter = _duel(&"ash_wolf", &"fled")
		f.zone = &"cueva"
		p.record(f)
	_check(p.fame_title(&"cueva") == "el que siempre huye", "huir mucho no da mala fama")
	_check(p.style_summary().contains("huyes seguido"), "el estilo no nota que huyes")


func test_power_reading_precision() -> void:
	var r1: PowerReading = PowerReading.read(1, 100, "Lobo", 160, "Fuego")
	_check(r1.tier == &"stronger" and r1.value == -1 and r1.weakness.is_empty(),
			"nivel 1 debería dar solo 'más fuerte' (%s)" % r1.text)
	var r2: PowerReading = PowerReading.read(2, 125, "Lobo", 160, "Fuego")
	_check(r2.value == 150 and r2.weakness.is_empty(), "nivel 2: número de 25 en 25 sin debilidad (%s)" % r2.text)
	var r3: PowerReading = PowerReading.read(3, 150, "Lobo", 163, "Fuego")
	_check(r3.value == 160 and r3.weakness == "Fuego" and r3.tier == &"similar", "nivel 3 (%s)" % r3.text)
	var r4: PowerReading = PowerReading.read(4, 175, "Lobo", 163, "Fuego")
	_check(r4.value == 163, "nivel 4: número exacto (%s)" % r4.text)
	_check(PowerReading.read(1, 100, "Cubo", 80).tier == &"weaker", "no lee 'más débil'")
	_check(PowerReading.read(1, 100, "Dragón", 210).tier == &"broken", "un poder enorme no rompe la lectura")
	_check(PowerReading.read(3, 150, "Dragón", 310).tier != &"broken", "con piedra fuerte no debería romperse")


func test_registry_save_roundtrip() -> void:
	var path: String = "user://test_rivals_roundtrip.tres"
	var reg: RivalRegistry = RivalRegistry.new()
	reg.record(_duel(&"test_cube", &"win", [2, 0, 1], {"Fuego": 1}, 1, 0, 0, "Fuego"))
	reg.record(_duel(&"ash_wolf", &"fled", [0, 3, 0]))
	reg.save(path)
	var loaded: RivalRegistry = RivalRegistry.load_or_new(path)
	_check(loaded != reg, "no se recargó desde disco")
	var cube: RivalMemory = loaded.memory_for(&"test_cube")
	_check(cube.duels == 1 and cube.scars == ["Fuego"] and cube.spell_counts.get("Fuego", 0) == 1,
			"la memoria del cubo no sobrevivió al guardado")
	_check(loaded.memory_for(&"ash_wolf").attack_counts == [0, 3, 0], "la memoria del lobo no sobrevivió")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_simulation_ten_duels() -> void:
	var sim: RivalSim = RivalSim.new().run()
	_check(sim.history.size() == 10, "la simulación no tuvo 10 duelos")
	for line: String in sim.lines():
		print(line)
	var cube: RivalMemory = sim.registry.memory_for(&"test_cube")
	var wolf: RivalMemory = sim.registry.memory_for(&"ash_wolf")
	_check(cube.duels == 5 and wolf.duels == 5, "cada rival debería recordar solo sus 5 duelos")
	# El lobo (astuto) aprende en su 3er duelo; el cubo, en su 4o.
	_check(sim.history[3].guard_side == -1, "en su 2o duelo (duelo 4) el lobo todavía no debería adaptarse")
	_check(sim.history[5].guard_side == 0, "en su 3er duelo (duelo 6) el lobo debería cubrir tu izquierda")
	_check(sim.history[4].guard_side == -1, "en su 3er duelo (duelo 5) el cubo todavía no debería adaptarse")
	_check(sim.history[6].guard_side == 0, "en su 4o duelo (duelo 7) el cubo debería cubrir tu izquierda")
	_check(sim.history[6].resists == "Fuego", "tras ver tu Fuego 3 veces el cubo debería resistirlo")
	_check(sim.player.level() >= 3, "tras 4 victorias la piedra debería subir (nivel %d)" % sim.player.level())
	_check((sim.history[0].reading as String).contains("parecido a ti"), "la primera lectura del cubo")
	_check((sim.history[1].reading as String).contains("más fuerte"), "la primera lectura del lobo")
	_check(sim.history[0].greeting == CUBE.line_first_meet, "el primer saludo del cubo")
	_check((sim.history[2].greeting as String).begins_with("La última vez huiste"), "el cubo no recuerda que huiste")
