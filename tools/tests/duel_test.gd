extends Node
## Prueba automática de la v0.2.0 con dedos simulados:
## 1) stick de una mano (avanzar y girar), 2) modo por casillas,
## 3) primer golpe al cubo -> duelo, 4) atacar, 5) bloqueo perfecto,
## 6) hechizo con su canción, 7) huir y que el cubo lo recuerde.
## Corre en CI con: godot --headless --path . res://tools/tests/duel_test.tscn

const GREYBOX: PackedScene = preload("res://world/greybox/greybox.tscn")

var _failures: PackedStringArray = []
var _world: Node3D
var _player: Player
var _one: OneHandControls
var _duel: Duel
var _rival: RivalCube
var _ui: DuelUI


func _ready() -> void:
	RivalRegistry.save_enabled = false
	Piedra.save_enabled = false
	Piedra.use_record(PlayerRecord.new())
	_world = GREYBOX.instantiate()
	add_child(_world)
	_player = _world.get_node("Player")
	_one = _world.get_node("HUD/SafeArea/OneHandControls")
	_duel = _world.get_node("Duel")
	_rival = _world.get_node("Rivals/RivalCube")
	_ui = _duel.get_node("SafeArea/DuelUI")
	await _frames(10)
	_player.settings.haptics_enabled = false
	_player.settings.move_mode = ControlSettings.MODE_TANK
	_world.apply_mode()
	_duel.rng.seed = 7
	await _run()
	if _failures.is_empty():
		print("DUEL TEST OK")
		get_tree().quit(0)
	else:
		for f: String in _failures:
			printerr("DUEL TEST FAIL: ", f)
		get_tree().quit(1)


func _run() -> void:
	var rect: Rect2 = _one.get_global_rect()
	var thumb: Vector2 = Vector2(rect.get_center().x, rect.end.y - 200)

	# 1) Stick de tanque: arriba avanza, a la derecha gira (sin caminar de lado).
	print("Paso 1: Stick de tanque: arriba avanza, a la derecha gira (sin caminar de lado).")
	var start: Vector3 = _player.global_position
	_touch(0, thumb, true)
	_drag(0, thumb + Vector2(0, -110), Vector2(0, -110))
	await _frames(40)
	_check(_player.global_position.z - start.z < -0.5, "el stick de una mano no avanzó (Δz=%.2f)" % (_player.global_position.z - start.z))
	var yaw: float = _player.rotation.y
	_drag(0, thumb + Vector2(110, 0), Vector2(110, 110))
	await _frames(30)
	_check(_player.rotation.y < yaw - 0.3, "empujar a la derecha no giró a la derecha")
	_touch(0, thumb, false)
	await _frames(5)
	_check(_player.turn_input == 0.0 and _player.move_input == Vector2.ZERO, "al soltar el stick sigue moviéndose")

	# 2) Por casillas: un empujón = un paso exacto; a un lado = giro de 90°.
	print("Paso 2: Por casillas: un empujón = un paso exacto; a un lado = giro de 90°.")
	_player.settings.move_mode = ControlSettings.MODE_GRID
	_world.apply_mode()
	await _frames(3)
	var cell: Vector3 = _player.global_position
	var grid_yaw: float = _player.rotation.y
	_touch(0, thumb, true)
	_drag(0, thumb + Vector2(0, -100), Vector2(0, -100))
	await _frames(8)
	_touch(0, thumb, false)
	await _frames(20)
	var stepped: float = Vector2(_player.global_position.x - cell.x, _player.global_position.z - cell.z).length()
	_check(absf(stepped - _player.grid_size) < 0.05, "el paso por casillas no fue de una casilla (%.2f)" % stepped)
	_touch(0, thumb, true)
	_drag(0, thumb + Vector2(-100, 0), Vector2(-100, 0))
	await _frames(5)
	_touch(0, thumb, false)
	await _frames(20)
	_check(absf(angle_difference(grid_yaw, _player.rotation.y) - PI / 2.0) < 0.05, "el giro por casillas no fue de 90°")
	_player.settings.move_mode = ControlSettings.MODE_TANK
	_world.apply_mode()

	# 3) Primer golpe: ponerse frente al cubo y tocar ATACAR.
	print("Paso 3: Primer golpe: ponerse frente al cubo y tocar ATACAR.")
	var cube_pos: Vector3 = _rival.global_position
	_player.global_position = cube_pos + Vector3(0, 0, 2.2)
	_player.face_direction(Vector3(0, 0, -1))
	await _frames(3)
	_check(_world.get_node("%StoneLabel").visible, "la piedra no avisó que hay un rival cerca")
	var attack: ActionButton = _one.get_node("AttackButton")
	var center: Vector2 = attack.global_position + attack.size * 0.5
	_touch(0, center, true)
	await _frames(2)
	_touch(0, center, false)
	await _until(func() -> bool: return _duel.phase == &"menu", 5.0)
	_check(_duel.phase == &"menu", "el golpe al cubo no inició el duelo (fase %s)" % _duel.phase)
	_check(_rival.hp == _rival.max_hp - Duel.FIRST_STRIKE_DAMAGE, "el primer golpe no hizo daño")
	_check(not _one.visible, "los controles de exploración siguen visibles en el duelo")

	# 4) Cuerpo a cuerpo: dos golpes y terminar turno.
	print("Paso 4: Cuerpo a cuerpo: dos golpes y terminar turno.")
	await _tap(_ui.button_for(&"menu", 0))
	await _until(func() -> bool: return _duel.phase == &"melee", 2.0)
	var pa_before: int = _duel.pa
	var rival_before: int = _rival.hp
	for side: int in [3, 5]:
		await _tap(_ui.button_for(&"cell", side))
		await _until(func() -> bool: return _duel.phase == &"melee", 3.0)
	_check(_duel.pa == pa_before - 2 * Duel.ATTACK_COST, "los golpes no gastaron PA (%d -> %d)" % [pa_before, _duel.pa])
	_check(_rival.hp < rival_before, "los golpes no le bajaron vida al cubo")
	await _tap(_ui.button_for(&"end", 0))

	# 5) Turno del rival: bloquear justo antes del impacto = perfecto.
	print("Paso 5: Turno del rival: bloquear justo antes del impacto = perfecto.")
	await _block_rival_turn(true)
	_check(_duel.stats.perfect >= 1, "no salió ningún bloqueo perfecto (%s)" % _duel.stats)

	# 6) Hechizo Fuego: tocar su canción con ritmo parejo.
	print("Paso 6: Hechizo Fuego: tocar su canción con ritmo parejo.")
	await _until(func() -> bool: return _duel.phase == &"menu", 8.0)
	await _tap(_ui.button_for(&"menu", 1))
	await _until(func() -> bool: return _duel.phase == &"spell_pick", 2.0)
	var pm_before: int = _duel.pm
	rival_before = _rival.hp
	await _tap(_ui.button_for(&"spell", 0))
	for note: int in Duel.SPELLS[0].song:
		await _until(func() -> bool: return _duel.phase == &"song", 2.0)
		await _seconds(0.15)
		await _tap(_ui.button_for(&"cell", note))
	await _seconds(0.5)
	_check(_duel.pm == pm_before - int(Duel.SPELLS[0].cost), "el hechizo no gastó PM")
	_check(rival_before - _rival.hp >= int(Duel.SPELLS[0].power), "el hechizo no hizo su daño (%d)" % (rival_before - _rival.hp))

	# 7) No bloquear (recibir daño) y luego huir hasta lograrlo.
	print("Paso 7: No bloquear (recibir daño) y luego huir hasta lograrlo.")
	var hp_before: int = _duel.hp
	await _block_rival_turn(false)
	_check(_duel.hp < hp_before, "no bloquear no hizo daño")
	for attempt: int in 6:
		await _until(func() -> bool: return _duel.phase == &"menu" or not _duel.is_active(), 10.0)
		if not _duel.is_active() or _duel.result == &"fled":
			break
		await _tap(_ui.button_for(&"menu", 3))
		await _until(func() -> bool: return _duel.phase in [&"rival", &"block", &"outro", &"idle"], 3.0)
		if _duel.phase in [&"rival", &"block"]:
			await _block_rival_turn(true)
	await _until(func() -> bool: return not _duel.is_active(), 6.0)
	_check(_duel.result == &"fled", "no se pudo huir (%s)" % _duel.result)
	_check(_one.visible, "los controles no regresaron al salir del duelo")
	var registry: RivalRegistry = _world.get("_rivals")
	var memory: RivalMemory = registry.memory_for(_rival.data.id)
	_check(memory.duels == 1 and memory.last_result == "fled", "el cubo no recordó el duelo")
	_check(memory.attack_counts[0] == 1 and memory.attack_counts[2] == 1, "el cubo no recordó tus golpes (%s)" % str(memory.attack_counts))
	_check(memory.spell_counts.get("Fuego", 0) == 1, "el cubo no recordó tu Fuego")
	_check(Piedra.record.duels == 1 and Piedra.record.flees == 1, "la piedra no registró el duelo")
	var hello: String = RivalDialogue.greeting(_rival.data, memory, RivalTactics.plan(_rival.data, memory))
	_check(hello.begins_with("La última vez huiste"), "el saludo no menciona que huiste: %s" % hello)

	# 8) Memoria: tras 3 duelos cubre tu lado favorito.
	print("Paso 8: Memoria: tras 3 duelos cubre tu lado favorito.")
	memory.duels = 3
	memory.attack_counts = [9, 1, 1]
	_duel._tactics = RivalTactics.plan(_rival.data, memory)
	var guards: Array[int] = [0, 0, 0]
	for i: int in 200:
		guards[_duel._pick_guard()] += 1
	_check(guards[0] > 120, "el cubo no cubre tu lado favorito tras 3 duelos (%s)" % str(guards))
	hello = RivalDialogue.greeting(_rival.data, memory, _duel._tactics)
	_check(hello.contains("la izquierda"), "el saludo no menciona tu lado favorito: %s" % hello)


## Durante el turno del rival: bloquear cada golpe en el momento perfecto
## (perfect = true) o no tocar nada.
func _block_rival_turn(perfect: bool) -> void:
	await _until(func() -> bool: return _duel.phase == &"block", 5.0)
	while _duel.phase in [&"rival", &"block", &"busy"]:
		if _duel.phase == &"block" and perfect:
			var side: int = _duel.telegraph_side
			var wait: float = _duel.impact_at - 0.1 - Time.get_ticks_usec() / 1_000_000.0
			if wait > 0.0:
				await _seconds(wait)
			await _tap(_ui.button_for(&"cell", side), 0.0)
			await _until(func() -> bool: return _duel.phase != &"block", 2.0)
		await _frames(1)


## Toque real en el centro de un botón (pasa por el sistema de input).
func _tap(button: Button, delay: float = 0.2) -> void:
	if button == null:
		_failures.append("no se encontró un botón del duelo")
		return
	# Esperar el candado de DuelUI.SWAP_LOCK_MS (como un humano real).
	if delay > 0.0:
		await _seconds(delay)
	var c: Vector2 = button.get_global_rect().get_center()
	_touch(0, c, true)
	await _frames(1)
	_touch(0, c, false)
	await _frames(1)


func _to_screen(pos: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * pos


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e: InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = index
	e.position = _to_screen(pos)
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(index: int, pos: Vector2, relative: Vector2) -> void:
	var e: InputEventScreenDrag = InputEventScreenDrag.new()
	e.index = index
	e.position = _to_screen(pos)
	e.relative = get_viewport().get_screen_transform().basis_xform(relative)
	Input.parse_input_event(e)


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
