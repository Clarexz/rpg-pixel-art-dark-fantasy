extends Node
## Prueba automática del combate real (fase 3, v0.5.0):
## 1) fichas de enemigos y sprites, 2) patrones (EnemyAI), 3) inventario y
## botín, 4) huir según la piedra, 5) un enemigo te ve, te persigue y te
## alcanza, 6) duelo contra un enemigo común (combo, bomba, victoria, botín,
## sin memoria), 7) gólem: golpe cargado, Trueno lo corta, y si no, pega
## fuerte, 8) lobo: la finta cambia de lado y se puede bloquear perfecto.
## Corre en CI con: godot --headless --path . res://tools/tests/combat_test.tscn

const WORLD: PackedScene = preload("res://world/world.tscn")
const SCAV: EnemyData = preload("res://enemies/data/scavenger.tres")
const GOLEM: EnemyData = preload("res://enemies/data/slag_golem.tres")
const WOLF: RivalData = preload("res://rivals/data/ash_wolf.tres")

var _failures: PackedStringArray = []
var _world: World
var _player: Player
var _duel: Duel
var _ui: DuelUI


func _ready() -> void:
	RivalRegistry.save_enabled = false
	Piedra.save_enabled = false
	Inventory.save_enabled = false
	Piedra.use_record(PlayerRecord.new())
	test_data()
	test_patterns()
	test_inventory()
	test_flee_chance()
	_world = WORLD.instantiate() as World
	# Estas pruebas usan el campo de pruebas (nivel gris).
	_world.start_zone = load(World.PRACTICE_ZONE)
	add_child(_world)
	_player = _world.get_node("Player")
	_duel = _world.get_node("Duel")
	_ui = _duel.get_node("SafeArea/DuelUI")
	await _frames(10)
	_player.settings.haptics_enabled = false
	_duel.rng.seed = 11
	await test_chase_and_ambush()
	await test_common_enemy_duel()
	await test_golem_charge()
	await test_wolf_feint()
	if _failures.is_empty():
		print("COMBAT TEST OK")
		get_tree().quit(0)
	else:
		for f: String in _failures:
			printerr("COMBAT TEST FAIL: ", f)
		get_tree().quit(1)


func test_data() -> void:
	print("Paso 1: fichas y sprites")
	for d: EnemyData in [SCAV, GOLEM, WOLF]:
		_check(d.sprite != null and d.sprite.get_width() == 48 * 6 and d.sprite.get_height() == 48,
				"%s: el sprite debe ser una tira de 6 cuadros de 48x48" % d.id)
		for pat: PackedStringArray in [d.pattern, d.pattern_low]:
			for move_id: String in pat:
				_check(d.move_by_id(StringName(move_id)) != null, "%s: el patrón nombra '%s' y no existe" % [d.id, move_id])
		for item: Variant in d.loot:
			_check(Inventory.CATALOG.has(StringName(item)), "%s suelta un item desconocido: %s" % [d.id, item])
	_check(WOLF.is_rival() and not SCAV.is_rival() and not GOLEM.is_rival(), "solo el lobo debe ser rival")
	var kinds: Dictionary = {}
	for d: EnemyData in [SCAV, GOLEM, WOLF]:
		for m: EnemyMove in d.moves:
			kinds[m.kind] = true
	_check(kinds.size() == 4, "faltan tipos de movimiento (simple, combo, finta, cargado)")


func test_patterns() -> void:
	print("Paso 2: patrones aprendibles")
	var seq: PackedStringArray = []
	for step: int in 5:
		seq.append(String(EnemyAI.choose(GOLEM, step, 1.0).id))
	_check(seq == PackedStringArray(["punetazo", "aplastar", "punetazo", "punetazo", "punetazo"]),
			"el gólem no sigue su patrón: %s" % str(seq))
	_check(EnemyAI.choose(GOLEM, 0, 0.3).id == &"aplastar", "con poca vida el gólem debería usar su otro patrón")
	_check(EnemyAI.choose(SCAV, 1, 0.3).id == &"frenesi", "con poca vida el carroñero debería hacer Frenesí")
	var cube: RivalData = load("res://rivals/data/test_cube.tres")
	_check(EnemyAI.choose(cube, 0, 1.0).kind == EnemyMove.Kind.SIMPLE, "sin movimientos debería usar un golpe simple")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for i: int in 50:
		var sides: Array[int] = EnemyAI.combo_sides(3, rng)
		_check(sides[0] != sides[1] and sides[1] != sides[2], "un combo repitió lado seguido: %s" % str(sides))
		var real: int = rng.randi_range(0, 2)
		_check(EnemyAI.feint_side(real, rng) != real, "la finta amagó del mismo lado")


func test_inventory() -> void:
	print("Paso 3: inventario y botín")
	var inv: Inventory = Inventory.starting()
	_check(inv.count(&"pocion") == 2 and inv.count(&"eter") == 1 and inv.count(&"bomba") == 1, "inventario inicial raro: %s" % inv.counts)
	_check(inv.take(&"bomba") and not inv.take(&"bomba"), "gastar items no funciona")
	_check(inv.add(&"pocion", 20) == Inventory.MAX_STACK - 2, "el tope de %d no se respetó" % Inventory.MAX_STACK)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var got: int = 0
	for i: int in 200:
		got += inv.roll_loot({"eter": 0.5}, rng).size()
		inv.counts["eter"] = 0
	_check(got > 70 and got < 130, "el botín no respeta su probabilidad (%d de 200 con 50%%)" % got)
	Inventory.save_enabled = true
	var path: String = "user://test_inventory.tres"
	inv.counts["eter"] = 4
	inv.save(path)
	var loaded: Inventory = Inventory.load_or_new(path)
	Inventory.save_enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(loaded.count(&"eter") == 4 and loaded.count(&"pocion") == Inventory.MAX_STACK, "el inventario no se guardó bien")


func test_flee_chance() -> void:
	print("Paso 4: huir depende de la piedra")
	var c: Dictionary = Duel.FLEE_CHANCE
	_check(c[&"weaker"] > c[&"similar"] and c[&"similar"] > c[&"stronger"] and c[&"stronger"] > c[&"broken"],
			"huir debería ser más difícil contra enemigos más fuertes")
	_check(Piedra.scan(SCAV, null).tier == &"weaker", "el carroñero debería leerse más débil")
	_check(Piedra.scan(WOLF, null).tier == &"stronger", "el lobo debería leerse más fuerte")


func test_chase_and_ambush() -> void:
	print("Paso 5: te ve, te persigue y te alcanza")
	var scav: Enemy = _world.zone.get_node("Enemies/Scavenger")
	scav.global_position = Vector3(8, 0, -6)
	_player.global_position = Vector3(3, 0, -6)
	_player.face_direction(Vector3(0, 0, 1))  # de espaldas: no le pega primero
	var start_dist: float = scav.global_position.distance_to(_player.global_position)
	await _until(func() -> bool: return scav.state == Enemy.State.CHASE, 4.0)
	_check(scav.state == Enemy.State.CHASE, "el carroñero no empezó a perseguir (estado %d)" % scav.state)
	await _until(func() -> bool: return _duel.is_active(), 6.0)
	_check(_duel.is_active(), "el carroñero no te alcanzó")
	_check(_duel._encounter.advantage == &"rival", "si te alcanza, debería atacar él primero")
	_check(scav.global_position.distance_to(_player.global_position) < start_dist, "no se acercó al perseguirte")


func test_common_enemy_duel() -> void:
	print("Paso 6: duelo contra un enemigo común")
	var scav: Enemy = _world.zone.get_node("Enemies/Scavenger")
	var inv: Inventory = _world.get("_inventory")
	var registry: RivalRegistry = _world.get("_rivals")
	# Empieza él (emboscada): recibir su golpe.
	await _until(func() -> bool: return _duel.phase == &"menu", 8.0)
	_check(_duel.hp < Duel.PLAYER_MAX_HP, "su primer golpe no hizo daño")
	# Bomba: daño fijo, gasta el item.
	var hp_before: int = scav.hp
	await _tap(_ui.menu_point(2))
	await _until(func() -> bool: return _duel.phase == &"items", 2.0)
	await _tap(_ui.button_for(&"item", 2))
	await _until(func() -> bool: return _duel.phase != &"items" and _duel.phase != &"busy", 3.0)
	_check(hp_before - scav.hp == int(Inventory.CATALOG[&"bomba"].power), "la bomba no hizo su daño fijo (%d)" % (hp_before - scav.hp))
	_check(inv.count(&"bomba") == 0, "la bomba no se gastó")
	# Su segundo movimiento es un combo de 2: sin bloquear, dos golpes.
	var hits: int = _duel.stats.hit
	await _until(func() -> bool: return _duel.phase == &"menu", 10.0)
	_check(_duel.last_move.kind == EnemyMove.Kind.COMBO, "el segundo movimiento debería ser un combo")
	_check(_duel.stats.hit - hits == 2, "el combo debería pegar 2 veces (%d)" % (_duel.stats.hit - hits))
	# Rematarlo.
	var items_before: int = _total(inv)
	await _finish_win(scav)
	_check(_duel.result == &"win", "no se ganó el duelo (%s)" % _duel.result)
	_check(_total(inv) - items_before == _duel.loot_won.size(), "el botín mostrado no coincide con el inventario")
	_check(not registry.memories.has("scavenger"), "¡un enemigo común no debe tener memoria!")
	_check(Piedra.record.wins == 1 and Piedra.record.absorbed.is_empty(), "un enemigo común da XP pero no fragmento de piedra")
	_check(not scav.visible and scav.state == Enemy.State.DEAD, "el carroñero vencido sigue en el mundo")


func test_golem_charge() -> void:
	print("Paso 7: gólem: carga, Trueno la corta; si no, pega fuerte")
	var golem: Enemy = _world.zone.get_node("Enemies/SlagGolem")
	_player.global_position = golem.global_position + Vector3(0, 0, 2.0)
	_world._on_enemy_engaged(golem, &"player")
	await _until(func() -> bool: return _duel.phase == &"menu", 5.0)
	_duel._step = 1  # siguiente movimiento: Aplastar (cargado)
	await _end_turn_with_one_hit()
	await _until(func() -> bool: return _duel.phase == &"menu", 8.0)
	_check(_duel.charging, "el gólem no empezó a cargar")
	_check(golem._sprite.frame == Enemy.F_WINDUP, "el sprite no está en la pose de preparar")
	# Trueno corta la carga.
	_duel.pm = Duel.PM_MAX
	await _cast(3)
	_check(not _duel.charging, "Trueno no cortó la carga")
	await _until(func() -> bool: return _duel.phase == &"menu", 6.0)
	_check(_duel.stats.hit == 0 and _duel.hp == Duel.PLAYER_MAX_HP, "aturdido no debería atacar")
	# Otra carga, esta vez sin cortarla: pega fuerte.
	_duel._step = 1
	await _end_turn_with_one_hit()
	await _until(func() -> bool: return _duel.phase == &"menu", 8.0)
	_check(_duel.charging, "no volvió a cargar")
	var hp_before: int = _duel.hp
	await _end_turn_with_one_hit()
	await _until(func() -> bool: return _duel.phase == &"menu", 8.0)
	_check(hp_before - _duel.hp == _duel.last_move.damage, "el golpe cargado debería hacer %d (hizo %d)" % [_duel.last_move.damage, hp_before - _duel.hp])
	await _finish_win(golem)


func test_wolf_feint() -> void:
	print("Paso 8: lobo: la finta cambia de lado")
	var wolf: Enemy = _world.zone.get_node("Enemies/AshWolf")
	_player.global_position = wolf.global_position + Vector3(0, 0, 2.0)
	_world._on_enemy_engaged(wolf, &"player")
	await _until(func() -> bool: return _duel.phase == &"menu", 5.0)
	_duel._step = 1  # Amago (finta)
	await _end_turn_with_one_hit()
	await _until(func() -> bool: return _duel.phase == &"block", 5.0)
	_check(_duel.telegraph_is_feint, "el aviso no se marcó como finta")
	var shown: int = _duel.telegraph_side
	await _until(func() -> bool: return not _duel.telegraph_is_feint, 3.0)
	_check(_duel.telegraph_side != shown, "la finta no cambió de lado")
	var wait: float = _duel.impact_at - 0.1 - Time.get_ticks_usec() / 1_000_000.0
	if wait > 0.0:
		await _seconds(wait)
	await _tap(_ui.button_for(&"cell", _duel.telegraph_side), 0.0)
	await _until(func() -> bool: return _duel.phase == &"menu", 6.0)
	_check(_duel.stats.perfect == 1, "no se pudo bloquear perfecto la finta (%s)" % _duel.stats)
	var registry: RivalRegistry = _world.get("_rivals")
	await _finish_win(wolf)
	_check(registry.memory_for(&"ash_wolf").player_wins == 1, "el lobo no recordó que lo venciste")
	_check(Piedra.record.absorbed.has("ash_wolf"), "vencer al rival debería darte un fragmento de su piedra")


# --- Ayudantes -------------------------------------------------------------------

func _total(inv: Inventory) -> int:
	var n: int = 0
	for k: Variant in inv.counts:
		n += int(inv.counts[k])
	return n


func _end_turn_with_one_hit() -> void:
	await _tap(_ui.menu_point(0))
	await _until(func() -> bool: return _duel.phase == &"melee", 2.0)
	await _tap(_ui.button_for(&"cell", 4))
	await _until(func() -> bool: return _duel.phase == &"melee", 3.0)
	await _tap(_ui.button_for(&"end", 0))


func _cast(index: int) -> void:
	await _tap(_ui.menu_point(1))
	await _until(func() -> bool: return _duel.phase == &"spell_pick", 2.0)
	await _tap(_ui.button_for(&"spell", index))
	for note: int in Duel.SPELLS[index].song:
		await _until(func() -> bool: return _duel.phase == &"song", 2.0)
		await _seconds(0.15)
		await _tap(_ui.button_for(&"cell", note))
	await _until(func() -> bool: return _duel.phase != &"song" and _duel.phase != &"busy", 4.0)


func _finish_win(enemy: Enemy) -> void:
	await _until(func() -> bool: return _duel.phase == &"menu", 8.0)
	enemy.hp = 1
	await _tap(_ui.menu_point(0))
	await _until(func() -> bool: return _duel.phase == &"melee", 2.0)
	await _tap(_ui.button_for(&"cell", 3))
	await _until(func() -> bool: return not _duel.is_active(), 10.0)


func _tap(target: Variant, delay: float = 0.2) -> void:
	if target == null:
		_failures.append("no se encontró un botón del duelo")
		return
	if delay > 0.0:
		await _seconds(delay)
	var c: Vector2 = get_viewport().get_screen_transform() * _point_of(target)
	for pressed: bool in [true, false]:
		var e: InputEventScreenTouch = InputEventScreenTouch.new()
		e.position = c
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(condition: Callable, timeout: float) -> void:
	var end: float = Time.get_ticks_msec() + timeout * 1000.0
	while not condition.call() and Time.get_ticks_msec() < end:
		await get_tree().process_frame


## Punto global a tocar: un Vector2 tal cual, o el centro de un botón.
func _point_of(target: Variant) -> Vector2:
	if target is Vector2:
		return target
	return (target as Control).get_global_rect().get_center()
