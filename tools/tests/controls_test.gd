extends Node
## Prueba automática de controles: carga el nivel gris, simula dedos
## (joystick, arrastre para mirar, botón de ataque) y verifica que el jugador
## responda. Corre en CI con: godot --headless --path . res://tools/tests/controls_test.tscn
##
## Analogía web: un test de Playwright que hace page.touchscreen.tap().

const WORLD: PackedScene = preload("res://world/world.tscn")

var _failures: PackedStringArray = []
var _world: World
var _player: Player
var _touch: TouchControls


func _ready() -> void:
	RivalRegistry.save_enabled = false
	Piedra.save_enabled = false
	_world = WORLD.instantiate() as World
	# Estas pruebas usan el campo de pruebas (nivel gris).
	_world.start_zone = load(World.PRACTICE_ZONE)
	add_child(_world)
	_player = _world.get_node("Player")
	_touch = _world.get_node("HUD/SafeArea/TouchControls")
	await _frames(10)
	_player.settings.haptics_enabled = false
	# Esta prueba es del esquema de dos pulgares (v0.1.0).
	_player.settings.move_mode = ControlSettings.MODE_TWIN
	_world.apply_mode()
	await _frames(2)
	await _run()
	if _failures.is_empty():
		print("CONTROLS TEST OK")
		get_tree().quit(0)
	else:
		for f: String in _failures:
			printerr("CONTROLS TEST FAIL: ", f)
		get_tree().quit(1)


func _run() -> void:
	var rect: Rect2 = _touch.get_global_rect()

	# 1) Joystick: dedo abajo-izquierda, empujar hacia arriba = caminar adelante.
	var start: Vector3 = _player.global_position
	var joy: Vector2 = Vector2(rect.position.x + 180, rect.end.y - 250)
	_touch_event(0, joy, true)
	_drag_event(0, joy + Vector2(0, -100), Vector2(0, -100))
	await _frames(45)
	_check(_player.move_input.y < -0.5, "joystick no produjo movimiento hacia adelante (%s)" % _player.move_input)
	var moved: Vector3 = _player.global_position - start
	_check(moved.z < -0.5, "el jugador no avanzó (Δz=%.2f)" % moved.z)

	# 2) Mirar con otro dedo al mismo tiempo (multitouch), arriba de la pantalla.
	var yaw_before: float = _player.rotation.y
	var look: Vector2 = Vector2(rect.get_center().x, rect.position.y + 300)
	_touch_event(1, look, true)
	_drag_event(1, look + Vector2(120, 0), Vector2(120, 0))
	await _frames(2)
	_check(absf(_player.rotation.y - yaw_before) > 0.1, "arrastrar no giró la cámara")
	_touch_event(1, look + Vector2(120, 0), false)

	# 3) Soltar joystick: debe frenar.
	_touch_event(0, joy, false)
	await _frames(40)
	_check(_player.move_input == Vector2.ZERO, "al soltar el joystick sigue moviéndose")

	# 4) Atacar: girar hacia un muñeco y presionar ATACAR.
	var attacked: Array[bool] = []
	_player.attacked.connect(func(hit: bool) -> void: attacked.append(hit))
	var button: ActionButton = _touch.get_node("AttackButton")
	var center: Vector2 = button.global_position + button.size * 0.5
	_touch_event(2, center, true)
	await _frames(5)
	_touch_event(2, center, false)
	_check(attacked.size() == 1, "el botón de ataque no atacó (%d)" % attacked.size())

	# 5) Pérdida de foco: suelta todos los dedos y pausa.
	_touch_event(3, joy, true)
	_drag_event(3, joy + Vector2(0, -100), Vector2(0, -100))
	_world.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_touch.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(2)
	_check(_player.move_input == Vector2.ZERO, "perder el foco no soltó el joystick")
	_check(get_tree().paused, "perder el foco no pausó el juego")
	get_tree().paused = false


func _to_screen(pos: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * pos


func _touch_event(index: int, pos: Vector2, pressed: bool) -> void:
	var e: InputEventScreenTouch = InputEventScreenTouch.new()
	e.index = index
	e.position = _to_screen(pos)
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag_event(index: int, pos: Vector2, relative: Vector2) -> void:
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
